import AppKit
import SwiftUI

struct MainView: View {
    @EnvironmentObject var appState: AppState
    /// All owned by `AppEnvironment`: the menu bar clock and the peek observe them
    /// while this view is not on screen at all.
    @EnvironmentObject var timerManager: TimerManager
    @EnvironmentObject var taskStore: TaskStore
    @EnvironmentObject var dailyTotal: DailyTotalService

    @StateObject private var viewModel: MainViewModel
    @FocusState private var searchFocused: Bool

    init(taskStore: TaskStore) {
        _viewModel = StateObject(wrappedValue: MainViewModel(taskStore: taskStore))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            StatusPill(state: pillState)

            TimerDisplay(elapsed: timerManager.elapsed)
                .padding(.top, 6)

            TodaySummaryLine(total: displayedTotal, isStale: dailyTotal.isStale)
                .padding(.top, 1)

            if let recovery = timerManager.pendingRecovery {
                SessionRecoveryPrompt(
                    taskName: recovery.taskName,
                    knownDuration: recovery.knownDuration,
                    onAccept: {
                        timerManager.acceptRecovery()
                        viewModel.showToast("Sesión recuperada", type: .success)
                    },
                    onDiscard: { timerManager.discardRecovery() }
                )
                .padding(.top, 12)
            }

            TaskCaption(task: taskStore.selectedTask,
                        isRunning: timerManager.isRunning,
                        isExpanded: viewModel.isListOpen) {
                viewModel.toggleList()
            }
            .padding(.top, 12)

            taskList

            HStack(spacing: Theme.controlGap) {
                PrimaryActionButton(isRunning: timerManager.isRunning,
                                    isEnabled: canToggleTimer,
                                    action: toggleTimer)
                DailyTotalChip(total: displayedTotal)
            }
            .padding(.top, 12)
        }
        .padding(.horizontal, Theme.panelPadH)
        .padding(.top, Theme.panelPadTop)
        .padding(.bottom, Theme.panelPadBottom)
        .frame(width: Theme.panelWidth)
        .background { KeyCatcher(handler: handleKey).frame(width: 0, height: 0) }
        .overlay(alignment: .top) { toastOverlay }
        .onChange(of: viewModel.isListOpen) { isOpen in
            searchFocused = isOpen
        }
        .onChange(of: taskStore.selectedTask?.id) { _ in
            handleTaskChange()
        }
        .onChange(of: timerManager.syncError) { error in
            if let error { viewModel.showToast(error, type: .error) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .panelDidPresent)) { _ in
            viewModel.onPanelPresented()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openTaskListRequested)) { _ in
            viewModel.openList()
        }
    }

    // MARK: - Task list

    /// Animating an explicit height (rather than using a transition) is what lets the
    /// window grow smoothly: a transition would insert the list at full size on the
    /// first frame, so the window would jump and the content would fade in after.
    private var taskList: some View {
        TaskListPanel(
            tasks: viewModel.filteredTasks,
            selectedTaskID: taskStore.selectedTask?.id,
            focusedIndex: viewModel.focusedIndex,
            emptyMessage: viewModel.emptyMessage,
            query: $viewModel.query,
            searchFocus: $searchFocused,
            onSelect: { viewModel.select($0) },
            onHoverRow: { viewModel.hoveredIndex = $0 }
        )
        .frame(height: viewModel.isListOpen ? Theme.listMaxHeight : 0, alignment: .top)
        .clipped()
        .opacity(viewModel.isListOpen ? 1 : 0)
        // `clipped()` does not stop hit-testing outside the frame, so collapsed rows
        // would still swallow clicks meant for the button below.
        .allowsHitTesting(viewModel.isListOpen)
        // Crucially this also takes the search field out of the focus chain. The
        // collapsed list stays mounted so its height can animate, and AppKit would
        // otherwise hand it first responder when the panel becomes key — swallowing
        // every SPACE as typed text.
        .disabled(!viewModel.isListOpen)
        .accessibilityHidden(!viewModel.isListOpen)
        // Scoped to `isListOpen` on purpose: a blanket `withAnimation` would drag the
        // once-per-second timer tick into this animation.
        .animation(Theme.listAnimation, value: viewModel.isListOpen)
    }

    @ViewBuilder
    private var toastOverlay: some View {
        if let toast = viewModel.toast {
            ToastView(toast: toast)
                .padding(.top, 8)
                .transition(.opacity)
                .animation(Theme.toastAnimation, value: toast)
        }
    }

    // MARK: - Derived state

    private var pillState: PillState {
        if timerManager.isRunning { return .recording }
        return taskStore.selectedTask == nil ? .noTask : .ready
    }

    private var canToggleTimer: Bool {
        if timerManager.isRunning { return true }
        return taskStore.selectedTask != nil && !timerManager.isSyncing
    }

    private var displayedTotal: TimeInterval? {
        dailyTotal.displayTotal(runningSince: timerManager.startTime,
                                elapsed: timerManager.elapsed)
    }

    // MARK: - Actions

    private func toggleTimer() {
        if timerManager.isRunning {
            // Reports what actually happened instead of guessing after a fixed delay.
            Task {
                if case .synced = await timerManager.stopAndSync() {
                    viewModel.showToast("Tiempo registrado", type: .success)
                }
            }
        } else if let task = taskStore.selectedTask {
            timerManager.start(task: task)
        }
    }

    private func handleTaskChange() {
        guard let task = taskStore.selectedTask, timerManager.isRunning else { return }
        timerManager.switchTask(to: task)
    }

    // MARK: - Keyboard

    private func handleKey(_ key: ChronoKey) -> Bool {
        switch key {
        case .escape:
            // Two nested scopes: the list closes first, the panel only after.
            if viewModel.isListOpen {
                viewModel.closeList()
            } else {
                NotificationCenter.default.post(name: .panelDismissRequested, object: nil)
            }
            return true

        case .down:
            // With the list closed, ↓ opens it. It is the one key people try first,
            // and it means the whole flow works without ever touching the mouse.
            if !viewModel.isListOpen {
                viewModel.openList()
            } else {
                viewModel.moveFocus(.down)
            }
            return true

        case .up:
            guard viewModel.isListOpen else { return false }
            viewModel.moveFocus(.up)
            return true

        case .slash, .findShortcut:
            // `/`, `⌘K` and `⌘F` all land on the search field.
            viewModel.openList()
            return true

        case .enter:
            // Enter now means "pick this row" and no longer doubles as start/stop —
            // with the list open the old dual meaning was ambiguous.
            guard viewModel.isListOpen else { return false }
            viewModel.commitFocused()
            return true

        case .space:
            guard canToggleTimer else { return false }
            toggleTimer()
            return true

        case .quickPick(let index):
            // ⌘1…⌘9 pick a task outright, and start it if nothing is running.
            let tasks = viewModel.filteredTasks
            guard tasks.indices.contains(index) else { return true }
            let task = tasks[index]
            viewModel.select(task)
            if !timerManager.isRunning && !timerManager.isSyncing {
                timerManager.start(task: task)
            }
            return true
        }
    }
}
