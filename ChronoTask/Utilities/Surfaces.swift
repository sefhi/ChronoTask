import SwiftUI

/// The glass look is split across two layers and neither may do the other's job:
///
/// - The **window** supplies the blur (`NSVisualEffectView`, `.behindWindow`) and the
///   drop shadow. Only it can sample the desktop.
/// - **These modifiers** supply the tint, the border and the top-edge highlight.
///
/// SwiftUI `Material` is deliberately absent: it blurs what is *inside* the window,
/// which over a transparent window background buys nothing and costs a compositing
/// pass. `selfBlur` exists only for previews, where there is no window behind.
struct GlassSurface: ViewModifier {
    var radius: CGFloat = Theme.radiusPanel
    var selfBlur: Bool = false
    var shadow: Bool = false

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        return content
            .background {
                ZStack {
                    if selfBlur && !reduceTransparency {
                        Rectangle().fill(.ultraThinMaterial)
                    }
                    Rectangle().fill(reduceTransparency ? Theme.glassTintOpaque : Theme.glassTint)
                }
                .clipShape(shape)
            }
            // `strokeBorder`, not `stroke`: the latter centres the line on the path, so
            // half of a 0.5pt border falls outside the shape and gets clipped away.
            .overlay {
                shape.strokeBorder(Theme.glassStroke, lineWidth: Theme.strokeHairline)
            }
            // `inset 0 1px 0`. A gradient stroke that fades out by 35% follows the
            // rounded corners correctly; `UnevenRoundedRectangle` is macOS 14+.
            .overlay {
                shape.strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: Theme.glassHighlight, location: 0),
                            .init(color: Theme.glassHighlight.opacity(0), location: 0.35)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: Theme.strokeHighlight
                )
            }
            .compositingGroup()
            .shadow(
                color: shadow ? Theme.glassShadow : .clear,
                radius: shadow ? Theme.shadowGlassRadius : 0,
                y: shadow ? Theme.shadowGlassY : 0
            )
            .contentShape(shape)
    }
}

/// Recessed surface used by the task caption, the search field and the daily chip.
/// Sitting a further ~40% white over the glass is also what keeps their text legible.
struct InsetSurface: ViewModifier {
    var radius: CGFloat = Theme.radiusSurface
    var fill: Color = Theme.insetFill

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        return content
            .background(fill, in: shape)
            .overlay { shape.strokeBorder(Theme.insetStroke, lineWidth: Theme.strokeHairline) }
            .contentShape(shape)
    }
}

extension View {
    func glassSurface(radius: CGFloat = Theme.radiusPanel,
                      selfBlur: Bool = false,
                      shadow: Bool = false) -> some View {
        modifier(GlassSurface(radius: radius, selfBlur: selfBlur, shadow: shadow))
    }

    func insetSurface(radius: CGFloat = Theme.radiusSurface,
                      fill: Color = Theme.insetFill) -> some View {
        modifier(InsetSurface(radius: radius, fill: fill))
    }

    /// Standard panel/peek entrance: fade plus a short vertical slide.
    func chronoPanelTransition() -> some View {
        transition(.opacity.combined(with: .offset(y: Theme.panelOffset)))
    }
}
