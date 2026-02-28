import SwiftUI

struct PlayStopButton: View {
    let isRunning: Bool
    let isDisabled: Bool
    let action: () -> Void

    private let size: CGFloat = 44
    private let iconSize: CGFloat = 20
    private let radius: CGFloat = 12

    var body: some View {
        Button(action: action) {
            Image(systemName: isRunning ? "stop.fill" : "play.fill")
                .font(.system(size: iconSize))
                .foregroundColor(.white)
                .frame(width: size, height: size)
                .background(isRunning ? Theme.stopColor : Theme.playColor)
                .cornerRadius(radius)
                .shadow(
                    color: (isRunning ? Theme.stopColor : Theme.playColor).opacity(0.25),
                    radius: 6,
                    y: 3
                )
                .opacity(isDisabled ? 0.4 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}
