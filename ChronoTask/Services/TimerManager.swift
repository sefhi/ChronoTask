import Combine
import Foundation

enum TimerState {
    case idle
    case running
    /// Nothing is running any more, but a stopped entry is still on its way to
    /// ClickUp.
    case syncing
}

/// Outcome of stopping, so callers can report accurately instead of guessing from a
/// delay.
enum StopOutcome: Equatable {
    case noop
    case synced(duration: TimeInterval)
    /// At least one POST failed; those entries are safe in `PendingEntryQueue`.
    case queued(duration: TimeInterval)

    var duration: TimeInterval {
        switch self {
        case .noop: return 0
        case .synced(let duration), .queued(let duration): return duration
        }
    }

    /// Folds the outcomes of several stops into one: synced only if every entry was.
    static func combined(_ outcomes: [StopOutcome]) -> StopOutcome {
        let real = outcomes.filter { $0 != .noop }
        guard !real.isEmpty else { return .noop }
        let total = real.reduce(0) { $0 + $1.duration }
        let allSynced = real.allSatisfy { if case .synced = $0 { return true } else { return false } }
        return allSynced ? .synced(duration: total) : .queued(duration: total)
    }
}

/// One task being timed. Several can run side by side.
struct RunningTimer: Identifiable, Equatable {
    let task: ClickUpTask
    let startedAt: Date

    var id: String { task.id }

    func elapsed(at date: Date) -> TimeInterval {
        max(0, date.timeIntervalSince(startedAt))
    }
}

/// Sessions recovered at launch, awaiting the user's decision. They share one
/// heartbeat, so they are offered — and accepted or discarded — together.
struct RecoveredSession: Equatable {
    fileprivate struct Item: Equatable {
        let session: PersistedSession
        let knownDuration: TimeInterval
    }

    fileprivate let items: [Item]

    var taskName: String {
        items.count == 1 ? items[0].session.taskName : "\(items.count) tareas en paralelo"
    }

    var knownDuration: TimeInterval {
        items.reduce(0) { $0 + $1.knownDuration }
    }
}

@MainActor
final class TimerManager: ObservableObject {
    /// Oldest first. The order is what the parallel list and the peek show.
    @Published private(set) var runs: [RunningTimer] = []
    /// The run shown large in the panel and in the menu bar.
    @Published private(set) var focusedTaskId: String?
    /// Advances once a second while anything runs. Every elapsed figure is derived
    /// from it, so one publish redraws all the clocks at once.
    @Published private(set) var clock: Date
    @Published private(set) var state: TimerState = .idle
    @Published var syncError: String?
    @Published private(set) var pendingRecovery: RecoveredSession?

    /// Fires after each entry that reaches ClickUp, so the daily total can refresh.
    let didSyncEntry = PassthroughSubject<TimeInterval, Never>()

    private var ticker: Timer?
    private var teamId: String = ""
    private var lastHeartbeat: Date?
    private var uploadsInFlight = 0

    private let api: ClickUpAPIClient
    private let sessionStore: SessionPersisting
    private let pendingQueue: PendingEntryQueue?
    private let now: () -> Date

    /// How often the in-flight sessions are written to disk. Every second would be
    /// pointless churn; a few minutes of exposure is an acceptable worst case.
    private static let heartbeatInterval: TimeInterval = 30

    init(api: ClickUpAPIClient = ClickUpAPI.shared,
         sessionStore: SessionPersisting = SessionStore(),
         pendingQueue: PendingEntryQueue? = nil,
         now: @escaping () -> Date = Date.init) {
        self.api = api
        self.sessionStore = sessionStore
        self.pendingQueue = pendingQueue
        self.now = now
        self.clock = now()
    }

    var isRunning: Bool { !runs.isEmpty }
    var isSyncing: Bool { state == .syncing }

    /// Falls back to the first run so a dangling focus id can never blank the panel.
    var focusedRun: RunningTimer? {
        runs.first { $0.id == focusedTaskId } ?? runs.first
    }

    /// Every run except the focused one — the "en paralelo" list.
    var parallelRuns: [RunningTimer] {
        guard let focused = focusedRun else { return [] }
        return runs.filter { $0.id != focused.id }
    }

    /// The focused run's elapsed time; zero when nothing runs.
    var elapsed: TimeInterval {
        focusedRun?.elapsed(at: clock) ?? 0
    }

    func elapsed(of run: RunningTimer) -> TimeInterval {
        run.elapsed(at: clock)
    }

    /// Sum over every run — "Total · 01:02:03 en 3 tareas".
    var totalElapsed: TimeInterval {
        runs.reduce(0) { $0 + $1.elapsed(at: clock) }
    }

    func isRunning(taskId: String) -> Bool {
        runs.contains { $0.id == taskId }
    }

    func configure(teamId: String) {
        self.teamId = teamId
    }

    // MARK: - Start

    /// Adds `task` alongside whatever is already running and focuses it. Starting a
    /// task that is already running only moves the focus to it.
    func start(task: ClickUpTask) {
        if isRunning(taskId: task.id) {
            focusedTaskId = task.id
            return
        }

        let start = now()
        clock = start
        runs.append(RunningTimer(task: task, startedAt: start))
        focusedTaskId = task.id
        syncError = nil
        updateState()

        persistSessions(at: start)
        startTickerIfNeeded()
    }

    func focus(taskId: String) {
        guard isRunning(taskId: taskId) else { return }
        focusedTaskId = taskId
    }

    /// ⇥ / ⇧⇥: the next or previous run in start order, wrapping at either end.
    func cycleFocus(backwards: Bool = false) {
        guard runs.count > 1, let current = focusedRun,
              let index = runs.firstIndex(where: { $0.id == current.id }) else { return }
        let step = backwards ? runs.count - 1 : 1
        focusedTaskId = runs[(index + step) % runs.count].id
    }

    /// Built rather than scheduled: `scheduledTimer` already adds itself in
    /// `.default`, so the old code registered the same timer twice. `.common` is what
    /// keeps the menu bar clock ticking while a menu is being tracked.
    private func startTickerIfNeeded() {
        guard ticker == nil else { return }
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func tick() {
        guard isRunning else { return }
        let current = now()
        clock = current
        if let last = lastHeartbeat, current.timeIntervalSince(last) >= Self.heartbeatInterval {
            persistSessions(at: current)
        }
    }

    // MARK: - Stop

    /// Takes the run off the list synchronously — before any await — so a second
    /// click on the same stop button can never post the entry twice.
    private func detach(taskId: String) -> PendingTimeEntry? {
        guard let index = runs.firstIndex(where: { $0.id == taskId }) else { return nil }
        let run = runs.remove(at: index)
        let stoppedAt = now()
        clock = stoppedAt

        if focusedTaskId == taskId {
            focusedTaskId = runs.first?.id
        }
        if runs.isEmpty {
            stopTicker()
            lastHeartbeat = nil
            sessionStore.clear()
        } else {
            persistSessions(at: stoppedAt)
        }

        uploadsInFlight += 1
        updateState()

        return PendingTimeEntry(
            teamId: teamId,
            taskId: run.task.id,
            taskName: run.task.name,
            startedAt: run.startedAt,
            duration: run.elapsed(at: stoppedAt)
        )
    }

    /// Stops one run and waits for its entry to be sent (or queued).
    @discardableResult
    func stop(taskId: String) async -> StopOutcome {
        guard let entry = detach(taskId: taskId) else { return .noop }
        return await upload(entry)
    }

    /// Stops every run. All of them are detached at once, then uploaded together.
    @discardableResult
    func stopAll() async -> StopOutcome {
        let entries = runs.map(\.id).compactMap(detach(taskId:))
        return await uploadAll(entries)
    }

    /// "Solo esta": stops everything except `taskId`, which keeps running and takes
    /// the focus.
    @discardableResult
    func keepOnly(taskId: String) async -> StopOutcome {
        guard isRunning(taskId: taskId) else { return .noop }
        focusedTaskId = taskId
        let entries = runs.map(\.id).filter { $0 != taskId }.compactMap(detach(taskId:))
        return await uploadAll(entries)
    }

    private func uploadAll(_ entries: [PendingTimeEntry]) async -> StopOutcome {
        var outcomes: [StopOutcome] = []
        for entry in entries {
            outcomes.append(await upload(entry))
        }
        return StopOutcome.combined(outcomes)
    }

    private func upload(_ entry: PendingTimeEntry) async -> StopOutcome {
        defer {
            uploadsInFlight -= 1
            updateState()
        }

        do {
            _ = try await api.createTimeEntry(
                teamId: entry.teamId,
                taskId: entry.taskId,
                startDate: entry.startedAt,
                duration: entry.duration
            )
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

    private func updateState() {
        let next: TimerState = isRunning ? .running : (uploadsInFlight > 0 ? .syncing : .idle)
        if state != next { state = next }
    }

    // MARK: - Sleep / wake

    func recalculateElapsed() {
        guard isRunning else { return }
        clock = now()
    }

    // MARK: - Session persistence

    private func persistSessions(at date: Date) {
        sessionStore.saveAll(runs.map {
            PersistedSession(taskId: $0.task.id,
                             taskName: $0.task.name,
                             teamId: teamId,
                             startedAt: $0.startedAt,
                             savedAt: date)
        })
        lastHeartbeat = date
    }

    /// Called on `willTerminate` / `willSleep` so the last known-good moment is as
    /// recent as possible.
    func persistHeartbeat() {
        guard isRunning else { return }
        persistSessions(at: now())
    }

    /// Inspects the sessions left behind by a previous run and, one by one, resumes
    /// them, holds them for the user to decide, or drops them.
    func restoreSession() {
        guard !isRunning else { return }
        let sessions = sessionStore.loadAll()
        guard !sessions.isEmpty else { return }

        let current = now()
        var toPrompt: [RecoveredSession.Item] = []

        for session in sessions {
            switch SessionRecoveryPolicy.evaluate(session, now: current) {
            case .discard:
                break
            case .resume:
                guard !isRunning(taskId: session.taskId) else { continue }
                teamId = session.teamId
                runs.append(RunningTimer(task: ClickUpTask(id: session.taskId, name: session.taskName),
                                         startedAt: session.startedAt))
            case .prompt(let knownDuration):
                toPrompt.append(.init(session: session, knownDuration: knownDuration))
            }
        }

        if isRunning {
            focusedTaskId = runs.first?.id
            clock = current
            updateState()
            persistSessions(at: current)
            startTickerIfNeeded()
        } else if toPrompt.isEmpty {
            sessionStore.clear()
        }
        // With nothing resumed, sessions awaiting a decision stay on disk so an
        // unanswered prompt survives another relaunch. Once a run resumes, the next
        // heartbeat overwrites them — the prompt still holds them in memory.

        if !toPrompt.isEmpty {
            pendingRecovery = RecoveredSession(items: toPrompt)
        }
    }

    /// Logs only the stretch up to the last heartbeat — never the unaccounted gap.
    func acceptRecovery() {
        guard let recovery = pendingRecovery else { return }
        pendingRecovery = nil
        if !isRunning { sessionStore.clear() }

        let entries = recovery.items.map {
            PendingTimeEntry(
                teamId: $0.session.teamId,
                taskId: $0.session.taskId,
                taskName: $0.session.taskName,
                startedAt: $0.session.startedAt,
                duration: $0.knownDuration
            )
        }

        Task {
            for entry in entries {
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
    }

    func discardRecovery() {
        pendingRecovery = nil
        if !isRunning { sessionStore.clear() }
    }
}
