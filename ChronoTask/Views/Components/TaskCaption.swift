import SwiftUI

/// The clickable strip showing the selected task, which also toggles the list.
struct TaskCaption: View {
    let task: ClickUpTask?
    let isRunning: Bool
    let isExpanded: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Circle()
                    .fill(isRunning ? Theme.accent : Theme.inkQuaternary)
                    .frame(width: Theme.dotSize, height: Theme.dotSize)

                Text(task?.name ?? "Elige una tarea")
                    .font(Theme.captionFont)
                    .foregroundColor(task == nil ? Theme.inkTertiary : Theme.ink)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // A shortcut nobody can see is a shortcut nobody uses.
                if !isExpanded {
                    Text("⌘K")
                        .font(Theme.hintFont)
                        .foregroundColor(Theme.inkQuaternary)
                }

                Image(systemName: "chevron.down")
                    .font(.system(size: Theme.chevronSize, weight: .medium))
                    .foregroundColor(Theme.inkQuaternary)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.chronoInset(radius: Theme.radiusSurface))
        .animation(Theme.listAnimation, value: isExpanded)
        .accessibilityLabel("Tarea seleccionada")
        .accessibilityValue(task?.name ?? "ninguna")
        .accessibilityHint(isExpanded ? "Cierra la lista de tareas" : "Abre la lista de tareas")
    }
}
