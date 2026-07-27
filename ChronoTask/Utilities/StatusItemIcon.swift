import AppKit

/// ChronoTask's mark for the menu bar, drawn in code.
///
/// It used to be loaded with `NSImage(named:)` from `Assets.xcassets`. That made the
/// single most important pixel in the app — the one that proves it is running —
/// depend on how it was built: `install.sh` falls back to plain `swiftc` when Xcode
/// is not selected, and `swiftc` cannot compile an asset catalogue. The bundle then
/// shipped without one, `NSImage(named:)` returned nil, and a status item with no
/// image and no title collapses to zero width. The app was running and still opened
/// with ⌥⌘T, but the menu bar showed nothing at all.
///
/// Drawing removes that dependency: the mark is now identical on every build path.
enum StatusItemIcon {

    /// Matches the ~18pt the menu bar gives a status item at standard height.
    static let size = NSSize(width: 18, height: 18)

    /// Idle: a template image, so AppKit inverts it for light and dark menu bars.
    static func idle() -> NSImage {
        let image = NSImage(size: size, flipped: false) { _ in
            NSColor.black.setStroke()
            NSColor.black.setFill()
            drawMark(sweep: nil)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "ChronoTask"
        return image
    }

    /// Running: tinted with the accent, and with the dial split into a solid swept
    /// arc and a faded remainder — so the colour reads as progress rather than as a
    /// flat recolour of the idle mark.
    ///
    /// `tint` must already be resolved against the target appearance; a dynamic
    /// `NSColor` would resolve against whatever appearance is current while drawing.
    static func running(tint: NSColor) -> NSImage {
        let image = NSImage(size: size, flipped: false) { _ in
            tint.setStroke()
            tint.setFill()
            drawMark(sweep: sweptAngle)
            return true
        }
        // A template image would throw the tint away.
        image.isTemplate = false
        image.accessibilityDescription = "ChronoTask grabando"
        return image
    }

    // MARK: - Geometry

    // Laid out for an 18×18 canvas in AppKit's y-up coordinates. The dial sits left
    // of centre to leave room for the crown button on its upper right.
    private static let dialCenter = NSPoint(x: 8.3, y: 7.5)
    private static let dialRadius: CGFloat = 5.4
    private static let strokeWidth: CGFloat = 1.6

    /// Where the solid part of the dial stops, clockwise from 12 o'clock. Static:
    /// animating it would mean redrawing the status item every second for a detail
    /// that reads as texture, not as information.
    private static let sweptAngle: CGFloat = 250

    /// The faded remainder of the dial in the running state.
    private static let trackAlpha: CGFloat = 0.35

    private static func drawMark(sweep: CGFloat?) {
        drawCrown()
        drawSideButton()
        drawDial(sweep: sweep)
        drawHand()
    }

    /// The stem and cap on top, drawn as one rounded bar that tucks under the dial.
    private static func drawCrown() {
        let width: CGFloat = 5.0
        let height: CGFloat = 2.6
        let rect = NSRect(x: dialCenter.x - width / 2,
                          y: dialCenter.y + dialRadius - 0.4,
                          width: width,
                          height: height)
        NSBezierPath(roundedRect: rect, xRadius: 0.9, yRadius: 0.9).fill()
    }

    /// The start/stop pusher, angled off the dial's upper right.
    private static func drawSideButton() {
        let rect = NSRect(x: -1.6, y: -1.1, width: 3.2, height: 2.2)
        let path = NSBezierPath(roundedRect: rect, xRadius: 0.8, yRadius: 0.8)

        let transform = NSAffineTransform()
        // Close enough to the rim that the two shapes read as one object; any further
        // out and the pusher looks like a detached speck at menu bar size.
        transform.translateX(by: dialCenter.x + 4.3, yBy: dialCenter.y + 4.8)
        transform.rotate(byDegrees: -38)
        path.transform(using: transform as AffineTransform)
        path.fill()
    }

    private static func drawDial(sweep: CGFloat?) {
        guard let sweep else {
            strokedCircle().stroke()
            return
        }

        // The unswept remainder first, so the solid arc wins wherever they meet.
        // The fade comes from the context's alpha rather than a paler colour: the
        // caller has already set the stroke to the resolved tint, and replacing it
        // here would throw that tint away.
        let track = arc(from: sweep, to: 360)
        track.lineWidth = strokeWidth
        track.lineCapStyle = .round
        track.stroke(withAlpha: trackAlpha)

        let solid = arc(from: 0, to: sweep)
        solid.lineWidth = strokeWidth
        solid.lineCapStyle = .round
        solid.stroke()
    }

    private static func strokedCircle() -> NSBezierPath {
        let path = NSBezierPath(ovalIn: NSRect(x: dialCenter.x - dialRadius,
                                               y: dialCenter.y - dialRadius,
                                               width: dialRadius * 2,
                                               height: dialRadius * 2))
        path.lineWidth = strokeWidth
        return path
    }

    /// `start` and `end` are degrees clockwise from 12 o'clock, which is how the
    /// sweep of a stopwatch is naturally described; `NSBezierPath` wants degrees
    /// counter-clockwise from 3 o'clock.
    private static func arc(from start: CGFloat, to end: CGFloat) -> NSBezierPath {
        let path = NSBezierPath()
        path.appendArc(withCenter: dialCenter,
                       radius: dialRadius,
                       startAngle: 90 - start,
                       endAngle: 90 - end,
                       clockwise: true)
        return path
    }

    /// Pointing at roughly one o'clock, as in the original mark.
    private static func drawHand() {
        let angle = CGFloat.pi / 3.6
        let path = NSBezierPath()
        path.move(to: dialCenter)
        path.line(to: NSPoint(x: dialCenter.x + cos(angle) * 3.4,
                              y: dialCenter.y + sin(angle) * 3.4))
        path.lineWidth = strokeWidth * 0.95
        path.lineCapStyle = .round
        path.stroke()
    }
}

private extension NSBezierPath {
    /// Strokes at reduced opacity without disturbing the current stroke colour.
    func stroke(withAlpha alpha: CGFloat) {
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current?.cgContext.setAlpha(alpha)
        stroke()
        NSGraphicsContext.restoreGraphicsState()
    }
}
