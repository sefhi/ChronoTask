import AppKit

/// Owns the status item: the icon, the running clock, and the click handling that
/// tells a left click (open the panel) from a right click (context menu).
@MainActor
final class StatusItemController: NSObject {

    // Strong: releasing the status item makes it vanish from the menu bar.
    private var statusItem: NSStatusItem!
    private let hoverProxy = HoverProxy()
    private var imageCache: [String: NSImage] = [:]
    private var lastTitleLength = -1

    var onLeftClick: (() -> Void)?
    var onWillShowMenu: (() -> Void)?
    var onHoverEnter: (() -> Void)?
    var onHoverExit: (() -> Void)?
    var menuBuilder: (() -> NSMenu)?

    var button: NSStatusBarButton? { statusItem?.button }

    func install() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.autosaveName = "ChronoTaskStatusItem"
        // Must stay nil. With a menu attached AppKit consumes the click itself and
        // the button's action is never invoked — so there would be no left/right
        // distinction at all.
        statusItem.menu = nil

        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(handleClick)
        // `mouseUp` rather than `mouseDown` keeps ⌘-drag reordering working.
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.imagePosition = .imageOnly
        button.setAccessibilityLabel("ChronoTask")

        installTrackingArea(on: button)
        render(state: .idle, elapsed: 0)
    }

    // MARK: - Clicks

    @objc private func handleClick() {
        guard let event = NSApp.currentEvent else { return }
        let isRight = event.type == .rightMouseUp
            || (event.type == .leftMouseUp && event.modifierFlags.contains(.control))
        isRight ? showContextMenu() : onLeftClick?()
    }

    private func showContextMenu() {
        onWillShowMenu?()
        guard let menu = menuBuilder?() else { return }
        statusItem.menu = menu
        // Blocks while the menu tracks, and gives the native highlight for free —
        // `NSMenu.popUp` does neither.
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    /// Keeps the item highlighted while the panel is open.
    func setHighlighted(_ highlighted: Bool) {
        statusItem?.button?.highlight(highlighted)
    }

    // MARK: - Rendering

    func render(state: TimerState, elapsed: TimeInterval) {
        guard let button = statusItem?.button else { return }

        button.image = image(for: state)

        switch state {
        case .idle:
            button.imagePosition = .imageOnly
            button.attributedTitle = NSAttributedString(string: "")
            statusItem.length = NSStatusItem.variableLength
            lastTitleLength = -1
        case .running, .syncing:
            let text = Self.menuBarTime(elapsed)
            button.imagePosition = .imageLeading
            button.attributedTitle = Self.attributedTime(text)
            applyStableLength(for: text, image: button.image)
        }
    }

    /// `H:MM:SS`, without the leading zero on hours.
    static func menuBarTime(_ elapsed: TimeInterval) -> String {
        let total = max(0, Int(elapsed))
        return String(format: "%d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }

    private static func attributedTime(_ text: String) -> NSAttributedString {
        NSAttributedString(string: text, attributes: [
            // Monospaced digits so the width does not twitch every second, and metrics
            // that match the rest of the menu bar.
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium),
            // Deliberately not the accent: terracotta text lacks contrast on a dark
            // menu bar. Only the icon is tinted.
            .foregroundColor: NSColor.labelColor,
            .kern: -0.2
        ])
    }

    /// Monospaced digits fix per-digit jitter but not the jump from `9:59:59` to
    /// `10:00:00`. Widening only when the digit count changes confines that to once
    /// an hour — and since the panel is anchored to `maxX`, nothing visibly moves.
    private func applyStableLength(for text: String, image: NSImage?) {
        guard text.count != lastTitleLength else { return }
        lastTitleLength = text.count
        let template = String(repeating: "0", count: text.count)
        let textWidth = Self.attributedTime(template).size().width
        let imageWidth = image?.size.width ?? 0
        statusItem.length = ceil(imageWidth + 5 + textWidth + 12)
    }

    private func image(for state: TimerState) -> NSImage? {
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        let key = "\(state)-\(isDark)"
        if let cached = imageCache[key] { return cached }

        var image: NSImage?

        switch state {
        case .idle:
            // The app's own mark, drawn for 18pt: a heavier ring than the app icon's,
            // because at menu bar size a hairline dial disappears.
            image = NSImage(named: "MenuBarStopwatch")
            image?.accessibilityDescription = "ChronoTask"
            // Template images invert correctly on light and dark menu bars.
            image?.isTemplate = true
        case .syncing:
            image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath",
                            accessibilityDescription: "ChronoTask sincronizando")?
                .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 13, weight: .medium))
            image?.isTemplate = true
        case .running:
            // The running mark dims the unswept part of the dial, so the accent reads
            // as progress rather than as a flat recolour.
            var accent = Theme.NS.accent
            NSApp.effectiveAppearance.performAsCurrentDrawingAppearance {
                accent = Theme.NS.accent.usingColorSpace(.sRGB) ?? accent
            }
            image = NSImage(named: "MenuBarStopwatchRunning")?.tinted(with: accent)
            image?.accessibilityDescription = "ChronoTask grabando"
        }

        imageCache[key] = image
        return image
    }

    /// Appearance changes invalidate the tinted variants.
    func appearanceDidChange() {
        imageCache.removeAll()
    }

    // MARK: - Hover

    private func installTrackingArea(on button: NSStatusBarButton) {
        hoverProxy.owner = self
        let area = NSTrackingArea(
            rect: .zero,
            // `.activeAlways` is mandatory: this app is never the active one.
            // `.inVisibleRect` keeps the area correct as the button widens to fit the
            // clock, instead of having to rebuild it on every render.
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: hoverProxy,
            userInfo: nil
        )
        button.addTrackingArea(area)
    }

    /// Tracking-area callbacks are dispatched straight to the owner, which therefore
    /// does not need to be in the responder chain.
    private final class HoverProxy: NSResponder {
        weak var owner: StatusItemController?

        override func mouseEntered(with event: NSEvent) {
            Task { @MainActor in self.owner?.onHoverEnter?() }
        }

        override func mouseExited(with event: NSEvent) {
            Task { @MainActor in self.owner?.onHoverExit?() }
        }
    }
}
