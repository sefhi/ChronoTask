import SwiftUI

/// Start / stop. Fills the row next to the daily chip.
struct PrimaryActionButton: View {
    let isRunning: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                TransportGlyph(isRunning: isRunning, size: isRunning ? 8 : Theme.glyphSize)

                Text(isRunning ? "Detener" : "Iniciar")
                    .font(Theme.ctaFont)
                    .foregroundColor(Theme.onAccent)

                Spacer(minLength: 4)

                Text("SPACE")
                    .font(Theme.hintFont)
                    .tracking(Theme.trackingHint)
                    .foregroundColor(Theme.onAccent)
                    .opacity(0.55)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .frame(height: Theme.controlHeight)
        }
        .buttonStyle(.chronoAccent)
        .disabled(!isEnabled)
        .accessibilityLabel(isRunning ? "Detener el cronómetro" : "Iniciar el cronómetro")
    }
}
