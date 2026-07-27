import AppKit
import SwiftUI

/// Borderless translucent panel used for both the main panel and the peek.
///
/// `NSPanel` rather than `NSPopover`: the popover forces an arrow that cannot be
/// removed without private API, fixes its own corner radius, draws its own material
/// (which fights the 22pt clip), and does not reliably give first responder to text
/// fields from a non-activating app.
final class GlassPanel: NSPanel {

    private let wantsKey: Bool

    /// The blur itself is built by whatever `contentViewController` is installed
    /// (see `ContentSizingHostingController`), because assigning a content view
    /// controller replaces `contentView` outright — anything set here would be
    /// thrown away without a word.
    init(canBecomeKeyWindow: Bool) {
        self.wantsKey = canBecomeKeyWindow

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: Theme.panelWidth, height: Theme.minPanelHeight),
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        // `true` would only make the panel key when a control demands input, but local
        // NSEvent monitors need a key window to see keyDown at all — no ESC, no SPACE.
        becomesKeyOnlyIfNeeded = false
        // Deactivation is unreliable in an LSUIElement app that never activates;
        // dismissal is handled explicitly by the controller instead.
        hidesOnDeactivate = false
        // Above every app, but below `.popUpMenu` (101) where AppKit draws NSMenu —
        // otherwise our own context menu would render behind the panel.
        level = .statusBar
        // Code-created windows default to `true`, which deallocates on close and
        // crashes the next `orderFront`. We only ever `orderOut`.
        isReleasedWhenClosed = false
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        isMovableByWindowBackground = false
        animationBehavior = .none
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        // Must stay nil: pinning an appearance would freeze every dynamic colour.
        appearance = nil
    }

    override var canBecomeKey: Bool { wantsKey }
    override var canBecomeMain: Bool { false }
}

/// Hosts the blur and clips everything to the panel's rounded rectangle.
final class GlassPanelContentView: NSView {
    private let effectView = NSVisualEffectView()
    private let cornerRadius: CGFloat

    init(cornerRadius: CGFloat, material: NSVisualEffectView.Material) {
        self.cornerRadius = cornerRadius
        super.init(frame: .zero)

        wantsLayer = true
        layer?.cornerRadius = cornerRadius
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true
        layer?.borderWidth = 1

        effectView.material = material
        // Only `.behindWindow` samples the desktop; `.withinWindow` would blur our
        // own (transparent) background and show nothing.
        effectView.blendingMode = .behindWindow
        // The default `.followsWindowActiveState` flattens the material to grey in an
        // app that deliberately never activates.
        effectView.state = .active
        effectView.isEmphasized = false
        effectView.autoresizingMask = [.width, .height]
        effectView.frame = bounds
        // Both the mask and the layer clip are needed: the mask shapes the blur the
        // window server draws, the layer clip shapes the SwiftUI content on top.
        effectView.maskImage = Self.roundedMask(radius: cornerRadius)
        addSubview(effectView)

        updateBorderColor()
    }

    required init?(coder: NSCoder) { nil }

    /// The peek's panel is never key, so without this its first click would be spent
    /// activating the window instead of pressing the button.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    /// Installs content above the blur, pinned to the edges.
    func setContent(_ content: NSView) {
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: leadingAnchor),
            content.trailingAnchor.constraint(equalTo: trailingAnchor),
            content.topAnchor.constraint(equalTo: topAnchor),
            content.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateBorderColor()
    }

    /// `layer.borderColor` is a `CGColor` and does not follow the appearance on its
    /// own — without this the light-mode border stays white in dark mode.
    private func updateBorderColor() {
        let resolved = Theme.NS.panelBorder.resolved(for: effectiveAppearance)
        layer?.borderColor = resolved.cgColor
    }

    /// Nine-part stretchable mask: a rounded rect with cap insets so it scales to any
    /// panel size without distorting the corners.
    static func roundedMask(radius: CGFloat) -> NSImage {
        let edge = 2 * radius + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }
}

extension NSColor {
    /// Resolves a dynamic colour against a specific appearance.
    func resolved(for appearance: NSAppearance) -> NSColor {
        var result = self
        appearance.performAsCurrentDrawingAppearance {
            result = self.usingColorSpace(.sRGB) ?? self
        }
        return result
    }
}

/// Without `acceptsFirstMouse` the first click on a non-key panel is spent giving it
/// focus, so the user has to click twice — especially painful on the peek's button.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
