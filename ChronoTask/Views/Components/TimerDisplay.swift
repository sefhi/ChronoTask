import SwiftUI

struct TimerDisplay: View {
    let elapsed: TimeInterval
    let isRunning: Bool

    var body: some View {
        Text(elapsed.timerFormatted)
            .font(Theme.timerFont)
            .monospacedDigit()
            .foregroundColor(isRunning ? Theme.timerRunningColor : Theme.timerIdleColor)
    }
}
