import Combine
import Foundation

struct PendingTimeEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let teamId: String
    let taskId: String
    let taskName: String
    let startedAt: Date
    let duration: TimeInterval
    var attempts: Int
    var lastAttemptAt: Date?
    var lastError: String?

    init(id: UUID = UUID(),
         teamId: String,
         taskId: String,
         taskName: String,
         startedAt: Date,
         duration: TimeInterval,
         attempts: Int = 0,
         lastAttemptAt: Date? = nil,
         lastError: String? = nil) {
        self.id = id
        self.teamId = teamId
        self.taskId = taskId
        self.taskName = taskName
        self.startedAt = startedAt
        self.duration = duration
        self.attempts = attempts
        self.lastAttemptAt = lastAttemptAt
        self.lastError = lastError
    }
}

/// Time entries that failed to reach ClickUp, kept on disk until they do.
///
/// Losing a logged hour is the only failure this app cannot shrug off, so the entry
/// is persisted the moment the POST fails. Everything else here is deliberately
/// simple: no reachability monitoring, no idempotency keys, no generic sync engine.
@MainActor
final class PendingEntryQueue: ObservableObject {
    @Published private(set) var entries: [PendingTimeEntry] = []

    var hasPending: Bool { !entries.isEmpty }

    private let api: ClickUpAPIClient
    private let defaults: UserDefaults
    private let key: String
    private let now: () -> Date
    private let maxEntries: Int
    private var isFlushing = false

    init(api: ClickUpAPIClient = ClickUpAPI.shared,
         defaults: UserDefaults = .standard,
         key: String = AppPreferences.Key.pendingEntries.rawValue,
         now: @escaping () -> Date = Date.init,
         maxEntries: Int = 50) {
        self.api = api
        self.defaults = defaults
        self.key = key
        self.now = now
        self.maxEntries = maxEntries
        self.entries = Self.load(from: defaults, key: key)
    }

    func enqueue(_ entry: PendingTimeEntry) {
        entries.append(entry)
        // Drop the oldest rather than growing without bound. Anything this stale is
        // never going to sync cleanly anyway.
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
        persist()
    }

    func remove(id: UUID) {
        entries.removeAll { $0.id == id }
        persist()
    }

    /// Retries every entry whose backoff has elapsed. Returns how many synced.
    @discardableResult
    func flush() async -> Int {
        guard !isFlushing, !entries.isEmpty else { return 0 }
        isFlushing = true
        defer { isFlushing = false }

        var synced = 0
        for entry in entries where Self.isDue(entry, now: now()) {
            do {
                _ = try await api.createTimeEntry(
                    teamId: entry.teamId,
                    taskId: entry.taskId,
                    startDate: entry.startedAt,
                    duration: entry.duration
                )
                entries.removeAll { $0.id == entry.id }
                synced += 1
            } catch {
                guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { continue }
                entries[index].attempts += 1
                entries[index].lastAttemptAt = now()
                entries[index].lastError = error.localizedDescription
                // An expired token will not fix itself by retrying, but the work is
                // still real — hold the entry until the user signs in again.
                if case APIError.unauthorized = error { break }
            }
        }

        persist()
        return synced
    }

    /// Exponential backoff capped at five minutes.
    ///
    /// The exponent is `attempts - 1` because `attempts` has already been incremented
    /// by the time this is consulted: the first retry waits 60s, not 120s.
    static func isDue(_ entry: PendingTimeEntry, now: Date) -> Bool {
        guard let last = entry.lastAttemptAt else { return true }
        let exponent = max(0, entry.attempts - 1)
        let delay = min(60 * pow(2, Double(exponent)), 300)
        return now.timeIntervalSince(last) >= delay
    }

    // MARK: - Persistence

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: key)
    }

    private static func load(from defaults: UserDefaults, key: String) -> [PendingTimeEntry] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([PendingTimeEntry].self, from: data)) ?? []
    }
}
