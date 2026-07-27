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
        peek.onToggle = { [weak self] in self?.toggleTimer() }

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

    /// What the menu bar actually needs to draw. Whole seconds only — sub-second
    /// churn would redraw for nothing.
    private struct MenuBarSnapshot: Equatable {
        let state: TimerState
        let seconds: Int
        let hasTask: Bool
    }

    private func observeTimer() {
        let timer = environment.timerManager
        let taskPresence = timer.$currentTask
            .combineLatest(environment.taskStore.$selectedTask)
            .map { current, selected in current != nil || selected != nil }

        let snapshots = timer.$state
            .combineLatest(timer.$elapsed, taskPresence)
            .map { state, elapsed, hasTask in
                MenuBarSnapshot(state: state, seconds: Int(elapsed), hasTask: hasTask)
            }
            .removeDuplicates()

        snapshots
            .receive(on: RunLoop.main)
            .sink { [weak self] snapshot in
                guard let self else { return }
                let elapsed = TimeInterval(snapshot.seconds)
                self.statusItem.render(state: snapshot.state, elapsed: elapsed)
                self.peekController?.render(state: snapshot.state,
                                            elapsed: elapsed,
                                            hasTask: snapshot.hasTask)
            }
            .store(in: &cancellables)

        // Tinted symbol variants are appearance-specific and must be rebuilt.
        appearanceObservation = NSApp.observe(\.effectiveAppearance) { [weak self] _, _ in
            Task { @MainActor in
                self?.statusItem.appearanceDidChange()
                self?.statusItem.render(state: self?.environment.timerManager.state ?? .idle,
                                        elapsed: self?.environment.timerManager.elapsed ?? 0)
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

    private func toggleTimer() {
        let timer = environment.timerManager
        if timer.isRunning {
            Task { await timer.stopAndSync() }
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
            title: timer.isRunning ? "Detener cronómetro" : "Iniciar cronómetro",
            action: #selector(menuToggleTimer),
            keyEquivalent: ""
        )
        toggle.target = self
        toggle.isEnabled = timer.isRunning || environment.taskStore.selectedTask != nil
        menu.addItem(toggle)

        menu.addItem(.separator())

        let refresh = NSMenuItem(title: "Actualizar tareas", action: #selector(menuRefresh), keyEquivalent: "r")
        refresh.target = self
        menu.addItem(refresh)

        let logout = NSMenuItem(title: "Cambiar clave de API", action: #selector(menuLogout), keyEquivalent: "")
        logout.target = self
        menu.addItem(logout)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Salir de ChronoTask",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
        return menu
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

    @objc private func menuRefresh() { environment.requestRefresh() }

    @objc private func menuLogout() { environment.appState.logout() }
}
