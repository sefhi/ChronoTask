import SwiftUI

/// The refresh control that sits inside the search field, between the query and the
/// `ESC` hint. Spins while a load is in flight.
struct RefreshButton: View {
    let isSyncing: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button {
            // Guarded rather than `.disabled`, which would dim the glyph — the
            // prototype keeps it at full accent while it turns.
            guard !isSyncing else { return }
            action()
        } label: {
            glyph
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help("Actualizar tareas")
        .accessibilityLabel(isSyncing ? "Actualizando tareas" : "Actualizar tareas")
    }

    @ViewBuilder
    private var glyph: some View {
        let icon = Image(systemName: "arrow.clockwise")
            .font(.system(size: Theme.refreshIconSize, weight: .medium))
            .foregroundColor(tint)
            // A 12pt glyph is a small target; this widens it without pushing the
            // text field around.
            .frame(width: 16, height: 16)
            .contentShape(Rectangle())

        // Two branches on purpose. A `repeatForever` animation cannot be stopped by
        // setting its value back — it can only die with the view running it, so the
        // spinning and still glyphs must have separate identities.
        if isSyncing {
            icon.modifier(Spin())
        } else {
            icon
        }
    }

    private var tint: Color {
        if isSyncing { return Theme.accent }
        return isHovered ? Theme.accent : Theme.inkQuaternary
    }
}

/// Rotates its content indefinitely, starting when it appears and stopping by being
/// removed from the tree.
private struct Spin: ViewModifier {
    @State private var angle: Double = 0

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(angle))
            .onAppear {
                withAnimation(Theme.spinAnimation) { angle = 360 }
            }
    }
}
