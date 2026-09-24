import SwiftUI

/// "Elige una tarea": with nothing running, the strip that opens the list.
struct TaskCaption: View {
    let isExpanded: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Theme.inkQuaternary)
                    .frame(width: Theme.taskDotSize, height: Theme.taskDotSize)
                    .frame(width: Theme.rowIconWidth)

                Text("Elige una tarea")
                    .font(Theme.captionFont)
                    .foregroundColor(Theme.inkTertiary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // A shortcut nobody can see is a shortcut nobody uses.
                if !isExpanded {
                    Text("⌘K")
                        .font(Theme.hintFont)
                        .foregroundColor(Theme.inkQuaternary)
                }

                Chevron(isExpanded: isExpanded)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.chronoInset(radius: Theme.radiusSurface))
        .animation(Theme.listAnimation, value: isExpanded)
        .accessibilityLabel("Elige una tarea")
        .accessibilityHint(isExpanded ? "Cierra la lista de tareas" : "Abre la lista de tareas")
    }
}

/// The disclosure chevron shared by every row that opens the task list.
struct Chevron: View {
    let isExpanded: Bool

    var body: some View {
        Image(systemName: "chevron.down")
            .font(.system(size: Theme.chevronSize, weight: .medium))
            .foregroundColor(Theme.inkQuaternary)
            .rotationEffect(.degrees(isExpanded ? 180 : 0))
    }
}
