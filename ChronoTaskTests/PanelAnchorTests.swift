import AppKit
import XCTest
@testable import ChronoTask

/// Geometry only — no window server involved, which is the point of keeping
/// `PanelAnchor` separate from the controllers.
final class PanelAnchorTests: XCTestCase {

    /// A 1440×900 screen with a 25pt menu bar.
    private let screen = NSRect(x: 0, y: 0, width: 1440, height: 875)
    private let panelSize = NSSize(width: 300, height: 400)

    /// A status item near the right edge, just under the menu bar.
    private func anchor(maxX: CGFloat) -> NSRect {
        NSRect(x: maxX - 60, y: 875, width: 60, height: 25)
    }

    func testPanelHangsBelowAndIsRightAligned() {
        let frame = PanelAnchor.frame(panelSize: panelSize,
                                      anchor: anchor(maxX: 1400),
                                      visibleFrame: screen)

        XCTAssertEqual(frame.maxX, 1400, accuracy: 0.001, "right edges line up")
        XCTAssertEqual(frame.maxY, 875 - Theme.anchorGap, accuracy: 0.001, "hangs below the item")
        XCTAssertEqual(frame.width, 300)
    }

    func testPanelIsClampedAtTheRightEdge() {
        // An item flush against the screen edge would push the panel off-screen.
        let frame = PanelAnchor.frame(panelSize: panelSize,
                                      anchor: anchor(maxX: 1440),
                                      visibleFrame: screen)

        XCTAssertLessThanOrEqual(frame.maxX, screen.maxX - Theme.screenEdgeMargin)
    }

    func testPanelIsClampedAtTheLeftEdge() {
        // A status item dragged far left (or a very wide panel).
        let frame = PanelAnchor.frame(panelSize: panelSize,
                                      anchor: NSRect(x: 0, y: 875, width: 40, height: 25),
                                      visibleFrame: screen)

        XCTAssertGreaterThanOrEqual(frame.minX, screen.minX + Theme.screenEdgeMargin)
    }

    func testTallPanelIsKeptOnScreen() {
        let tall = NSSize(width: 300, height: 2000)
        let frame = PanelAnchor.frame(panelSize: tall,
                                      anchor: anchor(maxX: 1400),
                                      visibleFrame: screen)

        XCTAssertGreaterThanOrEqual(frame.minY, screen.minY + Theme.screenEdgeMargin)
    }

    func testPositioningIsRelativeToTheGivenScreen() {
        // Menu bar on a secondary display to the right of the main one.
        let secondary = NSRect(x: 1440, y: 0, width: 1920, height: 1055)
        let frame = PanelAnchor.frame(panelSize: panelSize,
                                      anchor: NSRect(x: 3200, y: 1055, width: 60, height: 25),
                                      visibleFrame: secondary)

        XCTAssertGreaterThan(frame.minX, secondary.minX)
        XCTAssertLessThanOrEqual(frame.maxX, secondary.maxX - Theme.screenEdgeMargin)
    }

    // MARK: - Available height

    /// Measured from the item's lower edge rather than `visibleFrame.maxY`, which is
    /// what makes this right on notched displays.
    func testMaxHeightIsMeasuredFromTheItem() {
        let height = PanelAnchor.maxHeight(anchor: anchor(maxX: 1400), visibleFrame: screen)
        XCTAssertEqual(height, 875 - Theme.anchorGap - Theme.screenEdgeMargin, accuracy: 0.001)
    }

    func testMaxHeightNeverGoesBelowTheMinimum() {
        // A very short screen, or an item sitting unusually low.
        let squashed = NSRect(x: 0, y: 0, width: 800, height: 100)
        let height = PanelAnchor.maxHeight(anchor: NSRect(x: 700, y: 90, width: 60, height: 25),
                                           visibleFrame: squashed)

        XCTAssertGreaterThanOrEqual(height, Theme.minPanelHeight)
    }

    // MARK: - Fallback

    /// Used when the status item cannot be located — hidden by a menu bar manager, or
    /// pushed out by the notch.
    func testFallbackSitsInTheTopRightCorner() {
        let frame = PanelAnchor.fallbackFrame(panelSize: panelSize, visibleFrame: screen)

        XCTAssertEqual(frame.maxX, screen.maxX - 20, accuracy: 0.001)
        XCTAssertEqual(frame.maxY, screen.maxY - 20, accuracy: 0.001)
    }
}
