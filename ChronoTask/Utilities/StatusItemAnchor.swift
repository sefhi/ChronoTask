import AppKit

/// Where the panel and the peek sit relative to the status item.
///
/// Pure geometry, kept apart from the controllers so the edge cases (screen clamping,
/// a second display, a very tall panel) can be tested without a window server.
enum PanelAnchor {

    /// The status item's frame in screen coordinates, plus the screen it lives on.
    ///
    /// Returns `nil` when the item is not currently visible — hidden behind a menu bar
    /// manager, or squeezed out by the notch.
    static func screenRect(of button: NSStatusBarButton) -> (rect: NSRect, screen: NSScreen)? {
        guard let window = button.window else { return nil }
        let inWindow = button.convert(button.bounds, to: nil)
        let onScreen = window.convertToScreen(inWindow)

        // The menu bar can live on a secondary display, and `NSScreen.main` means
        // "where the key window is", which is the wrong question here.
        let screen = window.screen
            ?? NSScreen.screens.first { $0.frame.intersects(onScreen) }
            ?? NSScreen.main
        guard let screen else { return nil }
        return (onScreen, screen)
    }

    /// Panel frame: hung below the item and aligned to its right edge, clamped to the
    /// visible area.
    ///
    /// Right alignment is deliberate — macOS packs status items against the right, so
    /// when ours widens to show the clock it grows leftwards and `maxX` stays put.
    /// The panel therefore does not shuffle every time the time changes.
    static func frame(panelSize: NSSize,
                      anchor: NSRect,
                      visibleFrame: NSRect,
                      gap: CGFloat = Theme.anchorGap,
                      margin: CGFloat = Theme.screenEdgeMargin) -> NSRect {
        var x = anchor.maxX - panelSize.width
        x = min(x, visibleFrame.maxX - panelSize.width - margin)
        x = max(x, visibleFrame.minX + margin)

        var y = anchor.minY - gap - panelSize.height
        y = max(y, visibleFrame.minY + margin)

        return NSRect(x: x, y: y, width: panelSize.width, height: panelSize.height)
    }

    /// Tallest the panel may be on this screen before it runs off the bottom.
    ///
    /// Measured from the item's own lower edge rather than `visibleFrame.maxY`, which
    /// is what makes this correct on notched displays.
    static func maxHeight(anchor: NSRect,
                          visibleFrame: NSRect,
                          gap: CGFloat = Theme.anchorGap,
                          margin: CGFloat = Theme.screenEdgeMargin) -> CGFloat {
        max(Theme.minPanelHeight, anchor.minY - gap - visibleFrame.minY - margin)
    }

    /// Fallback for when the status item cannot be located: top-right corner, which is
    /// where the old floating window used to sit.
    static func fallbackFrame(panelSize: NSSize, visibleFrame: NSRect) -> NSRect {
        NSRect(x: visibleFrame.maxX - panelSize.width - 20,
               y: visibleFrame.maxY - panelSize.height - 20,
               width: panelSize.width,
               height: panelSize.height)
    }
}
