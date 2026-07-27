import SwiftUI

struct TimerDisplay: View {
    let elapsed: TimeInterval

    var body: some View {
        Text(elapsed.timerFormatted)
            .font(Theme.timerFont)
            .monospacedDigit()
            .tracking(Theme.trackingTimer)
            .foregroundColor(Theme.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .accessibilityLabel("Tiempo transcurrido")
            .accessibilityValue(elapsed.timerFormatted)
    }
}
