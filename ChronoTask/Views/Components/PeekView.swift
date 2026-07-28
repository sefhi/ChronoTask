import SwiftUI

/// Contents of the hover peek: stop the timer without opening the panel.
struct PeekView: View {
    let elapsed: TimeInterval
    let isRunning: Bool
    let isEnabled: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: Theme.peekGap) {
            // The mark, as in the design — not a bare dot. At 15pt the swept dial is
            // still legible, and it says *which* app this floating capsule belongs to.
            ChronoMarkView(isRunning: isRunning,
                           size: 15,
                           color: isRunning ? Theme.accent : Theme.markHeader)

            Text(elapsed.timerFormatted)
                .font(Theme.peekTimeFont)
                .monospacedDigit()
                .foregroundColor(Theme.ink)

            Button(action: onToggle) {
                TransportGlyph(isRunning: isRunning,
                               color: isRunning ? Theme.accent : Theme.onAccent)
                    .frame(width: Theme.peekButtonSize, height: Theme.peekButtonSize)
                    .background { transportBackground }
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1 : 0.4)
            .accessibilityLabel(isRunning ? "Detener el cronómetro" : "Iniciar el cronómetro")
        }
        .padding(Theme.peekInsets)
        // Sized by its content so the peek window can measure itself.
        .fixedSize()
        .glassSurface(radius: Theme.radiusPeek)
    }

    /// Filled while stopped, tinted and outlined while running — the same distinction
    /// the panel's primary button makes, so the peek is not a second visual language.
    @ViewBuilder
    private var transportBackground: some View {
        if isRunning {
            Circle()
                .fill(Theme.peekStopFill)
                .overlay {
                    Circle().strokeBorder(Theme.peekStopStroke, lineWidth: Theme.strokeStop)
                }
        } else {
            Circle().fill(Theme.accentFill)
        }
    }
}
