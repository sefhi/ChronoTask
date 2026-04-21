import AppKit

final class MenuBarController {
    private var statusItem: NSStatusItem?
    private weak var appState: AppState?
    private weak var window: NSWindow?

    func install(appState: AppState, window: NSWindow?) {
        self.appState = appState
        self.window = window

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let image = NSImage(systemSymbolName: "timer", accessibilityDescription: "ChronoTask")
        image?.isTemplate = true
        item.button?.image = image

        let menu = NSMenu()

        let show = NSMenuItem(title: "Show Window", action: #selector(showWindow), keyEquivalent: "")
        show.target = self
        menu.addItem(show)

        menu.addItem(.separator())

        let refresh = NSMenuItem(title: "Refresh tasks", action: #selector(refresh), keyEquivalent: "r")
        refresh.target = self
        menu.addItem(refresh)

        let logout = NSMenuItem(title: "Settings / Logout", action: #selector(logoutAction), keyEquivalent: "")
        logout.target = self
        menu.addItem(logout)

        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "Quit ChronoTask",
                                action: #selector(NSApp.terminate(_:)),
                                keyEquivalent: "q"))

        item.menu = menu
        self.statusItem = item
    }

    @objc private func showWindow() {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    @objc private func refresh() {
        NotificationCenter.default.post(name: .refreshTasksRequested, object: nil)
    }

    @objc private func logoutAction() {
        Task { @MainActor in
            appState?.logout()
        }
    }
}
