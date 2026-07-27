import Combine
import Foundation

enum TimerState {
    case idle
    case running
    case syncing
}

/// Outcome of stopping the timer, so callers can report accurately instead of
/// guessing from a delay.
enum StopOutcome: Equatable {
    case noop
    case synced(duration: TimeInterval)
    /// The POST failed; the entry is safe in `PendingEntryQueue`.
    case queued(duration: TimeInterval)
}

/// A session recovered at launch, awaiting the user's decision.
struct RecoveredSession: Equatable {
    let taskName: String
    let knownDuration: TimeInterval
    fileprivate let session: PersistedSession
}

@MainActor
final class TimerManager: ObservableObject {
    @Published private(set) var state: TimerState = .idle
    @Published private(set) var elapsed: TimeInterval = 0
    /// Published because the menu bar clock and the peek render it with the panel closed.
    @Published private(set) var currentTask: ClickUpTask?
    @Published var syncError: String?
    @Published private(set) var pendingRecovery: RecoveredSession?

    /// Fires after each entry that reaches ClickUp, so the daily total can refresh.
    let didSyncEntry = PassthroughSubject<TimeInterval, Never>()

    private(set) var startTime: Date?

    private var ticker: Timer?
    private var teamId: String = ""
    private var lastHeartbeat: Date?

    private let api: ClickUpAPIClient
    private let sessionStore: SessionPersisting
    private let pendingQueue: PendingEntryQueue?
    private let now: () -> Date

    /// How often the in-flight session is written to disk. Every second would be
    /// pointless churn; two minutes of exposure is an acceptable worst case.
    private static let heartbeatInterval: TimeInterval = 30

    init(api: ClickUpAPIClient = ClickUpAPI.shared,
         sessionStore: SessionPersisting = SessionStore(),
         pendingQueue: PendingEntryQueue? = nil,
         now: @escaping () -> Date = Date.init) {
        self.api = api
        self.sessionStore = sessionStore
        self.pendingQueue = pendingQueue
        self.now = now
    }

    var isRunning: Bool { state == .running }
    var isSyncing: Bool { state == .syncing }

    func configure(teamId: String) {
        self.teamId = teamId
    }

    // MARK: - Start

    func start(task: ClickUpTask) {
        guard state == .idle else { return }

        let start = now()
        currentTask = task
        startTime = start
        elapsed = 0
        syncError = nil
        state = .running

        persistSession(at: start)
        startTicker()
    }

    /// Built rather than scheduled: `scheduledTimer` already adds itself in
    /// `.default`, so the old code registered the same timer twice. `.common` is what
    /// keeps the menu bar clock ticking while a menu is being tracked.
    private func startTicker() {
        ticker?.invalidate()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func tick() {
        guard let startTime else { return }
        let current = now()
        elapsed = current.timeIntervalSince(startTime)
        if let last = lastHeartbeat, current.timeIntervalSince(last) >= Self.heartbeatInterval {
            persistSession(at: current)
        }
    }

    // MARK: - Stop

    /// Synchronous half of stopping: kills the ticker and lands on `.syncing` before
    /// returning, which is what callers (and the existing tests) observe.
    private func beginStop() -> PendingTimeEntry? {
        guard state == .running,
              let startTime,
              let task = currentTask else { return nil }

        ticker?.invalidate()
        ticker = nil

        elapsed = now().timeIntervalSince(startTime)
        state = .syncing

        return PendingTimeEntry(
            teamId: teamId,
            taskId: task.id,
            taskName: task.name,
            startedAt: startTime,
            duration: elapsed
        )
    }

    func stop() {
        guard let entry = beginStop() else { return }
        Task { await finishStop(entry) }
    }

    /// Same as `stop()` but awaitable — used when the next action depends on the
    /// entry actually having been sent.
    @discardableResult
    func stopAndSync() async -> StopOutcome {
        guard let entry = beginStop() else { return .noop }
        return await finishStop(entry)
    }

    @discardableResult
    private func finishStop(_ entry: PendingTimeEntry) async -> StopOutcome {
        defer { resetAfterStop() }

        do {
            _ = try await api.createTimeEntry(
                teamId: entry.teamId,
                taskId: entry.taskId,
                startDate: entry.startedAt,
                duration: entry.duration
            )
            syncError = nil
            didSyncEntry.send(entry.duration)
            return .synced(duration: entry.duration)
        } catch {
            if let pendingQueue {
                // The time is safe on disk, so this is no longer an error the user
                // has to act on — just a delay.
                pendingQueue.enqueue(entry)
                syncError = "Guardado local · reintentando"
                return .queued(duration: entry.duration)
            }
            syncError = error.localizedDescription
            return .queued(duration: entry.duration)
        }
    }

    private func resetAfterStop() {
        state = .idle
        elapsed = 0
        startTime = nil
        currentTask = nil
        lastHeartbeat = nil
        sessionStore.clear()
    }

    // MARK: - Switching task mid-flight

    /// Stops, waits for the entry to be sent, then starts the new task.
    ///
    /// The previous implementation guessed with a fixed 0.5s delay, which could start
    /// the next timer before the POST finished — and `start()` would then no-op
    /// because the state was still `.syncing`, silently dropping the new session.
    func switchTask(to newTask: ClickUpTask) {
        guard state == .running else { return }
        Task {
            await stopAndSync()
            start(task: newTask)
        }
    }

    // MARK: - Sleep / wake

    func recalculateElapsed() {
        guard state == .running, let startTime else { return }
        elapsed = now().timeIntervalSince(startTime)
    }

    // MARK: - Session persistence

    private func persistSession(at date: Date) {
        guard let startTime, let task = currentTask else { return }
        sessionStore.save(
            PersistedSession(taskId: task.id,
                             taskName: task.name,
                             teamId: teamId,
                             startedAt: startTime,
                             savedAt: date)
        )
        lastHeartbeat = date
    }

    /// Called on `willTerminate` / `willSleep` so the last known-good moment is as
    /// recent as possible.
    func persistHeartbeat() {
        guard state == .running else { return }
        persistSession(at: now())
    }

    /// Inspects any session left behind by a previous run and either resumes it,
    /// surfaces it for the user to decide, or drops it.
    func restoreSession() {
        guard state == .idle, let session = sessionStore.load() else { return }

        switch SessionRecoveryPolicy.evaluate(session, now: now()) {
        case .discard:
            sessionStore.clear()

        case .resume:
            teamId = session.teamId
            currentTask = ClickUpTask(id: session.taskId, name: session.taskName)
            startTime = session.startedAt
            elapsed = now().timeIntervalSince(session.startedAt)
            state = .running
            lastHeartbeat = now()
            startTicker()

        case .prompt(let knownDuration):
            pendingRecovery = RecoveredSession(taskName: session.taskName,
                                               knownDuration: knownDuration,
                                               session: session)
        }
    }

    /// Logs only the stretch up to the last heartbeat — never the unaccounted gap.
    func acceptRecovery() {
        guard let recovery = pendingRecovery else { return }
        let session = recovery.session
        pendingRecovery = nil
        sessionStore.clear()

        let entry = PendingTimeEntry(
            teamId: session.teamId,
            taskId: session.taskId,
            taskName: session.taskName,
            startedAt: session.startedAt,
            duration: recovery.knownDuration
        )

        Task {
            do {
                _ = try await api.createTimeEntry(
                    teamId: entry.teamId,
                    taskId: entry.taskId,
                    startDate: entry.startedAt,
                    duration: entry.duration
                )
                didSyncEntry.send(entry.duration)
            } catch {
                pendingQueue?.enqueue(entry)
            }
        }
    }

    func discardRecovery() {
        pendingRecovery = nil
        sessionStore.clear()
    }
}
