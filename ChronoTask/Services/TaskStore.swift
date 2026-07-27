import Combine
import Foundation

/// Owns the task list and the current selection.
///
/// This used to be `@State` inside `MainView`. With an anchored panel that view is
/// torn down and rebuilt constantly, so keeping it there meant a network round trip
/// and an empty list on every single open.
@MainActor
final class TaskStore: ObservableObject {

    enum Phase: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    /// Already filtered down to trackable tasks.
    @Published private(set) var tasks: [ClickUpTask] = []
    /// How many the API returned before filtering — lets the UI tell "nothing
    /// assigned to you" apart from "everything you have is closed".
    @Published private(set) var rawCount: Int = 0
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var lastLoaded: Date?

    @Published var selectedTask: ClickUpTask? {
        didSet {
            guard selectedTask?.id != oldValue?.id else { return }
            preferences.setSelectedTask(selectedTask)
        }
    }

    /// Invoked when the API rejects our token, so the app can send the user back to
    /// the setup screen.
    var onUnauthorized: (() -> Void)?

    private let api: ClickUpAPIClient
    private let preferences: AppPreferences
    private let ttl: TimeInterval
    private let now: () -> Date

    private var teamId: String = ""
    private var userId: Int = 0
    private var inFlight: Task<Void, Never>?

    init(api: ClickUpAPIClient = ClickUpAPI.shared,
         preferences: AppPreferences = AppPreferences(),
         ttl: TimeInterval = 300,
         now: @escaping () -> Date = Date.init) {
        self.api = api
        self.preferences = preferences
        self.ttl = ttl
        self.now = now
    }

    func configure(teamId: String, userId: Int) {
        guard self.teamId != teamId || self.userId != userId else { return }
        self.teamId = teamId
        self.userId = userId
        // Credentials changed: whatever we cached belongs to another workspace.
        tasks = []
        rawCount = 0
        lastLoaded = nil
        phase = .idle
    }

    /// Restores the previous selection from disk so the panel shows a task name
    /// immediately, before any network call resolves.
    func restoreSelection() {
        guard selectedTask == nil else { return }
        selectedTask = preferences.selectedTaskSnapshot
    }

    var isStale: Bool {
        guard let lastLoaded else { return true }
        return now().timeIntervalSince(lastLoaded) >= ttl
    }

    /// Loads only if the cache has expired. Concurrent callers share one request —
    /// the panel can be opened repeatedly in quick succession.
    func loadIfStale() async {
        if let inFlight {
            await inFlight.value
            return
        }
        guard isStale else { return }
        await refresh()
    }

    func refresh() async {
        if let inFlight {
            await inFlight.value
            return
        }
        guard !teamId.isEmpty else { return }

        let task = Task { [weak self] in
            guard let self else { return }
            await self.performLoad()
        }
        inFlight = task
        await task.value
        inFlight = nil
    }

    private func performLoad() async {
        phase = .loading
        do {
            let fetched = try await api.getTasks(teamId: teamId, userId: userId)
            rawCount = fetched.count
            tasks = TaskEligibility.filter(fetched)
            lastLoaded = now()
            phase = .loaded
            reconcileSelection()
        } catch let error as APIError {
            if case .unauthorized = error {
                onUnauthorized?()
                return
            }
            phase = .failed(error.localizedDescription)
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    /// Re-points the selection at the freshly fetched instance, or clears it if the
    /// task is gone or no longer trackable.
    private func reconcileSelection() {
        guard let selectedId = selectedTask?.id else { return }
        if let match = tasks.first(where: { $0.id == selectedId }) {
            selectedTask = match
        } else {
            selectedTask = nil
        }
    }
}
