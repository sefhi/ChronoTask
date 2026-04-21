import SwiftUI

private struct PlayTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Full-width bottom bar that toggles the timer start/stop.
/// Transparent + ink text when idle, accent bg + background text when running.
struct StartStopBar: View {
    let isRunning: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isRunning {
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 6, height: 6)
                } else {
                    PlayTriangle()
                        .fill(Theme.ink)
                        .frame(width: 6, height: 8)
                }
                Text(isRunning ? "Stop" : "Start")
                Text("SPACE")
                    .opacity(0.5)
                    .padding(.leading, 8)
            }
            .font(Theme.buttonFont)
            .tracking(2.5)
            .foregroundColor(isRunning ? Theme.background : Theme.ink)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(isRunning ? Theme.accent : Color.clear)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Theme.hairline)
                    .frame(height: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.35 : 1)
        .frame(height: Theme.barHeight)
        .animation(Theme.barAnimation, value: isRunning)
    }
}
