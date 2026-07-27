import Combine
import Foundation

/// "Hoy · 2h 10m registrados".
///
/// ClickUp is the source of truth rather than a local tally, so the figure also
/// reflects time logged from the web or the phone, and does not drift when a sync
/// fails. The running session is added on top locally, since it is not in ClickUp yet.
@MainActor
final class DailyTotalService: ObservableObject {

    /// Seconds already logged in ClickUp for `day`. `nil` means never successfully
    /// loaded — the UI hides the figure rather than showing a false zero.
    @Published private(set) var syncedSeconds: TimeInterval?
    @Published private(set) var isRefreshing = false
    /// A refresh failed; the value shown is the last good one.
    @Published private(set) var isStale = false
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var lastError: String?
    @Published private(set) var day: Date

    private let api: ClickUpAPIClient
    private let calendar: Calendar
    private let now: () -> Date
    private let minimumRefreshInterval: TimeInterval
    private let pollInterval: TimeInterval

    private var teamId: String = ""
    private var userId: Int = 0
    private var pollTimer: Timer?
    private var retryTask: Task<Void, Never>?
    private var inFlight: Task<Void, Never>?

    init(api: ClickUpAPIClient = ClickUpAPI.shared,
         calendar: Calendar = .current,
         now: @escaping () -> Date = Date.init,
         minimumRefreshInterval: TimeInterval = 30,
         pollInterval: TimeInterval = 300) {
        self.api = api
        self.calendar = calendar
        self.now = now
        self.minimumRefreshInterval = minimumRefreshInterval
        self.pollInterval = pollInterval
        self.day = calendar.startOfDay(for: now())
    }

    deinit {
        pollTimer?.invalidate()
        retryTask?.cancel()
    }

    func configure(teamId: String, userId: Int) {
        guard self.teamId != teamId || self.userId != userId else { return }
        self.teamId = teamId
        self.userId = userId
        syncedSeconds = nil
        lastUpdated = nil
        isStale = false
    }

    /// Total to render: what ClickUp knows plus the session currently running.
    /// Returns `nil` while the figure has never loaded, so the UI can hide it.
    func displayTotal(runningSince startedAt: Date?, elapsed: TimeInterval) -> TimeInterval? {
        guard let syncedSeconds else { return nil }
        guard let startedAt else { return syncedSeconds }
        return syncedSeconds + DailyTotalCalculator.runningContribution(
            startedAt: startedAt,
            elapsed: elapsed,
            day: day,
            calendar: calendar
        )
    }

    func refresh(force: Bool = false) async {
        guard !teamId.isEmpty else { return }

        if !force, let lastUpdated, now().timeIntervalSince(lastUpdated) < minimumRefreshInterval {
            return
        }
        if let inFlight {
            await inFlight.value
            return
        }

        let task = Task { [weak self] in
            guard let self else { return }
            await self.performRefresh()
        }
        inFlight = task
        await task.value
        inFlight = nil
    }

    private func performRefresh() async {
        isRefreshing = true
        defer { isRefreshing = false }

        let bounds = DailyTotalCalculator.dayBounds(for: now(), calendar: calendar)
        do {
            let entries = try await api.getTimeEntries(
                teamId: teamId,
                startDate: bounds.start,
                endDate: bounds.end,
                assignee: nil
            )
            syncedSeconds = DailyTotalCalculator.total(
                from: entries,
                day: bounds.start,
                calendar: calendar,
                userId: userId
            )
            lastUpdated = now()
            isStale = false
            lastError = nil
            retryTask?.cancel()
            retryTask = nil
        } catch let error as APIError {
            // An expired token is not a transient failure; leave it to the auth layer.
            if case .unauthorized = error {
                lastError = error.localizedDescription
                isStale = true
                return
            }
            markFailed(error)
        } catch {
            markFailed(error)
        }
    }

    /// Never discards a good value on failure — a stale figure beats a blank one.
    private func markFailed(_ error: Error) {
        lastError = error.localizedDescription
        isStale = true
        scheduleRetry()
    }

    /// `ClickUpAPI` already retries internally; this is the one extra attempt on top.
    private func scheduleRetry() {
        guard retryTask == nil else { return }
        retryTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 60 * 1_000_000_000)
            guard !Task.isCancelled else { return }
            await self?.refresh(force: true)
            self?.retryTask = nil
        }
    }

    /// Credits a just-synced entry immediately, so the chip updates without waiting
    /// for the network round trip.
    func applyOptimistic(seconds: TimeInterval) {
        guard let current = syncedSeconds else { return }
        syncedSeconds = current + max(0, seconds)
    }

    /// Resets the total when the calendar day changes underneath us.
    func rolloverIfNeeded() {
        let today = calendar.startOfDay(for: now())
        guard today != day else { return }
        day = today
        syncedSeconds = nil
        lastUpdated = nil
        isStale = false
        Task { await refresh(force: true) }
    }

    /// Polls only while the timer runs — a closed panel with no session has nothing
    /// to keep fresh.
    func setPollingEnabled(_ enabled: Bool) {
        pollTimer?.invalidate()
        pollTimer = nil
        guard enabled else { return }

        let timer = Timer(timeInterval: pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.rolloverIfNeeded()
                await self?.refresh(force: true)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }
}
