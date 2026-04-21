import SwiftUI

struct TimerDisplay: View {
    let elapsed: TimeInterval

    var body: some View {
        Text(elapsed.timerFormatted)
            .font(Theme.timerFont)
            .monospacedDigit()
            .tracking(-1)
            .foregroundColor(Theme.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}
