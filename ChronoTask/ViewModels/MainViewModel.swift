import Combine
import Foundation

/// Panel presentation state.
///
/// Task loading and selection live in `TaskStore` (they outlive the panel); what is
/// here is purely about how the panel is currently being used.
@MainActor
final class MainViewModel: ObservableObject {

    @Published var isListOpen = false
    @Published var query = ""
    @Published var focusedIndex: Int?
    @Published var hoveredIndex: Int?
    @Published var toast: Toast?

    private let taskStore: TaskStore
    private var toastDismissal: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    init(taskStore: TaskStore) {
        self.taskStore = taskStore

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

    private func filteredTasks(matching query: String) -> [ClickUpTask] {
        let trimmed = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty else { return taskStore.tasks }
        return taskStore.tasks.filter { $0.name.lowercased().contains(trimmed) }
    }

    /// Distinguishes "your search matched nothing" from "you have no trackable tasks"
    /// from "the load failed" — three very different things to tell the user.
    var emptyMessage: String {
        if case .failed(let message) = taskStore.phase { return message }
        if !query.trimmingCharacters(in: .whitespaces).isEmpty { return "Sin resultados" }
        if taskStore.rawCount == 0 { return "No tienes tareas asignadas" }
        return "Todas tus tareas están cerradas"
    }

    // MARK: - List

    func openList() {
        guard !isListOpen else { return }
        query = ""
        isListOpen = true
        // Start the cursor on the current selection so Enter is a no-op rather than a
        // surprise.
        let tasks = filteredTasks
        focusedIndex = tasks.firstIndex { $0.id == taskStore.selectedTask?.id } ?? (tasks.isEmpty ? nil : 0)
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
        select(tasks[index])
    }

    func select(_ task: ClickUpTask) {
        taskStore.selectedTask = task
        closeList()
    }

    /// The panel became visible. With no task chosen, the list opens itself so the
    /// first thing the user sees is the choice they have to make.
    func onPanelPresented() {
        if taskStore.selectedTask == nil {
            openList()
        }
    }

    // MARK: - Toast

    func showToast(_ message: String, type: ToastType) {
        toastDismissal?.cancel()
        toast = Toast(message: message, type: type)
        toastDismissal = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
    }
}
