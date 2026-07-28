import SwiftUI

enum ChronoButtonKind {
    /// Filled terracotta — starting the timer, the panel's one primary action.
    case accent
    /// Tinted and outlined terracotta — stopping. Reads as actionable without
    /// competing with `accent` for the eye.
    case stop
    /// Recessed surface — task caption, workspace rows.
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
            case .stop:
                // The resting wash matches the prototype exactly, so hover deepens it
                // by laying a second one over the first rather than by raising an
                // opacity that is already at full.
                ZStack {
                    shape.fill(Theme.stopFill)
                    if hovering { shape.fill(Theme.stopFill) }
                }
            case .inset:
                shape.fill(hovering ? Theme.insetFillHover : Theme.insetFill)
            case .ghost:
                shape.fill(hovering ? Theme.rowHover : Color.clear)
            }
        }

        @ViewBuilder
        private func border(_ shape: RoundedRectangle) -> some View {
            switch kind {
            case .inset:
                shape.strokeBorder(Theme.insetStroke, lineWidth: Theme.strokeHairline)
            case .stop:
                shape.strokeBorder(Theme.stopStroke, lineWidth: Theme.strokeStop)
                // `inset 0 1px 0` — the same top-edge catch the glass surfaces get,
                // which is what stops the tint reading as a flat swatch.
                shape.strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: Theme.stopHighlight, location: 0),
                            .init(color: Theme.stopHighlight.opacity(0), location: 0.35)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: Theme.strokeHighlight
                )
            case .accent, .ghost:
                EmptyView()
            }
        }
    }
}

extension ButtonStyle where Self == ChronoButtonStyle {
    static var chronoAccent: Self {
        ChronoButtonStyle(kind: .accent, radius: Theme.radiusControl)
    }

    static var chronoStop: Self {
        ChronoButtonStyle(kind: .stop, radius: Theme.radiusControl)
    }

    static func chronoInset(radius: CGFloat = Theme.radiusSurface) -> Self {
        ChronoButtonStyle(kind: .inset, radius: radius)
    }

    static func chronoGhost(radius: CGFloat = Theme.radiusRow) -> Self {
        ChronoButtonStyle(kind: .ghost, radius: radius)
    }
}
