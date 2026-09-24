import AppKit
import Combine
import SwiftUI

/// Wires the status item, the panel and the peek to the app's state.
@MainActor
final class MenuBarCoordinator {

    private let environment: AppEnvironment
    private let statusItem = StatusItemController()
    private var panelController: MainPanelController<AnyView>?
    private var peekController: PeekController?
    private var cancellables = Set<AnyCancellable>()
    private var observers: [NSObjectProtocol] = []
    private var appearanceObservation: NSKeyValueObservation?
    private let hotKey = GlobalHotKey()

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    func install() {
        statusItem.install()
        statusItem.menuBuilder = { [weak self] in self?.makeMenu() ?? NSMenu() }

        let panel = MainPanelController(rootView: makeRootView(), statusButton: statusItem.button)
        let peek = PeekController(statusButton: statusItem.button)
        panelController = panel
        peekController = peek

        // Clicks inside the peek must not dismiss the panel.
        panel.isAuxiliaryWindow = { [weak peek] window in window === peek?.window }
        panel.onOpen = { [weak self] in
            self?.statusItem.setHighlighted(true)
            self?.peekController?.forceHide()
            self?.environment.panelDidOpen()
        }
        panel.onClose = { [weak self] in
            self?.statusItem.setHighlighted(false)
            self?.environment.panelDidClose()
        }

        peek.isPanelOpen = { [weak panel] in panel?.isVisible ?? false }

        statusItem.onLeftClick = { [weak panel] in panel?.toggle() }
        statusItem.onWillShowMenu = { [weak self] in
            self?.panelController?.hide()
            self?.peekController?.forceHide()
        }
        statusItem.onHoverEnter = { [weak peek] in peek?.statusItemHoverBegan() }
        statusItem.onHoverExit = { [weak peek] in peek?.statusItemHoverEnded() }

        observeTimer()
        observeNotifications()

        // Opening the panel is the one step that otherwise always needs the mouse.
        hotKey.register(.togglePanel) { [weak panel] in panel?.toggle() }
    }

    private func makeRootView() -> AnyView {
        AnyView(
            ContentRouter()
                .environmentObject(environment)
                .environmentObject(environment.appState)
                .environmentObject(environment.timerManager)
                .environmentObject(environment.taskStore)
                .environmentObject(environment.dailyTotal)
        )
    }

    // MARK: - Observation

    /// What the menu bar and the peek actually need to draw. Whole seconds only —
    /// sub-second churn would redraw for nothing.
    private struct MenuBarSnapshot: Equatable {
        let state: TimerState
        /// The focused run's elapsed seconds.
        let seconds: Int
        let parallelCount: Int
        let rows: [PeekRow]

        init(state: TimerState, runs: [RunningTimer], focusedTaskId: String?, clock: Date) {
            self.state = state
            let focused = runs.first { $0.id == focusedTaskId } ?? runs.first
            seconds = Int(focused?.elapsed(at: clock) ?? 0)
            parallelCount = max(0, runs.count - 1)
            rows = runs.map { PeekRow(task: $0.task, elapsed: TimeInterval(Int($0.elapsed(at: clock)))) }
        }
    }

    private func observeTimer() {
        let timer = environment.timerManager

        // Built from the published values themselves: `@Published` emits on
        // `willSet`, so reading the manager's properties here would lag a beat.
        timer.$state
            .combineLatest(timer.$runs, timer.$focusedTaskId, timer.$clock)
            .map { MenuBarSnapshot(state: $0, runs: $1, focusedTaskId: $2, clock: $3) }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] snapshot in
                guard let self else { return }
                self.statusItem.render(state: snapshot.state,
                                       elapsed: TimeInterval(snapshot.seconds),
                                       parallelCount: snapshot.parallelCount)
                self.peekController?.render(rows: snapshot.rows)
            }
            .store(in: &cancellables)

        // Tinted symbol variants are appearance-specific and must be rebuilt.
        appearanceObservation = NSApp.observe(\.effectiveAppearance) { [weak self] _, _ in
            Task { @MainActor in
                guard let self else { return }
                let timer = self.environment.timerManager
                self.statusItem.appearanceDidChange()
                self.statusItem.render(state: timer.state,
                                       elapsed: timer.elapsed,
                                       parallelCount: max(0, timer.runs.count - 1))
            }
        }
    }

    private func observeNotifications() {
        let token = NotificationCenter.default.addObserver(
            forName: .panelDismissRequested,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in self.panelController?.hide() }
        }
        observers.append(token)
    }

    // MARK: - Actions

    /// Stops everything that runs, or restarts the last task started.
    private func toggleTimer() {
        let timer = environment.timerManager
        if timer.isRunning {
            Task { await timer.stopAll() }
        } else if let task = environment.taskStore.selectedTask {
            timer.start(task: task)
        }
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        let timer = environment.timerManager

        let open = NSMenuItem(title: "Abrir ChronoTask", action: #selector(menuOpenPanel), keyEquivalent: "t")
        open.keyEquivalentModifierMask = [.command, .option]
        open.target = self
        menu.addItem(open)

        let toggle = NSMenuItem(
            title: toggleTitle(runCount: timer.runs.count),
            action: #selector(menuToggleTimer),
            keyEquivalent: ""
        )
        toggle.target = self
        toggle.isEnabled = timer.isRunning || environment.taskStore.selectedTask != nil

        // With several running, stopping just the one in focus sits above stopping
        // them all — the same pair the panel offers with ⌫ and SPACE.
        if timer.runs.count > 1, let focused = timer.focusedRun {
            let stopOne = NSMenuItem(title: "Detener «\(focused.task.strippedName)»",
                                     action: #selector(menuStopFocused),
                                     keyEquivalent: "")
            stopOne.target = self
            menu.addItem(stopOne)
        }
        menu.addItem(toggle)

        menu.addItem(.separator())

        let refresh = NSMenuItem(title: "Actualizar tareas", action: #selector(menuRefresh), keyEquivalent: "r")
        refresh.target = self
        menu.addItem(refresh)

        let logout = NSMenuItem(title: "Cambiar clave de API", action: #selector(menuLogout), keyEquivalent: "")
        logout.target = self
        menu.addItem(logout)

        menu.addItem(.separator())

        // Deliberately not `NSApplication.terminate(_:)`: that would drop the running
        // stretch on the floor for `restoreSession` to ask about next launch. Going
        // through the environment uploads it first.
        let quit = NSMenuItem(title: "Salir de ChronoTask", action: #selector(menuQuit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        return menu
    }

    private func toggleTitle(runCount: Int) -> String {
        switch runCount {
        case 0:
            if let task = environment.taskStore.selectedTask {
                return "Iniciar «\(task.strippedName)»"
            }
            return "Iniciar cronómetro"
        case 1:
            return "Detener cronómetro"
        default:
            return "Detener \(runCount) cronómetros"
        }
    }

    /// Opens the panel programmatically (menu item, debug launch).
    func presentPanel(keepOpen: Bool = false) {
        if keepOpen { panelController?.keepsOpenWhenInactive = true }
        panelController?.show()
    }

    /// Opens the task list too, for screenshots of the picker.
    func presentTaskList() {
        presentPanel(keepOpen: true)
        NotificationCenter.default.post(name: .openTaskListRequested, object: nil)
    }

    @objc private func menuOpenPanel() { presentPanel() }

    @objc private func menuToggleTimer() { toggleTimer() }

    @objc private func menuStopFocused() {
        let timer = environment.timerManager
        guard let focused = timer.focusedRun else { return }
        Task { await timer.stop(taskId: focused.id) }
    }

    @objc private func menuRefresh() { environment.requestRefresh() }

    @objc private func menuLogout() { environment.appState.logout() }

    @objc private func menuQuit() { environment.quit() }
}
