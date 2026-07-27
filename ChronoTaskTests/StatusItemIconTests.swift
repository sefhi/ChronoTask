import AppKit
import XCTest
@testable import ChronoTask

/// Regression cover for the bug where the menu bar icon came from `Assets.xcassets`.
/// Built without Xcode there is no compiled asset catalogue, `NSImage(named:)`
/// returned nil, and the status item collapsed to zero width — the app ran but was
/// invisible. These tests fail if the mark ever goes back to depending on a bundle
/// resource, because the test bundle has no catalogue either.
final class StatusItemIconTests: XCTestCase {

    func testIdleMarkIsDrawnAtMenuBarSize() {
        let icon = StatusItemIcon.idle()
        XCTAssertEqual(icon.size, StatusItemIcon.size)
        XCTAssertGreaterThan(icon.size.width, 0)
    }

    /// Template images are the ones AppKit recolours for light and dark menu bars.
    /// The idle mark must be one; the tinted running mark must not, or the tint is
    /// thrown away.
    func testOnlyTheIdleMarkIsATemplate() {
        XCTAssertTrue(StatusItemIcon.idle().isTemplate)
        XCTAssertFalse(StatusItemIcon.running(tint: .red).isTemplate)
    }

    func testMarksCarryAnAccessibilityDescription() {
        XCTAssertNotNil(StatusItemIcon.idle().accessibilityDescription)
        XCTAssertNotNil(StatusItemIcon.running(tint: .red).accessibilityDescription)
    }

    /// The real failure mode was not a nil image but an image that draws nothing:
    /// both are invisible in the menu bar, and only this catches the second.
    func testIdleMarkActuallyPutsInkOnTheCanvas() {
        XCTAssertGreaterThan(coveragePercent(of: StatusItemIcon.idle()), 5)
    }

    func testRunningMarkActuallyPutsInkOnTheCanvas() {
        XCTAssertGreaterThan(coveragePercent(of: StatusItemIcon.running(tint: .red)), 5)
    }

    /// The running mark carries the accent; a template flag or a lost tint would
    /// show up here as a greyscale result.
    func testRunningMarkIsDrawnInTheGivenTint() {
        let tint = NSColor(srgbRed: 1, green: 0, blue: 0, alpha: 1)
        guard let rep = bitmap(of: StatusItemIcon.running(tint: tint)) else {
            return XCTFail("could not rasterise the running mark")
        }

        var sawRed = false
        for x in 0..<rep.pixelsWide where !sawRed {
            for y in 0..<rep.pixelsHigh {
                guard let colour = rep.colorAt(x: x, y: y), colour.alphaComponent > 0.5 else { continue }
                if colour.redComponent > 0.5 && colour.greenComponent < 0.3 {
                    sawRed = true
                    break
                }
            }
        }
        XCTAssertTrue(sawRed, "the running mark ignored its tint")
    }

    // MARK: - Helpers

    private func bitmap(of image: NSImage) -> NSBitmapImageRep? {
        guard let tiff = image.tiffRepresentation else { return nil }
        return NSBitmapImageRep(data: tiff)
    }

    /// Percentage of pixels with meaningful alpha.
    private func coveragePercent(of image: NSImage) -> Double {
        guard let rep = bitmap(of: image) else { return 0 }
        var inked = 0
        for x in 0..<rep.pixelsWide {
            for y in 0..<rep.pixelsHigh {
                if let colour = rep.colorAt(x: x, y: y), colour.alphaComponent > 0.1 {
                    inked += 1
                }
            }
        }
        return Double(inked) / Double(rep.pixelsWide * rep.pixelsHigh) * 100
    }
}
