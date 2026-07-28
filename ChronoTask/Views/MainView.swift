import AppKit
import SwiftUI

struct MainView: View {
    @EnvironmentObject var environment: AppEnvironment
    @EnvironmentObject var appState: AppState
    /// All owned by `AppEnvironment`: the menu bar clock and the peek observe them
    /// while this view is not on screen at all.
    @EnvironmentObject var timerManager: TimerManager
    @EnvironmentObject var taskStore: TaskStore
    @EnvironmentObject var dailyTotal: DailyTotalService

    @StateObject private var viewModel: MainViewModel
    @FocusState private var searchFocused: Bool

    /// Drives the "Actualizado hace X min" line. Re-read from a ticker rather than
    /// computed once, or the label would freeze at whatever it said when the panel
    /// opened.
    @State private var clockTick = Date()

    private let syncedTicker = Timer
        .publish(every: Theme.syncedLabelRefresh, on: .main, in: .common)
        .autoconnect()

    init(taskStore: TaskStore) {
        _viewModel = StateObject(wrappedValue: MainViewModel(taskStore: taskStore))
    }

    var body: some View {
        // Three layers so a click anywhere else in the panel closes the menu: content,
        // then a transparent catcher, then the menu itself on top. An `.overlay` on the
        // content could not sit *between* the two.
        ZStack(alignment: .topTrailing) {
            content

            if viewModel.isMenuOpen {
                Color.black.opacity(0.001)
                    .contentShape(Rectangle())
                    .onTapGesture { viewModel.closeMenu() }
            }

            menuOverlay
        }
        .frame(width: Theme.panelWidth)
        .background { KeyCatcher(handler: handleKey).frame(width: 0, height: 0) }
        .overlay(alignment: .top) { toastOverlay }
        .animation(Theme.menuAnimation, value: viewModel.isMenuOpen)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

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
        .onChange(of: viewModel.isListOpen) { isOpen in
            searchFocused = isOpen
            // The ticker is suppressed while the list is closed, so catch up here
            // instead of showing a minute count frozen from last time.
            if isOpen { clockTick = Date() }
        }
        .onChange(of: taskStore.lastLoaded) { _ in
            // A finished load must read "hace un momento" immediately, not on the
            // ticker's next turn up to 20s later.
            clockTick = Date()
        }
        .onChange(of: taskStore.selectedTask?.id) { _ in
            handleTaskChange()
        }
        .onChange(of: timerManager.syncError) { error in
            if let error { viewModel.showToast(error, type: .error) }
        }
        .onReceive(syncedTicker) { date in
            // The collapsed list stays mounted so its height can animate, so this
            // fires whether or not anything is on screen. Redrawing only while it is
            // visible keeps a closed panel completely idle.
            guard viewModel.isListOpen else { return }
            clockTick = date
        }
        .onReceive(NotificationCenter.default.publisher(for: .panelDidPresent)) { _ in
            viewModel.onPanelPresented()
            // Opening after a long gap would otherwise show the stale minute count
            // from the last time the list was open.
            clockTick = Date()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openTaskListRequested)) { _ in
            viewModel.openList()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            ChronoMarkView(isRunning: timerManager.isRunning,
                           size: 18,
                           color: timerManager.isRunning ? Theme.accent : Theme.markHeader)
            StatusPill(state: pillState)
            Spacer(minLength: 8)
            PanelMenuButton(isOpen: viewModel.isMenuOpen) {
                viewModel.toggleMenu()
            }
        }
    }

    /// Floats over the content rather than taking part in the layout: the panel sizes
    /// itself to what it contains, so a menu in the flow would grow the window as it
    /// opened. Insets match the prototype's `top:22px; right:-6px` off the header,
    /// which itself sits inside the panel's padding.
    @ViewBuilder
    private var menuOverlay: some View {
        if viewModel.isMenuOpen {
            PanelMenu(onSelect: handleMenu)
                .padding(.trailing, Theme.panelPadH - 6)
                .padding(.top, Theme.panelPadTop + 22)
                .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .topTrailing)))
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
            syncedLabel: SyncLabel.text(lastLoaded: taskStore.lastLoaded,
                                        now: clockTick,
                                        isSyncing: taskStore.phase == .loading),
            isSyncing: taskStore.phase == .loading,
            query: $viewModel.query,
            searchFocus: $searchFocused,
            onSelect: { viewModel.select($0) },
            onHoverRow: { viewModel.hoveredIndex = $0 },
            onRefresh: { Task { await taskStore.refresh() } }
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

    private func handleMenu(_ action: PanelMenuAction) {
        viewModel.closeMenu()
        switch action {
        case .about:
            environment.showAbout()
        case .changeAPIKey:
            appState.logout()
        case .quit:
            environment.quit()
        }
    }

    private func handleTaskChange() {
        guard let task = taskStore.selectedTask, timerManager.isRunning else { return }
        timerManager.switchTask(to: task)
    }

    // MARK: - Keyboard

    private func handleKey(_ key: ChronoKey) -> Bool {
        // The menu is modal in spirit: while it is up it takes the keyboard, so no
        // shortcut fires behind an open menu.
        if viewModel.isMenuOpen {
            switch key {
            case .escape:
                viewModel.closeMenu()
            case .quit:
                handleMenu(.quit)
            default:
                break
            }
            return true
        }

        switch key {
        case .escape:
            // Three nested scopes now: menu, then list, then the panel itself.
            if viewModel.isListOpen {
                viewModel.closeList()
            } else {
                NotificationCenter.default.post(name: .panelDismissRequested, object: nil)
            }
            return true

        case .quit:
            handleMenu(.quit)
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
