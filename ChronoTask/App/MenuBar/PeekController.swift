import AppKit
import SwiftUI

/// The hover peek: every running task and its time, without opening the panel.
@MainActor
final class PeekController {

    private let panel: GlassPanel
    /// A plain `FirstMouseHostingView` rather than a hosting *controller*: this panel
    /// is never key, and a hosting controller would take over the glass container.
    private let hosting: FirstMouseHostingView<PeekContainer>
    private let glassContainer: GlassPanelContentView
    private weak var statusButton: NSStatusBarButton?
    private var hideWork: DispatchWorkItem?

    /// The peek must never appear on top of the open panel.
    var isPanelOpen: () -> Bool = { false }

    private(set) var isVisible = false
    private var model = PeekModel()

    var window: NSWindow { panel }

    init(statusButton: NSStatusBarButton?) {
        self.statusButton = statusButton
        self.panel = GlassPanel(canBecomeKeyWindow: false)
        self.glassContainer = GlassPanelContentView(cornerRadius: Theme.radiusPeek,
                                                    material: .popover)

        let model = self.model
        hosting = FirstMouseHostingView(rootView: PeekContainer(model: model))
        glassContainer.setContent(hosting)

        // Added last so it sits on top and owns the tracking area. It is invisible to
        // hit testing, so it never gets in the way of the content underneath.
        let hover = PeekHoverView()
        hover.onEnter = { [weak self] in self?.cancelPendingHide() }
        hover.onExit = { [weak self] in self?.scheduleHide(after: 0.15) }
        glassContainer.setContent(hover)

        // Assigning `contentView` directly, not a content view controller — the latter
        // would replace this view and take the blur with it.
        panel.contentView = glassContainer
    }

    func render(rows: [PeekRow]) {
        let resized = rows.count != model.rows.count
        model.rows = rows
        // A task started or stopped while the peek is up changes its height; the
        // window was measured when it appeared, so measure it again.
        if resized && isVisible {
            panel.setFrame(frame(), display: true)
            panel.invalidateShadow()
        }
    }

    // MARK: - Hover state machine

    func statusItemHoverBegan() {
        cancelPendingHide()
        guard !isPanelOpen() else { return }
        show()
    }

    func statusItemHoverEnded() {
        // Grace period so the pointer can travel from the status item to the peek.
        scheduleHide(after: 0.25)
    }

    func forceHide() {
        cancelPendingHide()
        hideNow()
    }

    private func show() {
        guard !isVisible else { return }

        panel.setFrame(frame(), display: false)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        panel.invalidateShadow()
        isVisible = true

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.14
            panel.animator().alphaValue = 1
        }
    }

    private func frame() -> NSRect {
        hosting.layoutSubtreeIfNeeded()
        let size = hosting.fittingSize
        let peekSize = NSSize(width: max(size.width, Theme.peekWidth), height: max(size.height, 38))

        if let button = statusButton, let anchor = PanelAnchor.screenRect(of: button) {
            return PanelAnchor.frame(panelSize: peekSize,
                                     anchor: anchor.rect,
                                     visibleFrame: anchor.screen.visibleFrame,
                                     gap: 4)
        }
        return PanelAnchor.fallbackFrame(panelSize: peekSize,
                                         visibleFrame: NSScreen.main?.visibleFrame ?? .zero)
    }

    private func hideNow() {
        guard isVisible else { return }
        isVisible = false
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.1
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.panel.orderOut(nil)
        })
    }

    private func scheduleHide(after delay: TimeInterval) {
        cancelPendingHide()
        let work = DispatchWorkItem { [weak self] in self?.hideNow() }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func cancelPendingHide() {
        hideWork?.cancel()
        hideWork = nil
    }
}

/// Observable backing for the peek's SwiftUI content.
@MainActor
final class PeekModel: ObservableObject {
    @Published var rows: [PeekRow] = []
}

struct PeekContainer: View {
    @ObservedObject var model: PeekModel

    var body: some View {
        PeekView(rows: model.rows)
    }
}

/// Keeps the peek alive while the pointer is over it.
final class PeekHoverView: NSView {
    var onEnter: (() -> Void)?
    var onExit: (() -> Void)?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    /// Invisible to clicks. This view sits on top of the peek's content purely to own
    /// a tracking area.
    /// Tracking areas are processed independently of hit testing, so hover still works.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }

    override func mouseEntered(with event: NSEvent) { onEnter?() }
    override func mouseExited(with event: NSEvent) { onExit?() }
}
