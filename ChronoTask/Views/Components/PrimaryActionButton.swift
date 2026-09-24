import SwiftUI

/// "Detener" / "Detener 3": the footer's main action while anything runs.
///
/// Tinted and outlined rather than filled. Starting is now picking a task from the
/// list, so stopping never has a filled button to compete with — but it keeps the
/// treatment that marks it as the quieter half of the pair.
struct PrimaryActionButton: View {
    let title: String
    /// Keyboard hint on the trailing edge. "SPACE" fits when the button has the
    /// row to itself; beside "Solo esta" it shrinks to "␣".
    var hint = "SPACE"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                // On its own 24% wash the base terracotta falls under the 3:1 that
                // non-text needs in the dark, so the glyph takes the lightened accent.
                TransportGlyph(isRunning: true, size: 8, color: Theme.accent)

                Text(title)
                    .font(Theme.ctaFont)
                    .foregroundColor(Theme.stopLabel)
                    .lineLimit(1)

                Spacer(minLength: 4)

                Text(hint)
                    .font(Theme.hintFont)
                    .tracking(Theme.trackingHint)
                    .foregroundColor(Theme.stopLabel)
                    .opacity(0.55)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .frame(height: Theme.controlHeight)
        }
        .buttonStyle(.chronoStop)
        .accessibilityLabel(title)
        .accessibilityHint("Atajo: espacio")
    }
}

/// A quiet footer button on the inset surface — "Solo esta", and the disabled
/// placeholder shown while nothing runs.
struct SecondaryActionButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.ctaFont)
                .foregroundColor(Theme.inkSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity)
                .frame(height: Theme.controlHeight)
        }
        .buttonStyle(.chronoInset(radius: Theme.radiusControl))
    }
}
