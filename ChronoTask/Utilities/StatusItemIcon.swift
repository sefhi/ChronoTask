import AppKit

/// ChronoTask's mark rendered for the menu bar.
///
/// The geometry lives in `ChronoMark`, shared with the panel header and the peek —
/// this only rasterises it at status-item size and handles the appearance rules.
///
/// It is drawn rather than loaded from `Assets.xcassets` on purpose. Loading made the
/// single pixel that proves the app is running depend on how it was built:
/// `install.sh` falls back to plain `swiftc` when Xcode is not selected, `swiftc`
/// cannot compile an asset catalogue, and `NSImage(named:)` then returned nil. A
/// status item with no image and no title collapses to zero width, so the app ran and
/// still answered ⌥⌘T while showing nothing at all.
enum StatusItemIcon {

    /// Matches the ~18pt the menu bar gives a status item at standard height.
    static let size = NSSize(width: 18, height: 18)

    /// Idle: a template image, so AppKit inverts it for light and dark menu bars.
    static func idle() -> NSImage {
        let image = NSImage(size: size, flipped: false) { rect in
            draw(isRunning: false, in: rect, color: .black)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "ChronoTask"
        return image
    }

    /// Running: tinted with the accent, the unswept remainder left faint behind.
    ///
    /// `tint` must already be resolved against the target appearance; a dynamic
    /// `NSColor` would resolve against whatever appearance is current while drawing.
    static func running(tint: NSColor) -> NSImage {
        let image = NSImage(size: size, flipped: false) { rect in
            draw(isRunning: true, in: rect, color: tint)
            return true
        }
        // A template image would throw the tint away.
        image.isTemplate = false
        image.accessibilityDescription = "ChronoTask grabando"
        return image
    }

    private static func draw(isRunning: Bool, in rect: NSRect, color: NSColor) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        let scale = min(rect.width, rect.height) / ChronoMark.viewBox

        // `ChronoMark` is defined y-down like the SVG it came from; AppKit's image
        // context is y-up, so the whole thing is flipped once here.
        context.saveGState()
        context.translateBy(x: 0, y: rect.height)
        context.scaleBy(x: 1, y: -1)

        if isRunning {
            context.addPath(ChronoMark.ring(scale: scale))
            context.setFillColor(color.withAlphaComponent(ChronoMark.trackOpacity).cgColor)
            context.fillPath()

            context.setFillColor(color.cgColor)
            // Filled separately from the arc: merged, their opposing winding makes a
            // nonzero fill cut the cap back out.
            context.addPath(ChronoMark.sweep(scale: scale))
            context.fillPath()
            context.addPath(ChronoMark.sweepCap(scale: scale))
            context.fillPath()
        } else {
            context.addPath(ChronoMark.ring(scale: scale))
            context.setFillColor(color.cgColor)
            context.fillPath()
        }

        context.setFillColor(color.cgColor)
        context.addPath(ChronoMark.dial(scale: scale))
        context.fillPath()

        context.restoreGState()
    }
}
