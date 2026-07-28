import CoreGraphics
import Foundation

/// ChronoTask's stopwatch mark, transcribed from the prototype's SVG.
///
/// One definition for all three places the design shows it — the panel header, the
/// hover peek and the menu bar — because it is one mark. The menu bar copy used to be
/// drawn by eye from a rendered PDF and had drifted: different centre, different
/// radius, and no hub at all.
///
/// Everything is expressed in the prototype's 18×18 viewBox with **y pointing down**,
/// as in SVG. Callers scale, and the AppKit side flips.
enum ChronoMark {

    static let viewBox: CGFloat = 18

    /// Centre of the dial. Note it is below the box's middle: the crown sits above.
    private static let centre = CGPoint(x: 9, y: 10.2)

    /// The ring is drawn in the SVG as r=6.5 minus r=4.8, i.e. a 1.7-wide band whose
    /// mid-line is 5.65.
    private static let ringRadius: CGFloat = 5.65
    private static let ringWidth: CGFloat = 1.7

    /// The running mark sweeps from 12 o'clock to the SVG's end point at
    /// (3.51, 13.68) — 237.6° clockwise.
    private static let sweepDegrees: CGFloat = 237.6

    /// Opacity of the full ring left showing behind the sweep.
    static let trackOpacity: CGFloat = 0.3

    // MARK: - Parts

    /// The complete ring, for the idle mark and as the track behind the sweep.
    static func ring(scale: CGFloat = 1) -> CGPath {
        let circle = CGPath(
            ellipseIn: CGRect(x: centre.x - ringRadius, y: centre.y - ringRadius,
                              width: ringRadius * 2, height: ringRadius * 2),
            transform: nil
        )
        return scaled(circle.copy(strokingWithWidth: ringWidth, lineCap: .butt,
                                  lineJoin: .miter, miterLimit: 10), scale)
    }

    /// The swept arc. Its far end is squared off; `sweepCap` rounds it.
    ///
    /// Kept apart from the cap — as the SVG keeps them, as sibling elements — because
    /// merged into one path the two overlap with opposing winding, and a nonzero fill
    /// then punches the cap straight back out again.
    static func sweep(scale: CGFloat = 1) -> CGPath {
        // -90° is 12 o'clock. y grows downward here, so a clockwise sweep on screen
        // is an increasing angle.
        let arc = CGMutablePath()
        arc.addArc(center: centre, radius: ringRadius,
                   startAngle: sweepStart, endAngle: sweepEnd, clockwise: false)
        return scaled(arc.copy(strokingWithWidth: ringWidth, lineCap: .butt,
                               lineJoin: .miter, miterLimit: 10), scale)
    }

    /// Half the stroke width, centred on the ring's mid-line at the end angle —
    /// exactly the circle the prototype hard-codes at (4.23, 13.23).
    static func sweepCap(scale: CGFloat = 1) -> CGPath {
        let point = CGPoint(x: centre.x + cos(sweepEnd) * ringRadius,
                            y: centre.y + sin(sweepEnd) * ringRadius)
        let circle = CGPath(
            ellipseIn: CGRect(x: point.x - ringWidth / 2, y: point.y - ringWidth / 2,
                              width: ringWidth, height: ringWidth),
            transform: nil
        )
        return scaled(circle, scale)
    }

    private static let sweepStart = -CGFloat.pi / 2
    private static let sweepEnd = -CGFloat.pi / 2 + sweepDegrees * .pi / 180

    /// Crown, pusher, hand and hub — the parts present in both states.
    static func dial(scale: CGFloat = 1) -> CGPath {
        let path = CGMutablePath()

        // Crown: the flat cap on top.
        path.addRoundedRect(in: CGRect(x: 6.7, y: 2.19995, width: 4.6, height: 2.3),
                            cornerWidth: 1.1, cornerHeight: 1.1)

        // Pusher, angled off the upper right.
        path.addPath(rotatedRoundedRect(
            CGRect(x: 11.3725, y: 4.49487, width: 3.1, height: 1.7),
            radius: 0.85, degrees: -35, about: CGPoint(x: 11.3725, y: 4.49487)))

        // The hand, running down-left from the rim towards the hub.
        path.addPath(rotatedRoundedRect(
            CGRect(x: 10.7701, y: 6.19019, width: 1.7, height: 4.3),
            radius: 0.85, degrees: 35, about: CGPoint(x: 10.7701, y: 6.19019)))

        // Hub.
        path.addEllipse(in: CGRect(x: centre.x - 1.25, y: centre.y - 1.25,
                                   width: 2.5, height: 2.5))

        return scaled(path, scale)
    }

    // MARK: - Helpers

    /// SVG's `rotate(deg cx cy)`: rotate about an arbitrary point. Positive is
    /// clockwise on screen, which in this y-down space is a positive CG rotation.
    private static func rotatedRoundedRect(_ rect: CGRect,
                                           radius: CGFloat,
                                           degrees: CGFloat,
                                           about pivot: CGPoint) -> CGPath {
        var transform = CGAffineTransform(translationX: pivot.x, y: pivot.y)
            .rotated(by: degrees * .pi / 180)
            .translatedBy(x: -pivot.x, y: -pivot.y)
        return CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius,
                      transform: &transform)
    }

    private static func scaled(_ path: CGPath, _ scale: CGFloat) -> CGPath {
        guard scale != 1 else { return path }
        var transform = CGAffineTransform(scaleX: scale, y: scale)
        return path.copy(using: &transform) ?? path
    }
}
