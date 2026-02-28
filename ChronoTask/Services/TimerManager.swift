import Foundation

enum TimerState {
    case idle
    case running
    case syncing
}

final class TimerManager: ObservableObject {
    @Published var state: TimerState = .idle
    @Published var elapsed: TimeInterval = 0
    @Published var syncError: String?

    private var startTime: Date?
    private var timer: Timer?
    private var currentTask: ClickUpTask?
    private var teamId: String = ""

    private let api = ClickUpAPI.shared

    var isRunning: Bool { state == .running }
    var isSyncing: Bool { state == .syncing }

    func configure(teamId: String) {
        self.teamId = teamId
    }

    // MARK: - Start

    func start(task: ClickUpTask) {
        guard state == .idle else { return }

        currentTask = task
        startTime = Date()
        elapsed = 0
        syncError = nil
        state = .running

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.startTime else { return }
            DispatchQueue.main.async {
                self.elapsed = Date().timeIntervalSince(startTime)
            }
        }
        RunLoop.current.add(timer!, forMode: .common)
    }

    // MARK: - Stop

    func stop() {
        guard state == .running else { return }
        guard let startTime = startTime, let task = currentTask else { return }

        timer?.invalidate()
        timer = nil

        // Final elapsed calculation
        elapsed = Date().timeIntervalSince(startTime)
        let duration = elapsed
        let start = startTime

        state = .syncing

        Task { @MainActor in
            do {
                _ = try await api.createTimeEntry(
                    teamId: teamId,
                    taskId: task.id,
                    startDate: start,
                    duration: duration
                )
                self.state = .idle
                self.elapsed = 0
                self.startTime = nil
                self.currentTask = nil
                self.syncError = nil
            } catch {
                self.syncError = error.localizedDescription
                self.state = .idle
                // Keep elapsed visible so user can see what was tracked
            }
        }
    }

    // MARK: - Handle task change while running

    /// Stops the current timer (syncing the entry) and starts a new one for the new task
    func switchTask(to newTask: ClickUpTask) {
        if state == .running {
            stop()
            // Start new task after a brief delay to allow sync
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.start(task: newTask)
            }
        }
    }

    // MARK: - Recalculate after sleep/wake

    func recalculateElapsed() {
        guard state == .running, let startTime = startTime else { return }
        elapsed = Date().timeIntervalSince(startTime)
    }
}
