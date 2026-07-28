import SwiftUI

/// The "…" button in the panel header.
struct PanelMenuButton: View {
    let isOpen: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle()
                        .fill(isOpen || isHovered ? Theme.ink.opacity(0.75) : Theme.inkQuaternary)
                        .frame(width: 2.8, height: 2.8)
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help("Más opciones")
        .accessibilityLabel("Más opciones")
    }
}

/// What the header menu can do. Kept as a type rather than three closures so the rows
/// can be built from a list and the danger styling attaches to the item, not the call
/// site.
enum PanelMenuAction: Hashable {
    case about
    case changeAPIKey
    case quit

    var title: String {
        switch self {
        case .about:        return "Acerca de ChronoTask"
        case .changeAPIKey: return "Cambiar API key…"
        case .quit:         return "Salir de ChronoTask"
        }
    }

    var symbol: String {
        switch self {
        case .about:        return "info.circle"
        case .changeAPIKey: return "key"
        case .quit:         return "rectangle.portrait.and.arrow.right"
        }
    }

    var shortcut: String? {
        self == .quit ? "⌘Q" : nil
    }

    /// Quit is set apart: it is the one item here you cannot undo by clicking again.
    var isDangerous: Bool {
        self == .quit
    }
}

/// Drop-down for the header button.
///
/// Built in SwiftUI rather than as an `NSMenu` because the prototype's menu is part
/// of the panel's own visual language — rounded like it, tinted like it, with an
/// accent hover on Quit. An `NSMenu` would be drawn by the system in the system's
/// style, and could not be made to match.
struct PanelMenu: View {
    let onSelect: (PanelMenuAction) -> Void

    var body: some View {
        VStack(spacing: 0) {
            row(.about)
            row(.changeAPIKey)

            Rectangle()
                .fill(Theme.menuSeparator)
                .frame(height: Theme.strokeHairline)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)

            row(.quit)
        }
        .padding(5)
        .frame(width: Theme.menuWidth)
        .background {
            RoundedRectangle(cornerRadius: Theme.radiusMenu, style: .continuous)
                .fill(Theme.menuFill)
        }
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radiusMenu, style: .continuous)
                .strokeBorder(Theme.menuStroke, lineWidth: Theme.strokeHairline)
        }
        .compositingGroup()
        .shadow(color: Theme.menuShadow, radius: 14, y: 5)
        .accessibilityElement(children: .contain)
    }

    private func row(_ action: PanelMenuAction) -> some View {
        PanelMenuRow(action: action) { onSelect(action) }
    }
}

private struct PanelMenuRow: View {
    let action: PanelMenuAction
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 9) {
                Image(systemName: action.symbol)
                    .font(.system(size: Theme.menuIconSize, weight: .regular))
                    .opacity(0.6)
                    .frame(width: 14, alignment: .center)

                Text(action.title)
                    .font(Theme.menuRowFont)
                    .lineLimit(1)

                Spacer(minLength: 6)

                if let shortcut = action.shortcut {
                    Text(shortcut)
                        .font(Theme.menuKeyFont)
                        .opacity(0.45)
                }
            }
            .foregroundColor(foreground)
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: Theme.radiusMenuRow, style: .continuous)
                    .fill(background)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    private var background: Color {
        guard isHovered else { return .clear }
        return action.isDangerous ? Theme.menuRowDangerHover : Theme.menuRowHover
    }

    private var foreground: Color {
        isHovered && action.isDangerous ? Theme.stopLabel : Theme.ink
    }
}
