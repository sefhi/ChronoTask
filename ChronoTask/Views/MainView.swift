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

    init(taskStore: TaskStore, timerManager: TimerManager) {
        _viewModel = StateObject(wrappedValue: MainViewModel(taskStore: taskStore,
                                                             timerManager: timerManager))
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

            if let focused = timerManager.focusedRun {
                runningBody(focused)
            } else {
                idleBody
            }

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

            taskList

            footer
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
            StatusPill(state: timerManager.isRunning
                       ? .recording(count: timerManager.runs.count)
                       : .ready)
            Spacer(minLength: 8)
            PanelMenuButton(isOpen: viewModel.isMenuOpen) {
                viewModel.toggleMenu()
            }
        }
    }

    // MARK: - Body

    /// Nothing running: the empty clock and the strip that opens the list.
    private var idleBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            TimerDisplay(elapsed: 0)
                .padding(.top, 6)

            SummaryLine(content: .today(displayedTotal, isStale: dailyTotal.isStale))
                .padding(.top, 1)

            TaskCaption(isExpanded: viewModel.isListOpen) {
                viewModel.toggleList()
            }
            .padding(.top, 12)
        }
    }

    /// The focused task large, everything else running beside it listed below.
    private func runningBody(_ focused: RunningTimer) -> some View {
        let count = timerManager.runs.count

        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                TaskIcon(task: focused.task, isLive: true)
                    // Rebuilt per task so the pulse starts afresh on the new one.
                    .id(focused.id)
                Text(focused.task.strippedName)
                    .font(Theme.focusNameFont)
                    .foregroundColor(Theme.ink)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Stops only this task. Always visible: "Detener N" below stops them
                // all, and without this there was no way to stop just the one in
                // focus.
                Text("⌫")
                    .font(Theme.hintFont)
                    .foregroundColor(Theme.inkQuaternary)
                    .accessibilityHidden(true)
                RowStopButton(size: Theme.focusStopSize) { stop(focused) }
                    .accessibilityLabel("Detener \(focused.task.strippedName)")
                    .accessibilityHint("Atajo: borrar")
            }
            .padding(.top, 8)

            TimerDisplay(elapsed: timerManager.elapsed(of: focused), compact: true)
                .padding(.top, 4)

            SummaryLine(content: count > 1
                        ? .parallel(total: timerManager.totalElapsed, count: count)
                        : .today(displayedTotal, isStale: dailyTotal.isStale))
                .padding(.top, 1)

            ParallelTasksSection(
                runs: timerManager.parallelRuns,
                elapsed: { timerManager.elapsed(of: $0) },
                isListOpen: viewModel.isListOpen,
                onFocus: { timerManager.focus(taskId: $0.id) },
                onStop: { stop($0) },
                onAdd: { viewModel.toggleList() }
            )
            .padding(.top, 14)
        }
    }

    // MARK: - Footer

    @ViewBuilder
    private var footer: some View {
        let count = timerManager.runs.count
        HStack(spacing: Theme.controlGap) {
            switch count {
            case 0:
                SecondaryActionButton(title: "Elige una tarea para empezar") {}
                    .disabled(true)
                DailyTotalChip(total: displayedTotal)
            case 1:
                PrimaryActionButton(title: "Detener", action: stopAll)
                DailyTotalChip(total: displayedTotal)
            default:
                SecondaryActionButton(title: "Solo esta", action: keepOnlyFocused)
                PrimaryActionButton(title: "Detener \(count)", hint: "␣", action: stopAll)
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
            goLabel: timerManager.isRunning ? "+ INICIAR" : "INICIAR",
            focusedIndex: viewModel.focusedIndex,
            emptyMessage: viewModel.emptyMessage,
            syncedLabel: SyncLabel.text(lastLoaded: taskStore.lastLoaded,
                                        now: clockTick,
                                        isSyncing: taskStore.phase == .loading),
            isSyncing: taskStore.phase == .loading,
            query: $viewModel.query,
            searchFocus: $searchFocused,
            onSelect: { viewModel.start($0) },
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

    private var displayedTotal: TimeInterval? {
        dailyTotal.displayTotal(runs: timerManager.runs, at: timerManager.clock)
    }

    // MARK: - Actions
    //
    // Each reports what actually happened instead of guessing after a fixed delay. A
    // failed upload says nothing here: `syncError` raises its own toast.

    private func stop(_ run: RunningTimer) {
        Task {
            let outcome = await timerManager.stop(taskId: run.id)
            if case .synced(let duration) = outcome {
                viewModel.showToast("Registrado \(Self.loggedFormatted(duration)) · \(run.task.strippedName)",
                                    type: .success)
            }
        }
    }

    private func stopAll() {
        let count = timerManager.runs.count
        Task {
            let outcome = await timerManager.stopAll()
            guard case .synced(let duration) = outcome else { return }
            let message = count > 1
                ? "\(count) tareas registradas · \(Self.loggedFormatted(duration))"
                : "Registrado \(Self.loggedFormatted(duration))"
            viewModel.showToast(message, type: .success)
        }
    }

    private func stopFocused() {
        guard let focused = timerManager.focusedRun else { return }
        stop(focused)
    }

    private func keepOnlyFocused() {
        guard let focused = timerManager.focusedRun else { return }
        Task {
            if case .synced = await timerManager.keepOnly(taskId: focused.id) {
                viewModel.showToast("Foco en una sola tarea", type: .success)
            }
        }
    }

    /// "Registrado 0m" would read as nothing having been saved, so anything under a
    /// minute is rounded up in the message — the entry itself keeps its seconds.
    private static func loggedFormatted(_ duration: TimeInterval) -> String {
        max(duration, 60).todayFormatted
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
            // Enter means "start this row" and never doubles as stop — with the list
            // open a dual meaning would be ambiguous.
            guard viewModel.isListOpen else { return false }
            viewModel.commitFocused()
            return true

        case .space:
            // SPACE is the footer's main button: stop what runs, or with nothing
            // running, go and pick something.
            if timerManager.isRunning {
                stopAll()
            } else {
                viewModel.openList()
            }
            return true

        case .delete:
            // ⌫ stops the task in focus and leaves the rest running — the one-task
            // counterpart to SPACE. With the list open it is the search field's.
            guard !viewModel.isListOpen, timerManager.isRunning else { return false }
            stopFocused()
            return true

        case .tab(let backwards):
            // ⇥ walks the focus through the running tasks, so any one of them can be
            // brought forward — and then stopped with ⌫ — without the pointer.
            guard !viewModel.isListOpen, timerManager.runs.count > 1 else { return false }
            timerManager.cycleFocus(backwards: backwards)
            return true

        case .quickPick(let index):
            // ⌘1…⌘9 start one of the first tasks outright, beside anything running.
            let tasks = viewModel.filteredTasks
            guard tasks.indices.contains(index) else { return true }
            viewModel.start(tasks[index])
            return true
        }
    }
}
