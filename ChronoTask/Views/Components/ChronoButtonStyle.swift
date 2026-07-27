import SwiftUI

enum ChronoButtonKind {
    /// Filled terracotta — the primary start/stop action.
    case accent
    /// Recessed surface — task caption, daily chip, workspace rows.
    case inset
    /// No chrome until hovered — list rows and icon buttons.
    case ghost
}

struct ChronoButtonStyle: ButtonStyle {
    var kind: ChronoButtonKind = .accent
    var radius: CGFloat = Theme.radiusControl

    func makeBody(configuration: Configuration) -> some View {
        StyleBody(configuration: configuration, kind: kind, radius: radius)
    }

    /// Hover state lives in a nested `View`, not in the style itself: a `ButtonStyle`
    /// is a value SwiftUI recreates on every render, so `@State` declared on it has
    /// no stable identity.
    private struct StyleBody: View {
        let configuration: Configuration
        let kind: ChronoButtonKind
        let radius: CGFloat

        @Environment(\.isEnabled) private var isEnabled
        @State private var hovering = false

        var body: some View {
            let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
            let pressed = configuration.isPressed

            return configuration.label
                .background { background(shape) }
                .overlay { border(shape) }
                .brightness(pressed ? -0.05 : 0)
                .scaleEffect(pressed ? 0.985 : 1)
                .opacity(isEnabled ? 1 : 0.45)
                .contentShape(shape)
                .onHover { hovering = $0 && isEnabled }
                .animation(Theme.hoverAnimation, value: hovering)
                .animation(Theme.pressAnimation, value: pressed)
        }

        @ViewBuilder
        private func background(_ shape: RoundedRectangle) -> some View {
            switch kind {
            case .accent:
                shape.fill(Theme.accentFill).opacity(hovering ? 1 : 0.92)
            case .inset:
                shape.fill(hovering ? Theme.insetFillHover : Theme.insetFill)
            case .ghost:
                shape.fill(hovering ? Theme.rowHover : Color.clear)
            }
        }

        @ViewBuilder
        private func border(_ shape: RoundedRectangle) -> some View {
            if kind == .inset {
                shape.strokeBorder(Theme.insetStroke, lineWidth: Theme.strokeHairline)
            }
        }
    }
}

extension ButtonStyle where Self == ChronoButtonStyle {
    static var chronoAccent: Self {
        ChronoButtonStyle(kind: .accent, radius: Theme.radiusControl)
    }

    static func chronoInset(radius: CGFloat = Theme.radiusSurface) -> Self {
        ChronoButtonStyle(kind: .inset, radius: radius)
    }

    static func chronoGhost(radius: CGFloat = Theme.radiusRow) -> Self {
        ChronoButtonStyle(kind: .ghost, radius: radius)
    }
}
