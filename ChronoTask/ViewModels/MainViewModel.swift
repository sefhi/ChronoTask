import AppKit
import Combine
import Foundation

/// Panel presentation state.
///
/// Task loading lives in `TaskStore` and the running timers in `TimerManager` (both
/// outlive the panel); what is here is purely about how the panel is being used.
@MainActor
final class MainViewModel: ObservableObject {

    @Published var isListOpen = false
    @Published var isMenuOpen = false
    @Published var query = ""
    @Published var focusedIndex: Int?
    @Published var hoveredIndex: Int?
    @Published var toast: Toast?

    private let taskStore: TaskStore
    private let timerManager: TimerManager
    private var toastDismissal: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    init(taskStore: TaskStore, timerManager: TimerManager) {
        self.taskStore = taskStore
        self.timerManager = timerManager

        // Keep the keyboard cursor inside the list as it is filtered.
        $query
            .sink { [weak self] _ in
                guard let self else { return }
                self.focusedIndex = self.filteredTasks(matching: self.query).isEmpty ? nil : 0
            }
            .store(in: &cancellables)
    }

    deinit {
        toastDismissal?.cancel()
    }

    // MARK: - Filtering

    var filteredTasks: [ClickUpTask] {
        filteredTasks(matching: query)
    }

    /// Tasks already running are left out: the list is for starting one, and those
    /// are a click away in the panel above it.
    private func filteredTasks(matching query: String) -> [ClickUpTask] {
        let trimmed = query.trimmingCharacters(in: .whitespaces).lowercased()
        return taskStore.tasks.filter { task in
            !timerManager.isRunning(taskId: task.id)
                && (trimmed.isEmpty || task.name.lowercased().contains(trimmed))
        }
    }

    /// Distinguishes "your search matched nothing" from "you have no trackable tasks"
    /// from "the load failed" — three very different things to tell the user.
    var emptyMessage: String {
        if case .failed(let message) = taskStore.phase { return message }
        if !query.trimmingCharacters(in: .whitespaces).isEmpty { return "Sin resultados" }
        if taskStore.rawCount == 0 { return "No tienes tareas asignadas" }
        if !taskStore.tasks.isEmpty { return "Todas tus tareas están en marcha" }
        return "Todas tus tareas están cerradas"
    }

    // MARK: - List

    func openList() {
        guard !isListOpen else { return }
        query = ""
        isListOpen = true
        focusedIndex = filteredTasks.isEmpty ? nil : 0
    }

    func closeList() {
        guard isListOpen else { return }
        isListOpen = false
        query = ""
        focusedIndex = nil
        hoveredIndex = nil
    }

    func toggleList() {
        isListOpen ? closeList() : openList()
    }

    // MARK: - Header menu

    func toggleMenu() {
        isMenuOpen.toggle()
    }

    func closeMenu() {
        isMenuOpen = false
    }

    func moveFocus(_ direction: ArrowDirection) {
        let tasks = filteredTasks
        guard !tasks.isEmpty else { return }
        switch direction {
        case .down:
            focusedIndex = focusedIndex.map { min($0 + 1, tasks.count - 1) } ?? 0
        case .up:
            focusedIndex = focusedIndex.map { max($0 - 1, 0) } ?? (tasks.count - 1)
        }
    }

    func commitFocused() {
        let tasks = filteredTasks
        guard let index = focusedIndex, tasks.indices.contains(index) else { return }
        start(tasks[index])
    }

    /// Picking a task starts it, alongside whatever already runs. It is also
    /// remembered as the last task, which the status item's menu can restart.
    func start(_ task: ClickUpTask) {
        timerManager.start(task: task)
        taskStore.selectedTask = task
        closeList()
    }

    /// The panel became visible. With nothing running, the list opens itself so the
    /// first thing the user sees is the choice they have to make.
    func onPanelPresented() {
        if !timerManager.isRunning {
            openList()
        }
    }

    // MARK: - Toast

    /// A toast is purely visual; VoiceOver users would never learn that an entry was
    /// logged, or that it failed and was queued. This reads it out as well.
    private func announce(_ message: String) {
        NSAccessibility.post(
            element: NSApp as Any,
            notification: .announcementRequested,
            userInfo: [
                .announcement: message,
                .priority: NSAccessibilityPriorityLevel.high.rawValue
            ]
        )
    }

    func showToast(_ message: String, type: ToastType) {
        toastDismissal?.cancel()
        toast = Toast(message: message, type: type)
        announce(message)
        toastDismissal = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
    }
}
