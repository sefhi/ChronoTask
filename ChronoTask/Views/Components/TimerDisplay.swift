import SwiftUI

struct TimerDisplay: View {
    let elapsed: TimeInterval
    /// The focused task's clock runs a size smaller, with its name above it.
    var compact = false

    var body: some View {
        Text(elapsed.timerFormatted)
            .font(compact ? Theme.timerFontCompact : Theme.timerFont)
            .monospacedDigit()
            .tracking(Theme.trackingTimer)
            .foregroundColor(Theme.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .accessibilityLabel("Tiempo transcurrido")
            .accessibilityValue(elapsed.timerFormatted)
    }
}
