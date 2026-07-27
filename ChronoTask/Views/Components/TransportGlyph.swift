import SwiftUI

/// Play triangle / stop square, shared by the primary button and the peek.
struct TransportGlyph: View {
    let isRunning: Bool
    var size: CGFloat = Theme.glyphSize
    var color: Color = Theme.onAccent

    var body: some View {
        Group {
            if isRunning {
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(color)
                    .frame(width: size, height: size)
            } else {
                PlayTriangle()
                    .fill(color)
                    .frame(width: size, height: size + 2)
            }
        }
        .animation(nil, value: isRunning)
    }
}

struct PlayTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
