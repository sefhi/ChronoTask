import SwiftUI

/// The stopwatch mark, for the panel header and the peek.
///
/// While running the full ring stays behind at 30% and a swept arc is laid over it,
/// so the accent reads as elapsed progress rather than as a recolour.
struct ChronoMarkView: View {
    let isRunning: Bool
    var size: CGFloat = 18
    var color: Color

    var body: some View {
        ZStack {
            if isRunning {
                MarkPart.ring.shape.fill(color.opacity(ChronoMark.trackOpacity))
                MarkPart.sweep.shape.fill(color)
                MarkPart.sweepCap.shape.fill(color)
            } else {
                MarkPart.ring.shape.fill(color)
            }
            MarkPart.dial.shape.fill(color)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

private enum MarkPart {
    case ring, sweep, sweepCap, dial

    var shape: MarkShape { MarkShape(part: self) }
}

/// Scales the 18×18 definition to whatever it is given. The paths are already
/// outlined, so a plain fill is all that is needed and stroke width scales with
/// everything else.
private struct MarkShape: Shape {
    let part: MarkPart

    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / ChronoMark.viewBox
        switch part {
        case .ring:     return Path(ChronoMark.ring(scale: scale))
        case .sweep:    return Path(ChronoMark.sweep(scale: scale))
        case .sweepCap: return Path(ChronoMark.sweepCap(scale: scale))
        case .dial:     return Path(ChronoMark.dial(scale: scale))
        }
    }
}
