import AppKit
import SwiftUI

/// Shows, positions, sizes and dismisses the main panel.
@MainActor
final class MainPanelController<Content: View> {

    private let panel: GlassPanel
    private let hosting: ContentSizingHostingController<Content>
    private weak var statusButton: NSStatusBarButton?

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var appActivationObserver: NSObjectProtocol?
    private var screenChangeObserver: NSObjectProtocol?
    private var lastToggleAt: TimeInterval = 0

    /// Windows that must not count as "outside" for dismissal purposes.
    var isAuxiliaryWindow: ((NSWindow) -> Bool)?

    /// Screenshot/debug aid: keeps the panel on screen when focus moves elsewhere.
    /// Enabled by launching with CHRONOTASK_SHOW_PANEL=1.
    var keepsOpenWhenInactive = false
    var onOpen: (() -> Void)?
    var onClose: (() -> Void)?

    private(set) var isVisible = false

    init(rootView: Content, statusButton: NSStatusBarButton?) {
        self.statusButton = statusButton
        self.panel = GlassPanel(canBecomeKeyWindow: true)
        self.hosting = ContentSizingHostingController(rootView: rootView,
                                                     cornerRadius: Theme.radiusPanel)

        panel.contentViewController = hosting
        hosting.onPreferredSizeChange = { [weak self] size in
            self?.setContentHeight(size.height)
        }

        screenChangeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in self.repositionIfVisible() }
        }
    }

    deinit {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let appActivationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(appActivationObserver)
        }
        if let screenChangeObserver {
            NotificationCenter.default.removeObserver(screenChangeObserver)
        }
    }

    // MARK: - Presentation

    /// Guarded against the classic double toggle: clicking the status item both
    /// triggers "clicked outside" and the button's own action.
    func toggle() {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastToggleAt > 0.2 else { return }
        lastToggleAt = now
        isVisible ? hide() : show()
    }

    func show() {
        guard !isVisible else { return }

        hosting.layoutNow()
        let target = targetFrame()

        // Start slightly low and transparent, then settle — same 0.18s move the
        // prototype uses.
        panel.setFrame(target.offsetBy(dx: 0, dy: Theme.panelOffset), display: false)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        // The panel has to become genuinely key or neither the search field nor the
        // keyboard shortcuts receive anything: key events go to the *active* app, and
        // an agent app is never active until it says so. `.nonactivatingPanel` keeps
        // this from stealing focus any longer than the panel is open.
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.invalidateShadow()
        isVisible = true

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
            panel.animator().setFrame(target, display: true)
        }

        installDismissMonitors()
        onOpen?()
        NotificationCenter.default.post(name: .panelDidPresent, object: nil)
    }

    func hide() {
        guard isVisible else { return }
        isVisible = false
        removeDismissMonitors()

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.panel.orderOut(nil)
        })

        onClose?()
    }

    // MARK: - Geometry

    private func targetFrame() -> NSRect {
        let height = min(hosting.measuredHeight ?? panel.frame.height, maxAvailableHeight())
        let size = NSSize(width: Theme.panelWidth, height: max(height, Theme.minPanelHeight))

        guard let button = statusButton,
              let anchor = PanelAnchor.screenRect(of: button) else {
            let visible = NSScreen.main?.visibleFrame ?? .zero
            return PanelAnchor.fallbackFrame(panelSize: size, visibleFrame: visible)
        }
        return PanelAnchor.frame(panelSize: size,
                                 anchor: anchor.rect,
                                 visibleFrame: anchor.screen.visibleFrame)
    }

    private func maxAvailableHeight() -> CGFloat {
        guard let button = statusButton,
              let anchor = PanelAnchor.screenRect(of: button) else {
            return (NSScreen.main?.visibleFrame.height ?? 800) - 40
        }
        return PanelAnchor.maxHeight(anchor: anchor.rect, visibleFrame: anchor.screen.visibleFrame)
    }

    /// Applies a new content height, keeping the top edge pinned under the status item.
    ///
    /// Never animated here: SwiftUI is already animating the list's height, and two
    /// overlapping curves produce visible stutter.
    private func setContentHeight(_ raw: CGFloat) {
        guard isVisible else { return }
        let clamped = min(max(raw.rounded(), Theme.minPanelHeight), maxAvailableHeight())
        // Tolerance breaks the feedback loop between content height and window height.
        guard abs(clamped - panel.frame.height) > 0.5 else { return }

        let current = panel.frame
        panel.setFrame(NSRect(x: current.minX,
                              y: current.maxY - clamped,
                              width: current.width,
                              height: clamped),
                       display: true)
        // Otherwise the shadow keeps the silhouette of the previous size.
        panel.invalidateShadow()
    }

    private func repositionIfVisible() {
        guard isVisible else { return }
        panel.setFrame(targetFrame(), display: true)
        panel.invalidateShadow()
    }

    // MARK: - Dismissal

    private func installDismissMonitors() {
        guard !keepsOpenWhenInactive else { return }
        // Global monitors do not see our own process's clicks…
        globalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            Task { @MainActor in self?.hide() }
        }

        // …so a local one is needed for the status item and our own windows.
        localMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            guard let self else { return event }
            guard let clicked = event.window else { return event }
            if clicked === self.panel { return event }
            if self.isAuxiliaryWindow?(clicked) == true { return event }
            // Let the button's own action own the toggle, or the panel would close
            // and immediately reopen.
            if clicked === self.statusButton?.window { return event }
            self.hide()
            // Never return nil: the click still belongs to whatever it landed on.
            return event
        }

        // Covers ⌘-Tab. Not `windowDidResignKey`, which would also fire whenever a
        // SwiftUI `Menu` inside the panel takes key.
        appActivationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
            Task { @MainActor in self.hide() }
        }
    }

    private func removeDismissMonitors() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let appActivationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(appActivationObserver)
        }
        globalMonitor = nil
        localMonitor = nil
        appActivationObserver = nil
    }
}
