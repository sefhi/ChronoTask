import SwiftUI

/// Start / stop. Fills the row next to the daily chip.
///
/// The two states are deliberately not the same button in two colours: starting is
/// filled terracotta, stopping is a tint with an outline. Both are obviously
/// pressable, but only one is competing for attention at a time.
struct PrimaryActionButton: View {
    let isRunning: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                TransportGlyph(isRunning: isRunning,
                               size: isRunning ? 8 : Theme.glyphSize,
                               color: glyphColor)

                Text(isRunning ? "Detener" : "Iniciar")
                    .font(Theme.ctaFont)
                    .foregroundColor(labelColor)

                Spacer(minLength: 4)

                Text("SPACE")
                    .font(Theme.hintFont)
                    .tracking(Theme.trackingHint)
                    .foregroundColor(labelColor)
                    .opacity(0.55)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .frame(height: Theme.controlHeight)
        }
        .buttonStyle(isRunning ? .chronoStop : .chronoAccent)
        .disabled(!isEnabled)
        .accessibilityLabel(isRunning ? "Detener el cronómetro" : "Iniciar el cronómetro")
    }

    private var labelColor: Color {
        isRunning ? Theme.stopLabel : Theme.onAccent
    }

    /// On the filled button the glyph is white; on the tinted one it takes the accent,
    /// which in the dark is the lightened variant — `#C56446` on its own 24% wash
    /// falls under the 3:1 that non-text needs.
    private var glyphColor: Color {
        isRunning ? Theme.accent : Theme.onAccent
    }
}
