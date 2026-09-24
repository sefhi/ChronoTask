import SwiftUI

/// "EN PARALELO": every run except the focused one, plus the row that adds another.
///
/// Clicking a row brings that task into focus; its own stop button, revealed on
/// hover, stops just that one without disturbing the rest.
struct ParallelTasksSection: View {
    let runs: [RunningTimer]
    let elapsed: (RunningTimer) -> TimeInterval
    let isListOpen: Bool
    let onFocus: (RunningTimer) -> Void
    let onStop: (RunningTimer) -> Void
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            caption
                .padding(.horizontal, 2)

            VStack(spacing: 0) {
                ForEach(runs) { run in
                    ParallelRunRow(run: run,
                                   elapsed: elapsed(run),
                                   onFocus: { onFocus(run) },
                                   onStop: { onStop(run) })
                }
                AddParallelRow(isListOpen: isListOpen, action: onAdd)
            }
            .padding(3)
            .insetSurface(radius: Theme.radiusSurface)
        }
    }

    private var caption: some View {
        HStack {
            Text(runs.isEmpty ? "EN PARALELO" : "EN PARALELO · \(runs.count)")
                .font(Theme.labelFont)
                .tracking(Theme.trackingCaption)
            Spacer(minLength: 8)
            if !runs.isEmpty {
                Text("clic o ⇥ para enfocar")
                    .font(Theme.captionHintFont)
                    .tracking(0.3)
            }
        }
        .foregroundColor(Theme.inkSecondary)
    }
}

private struct ParallelRunRow: View {
    let run: RunningTimer
    let elapsed: TimeInterval
    let onFocus: () -> Void
    let onStop: () -> Void

    @State private var hovering = false

    var body: some View {
        // Two sibling buttons rather than a tap gesture over the row: this panel is
        // never the active window, and there `onTapGesture` lost the first click to
        // the "Añadir" button below it. Buttons take the first mouse; nesting one
        // in another's label would swallow the inner one's clicks.
        HStack(spacing: 8) {
            Button(action: onFocus) {
                HStack(spacing: 8) {
                    TaskIcon(task: run.task, isLive: true)

                    Text(run.task.strippedName)
                        .font(Theme.parallelRowFont)
                        .foregroundColor(Theme.ink)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(elapsed.timerFormatted)
                        .font(Theme.parallelTimeFont)
                        .monospacedDigit()
                        .foregroundColor(Theme.inkSecondary)
                }
                .padding(EdgeInsets(top: 6, leading: 9, bottom: 6, trailing: 0))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(run.task.strippedName)
            .accessibilityHint("Enfoca esta tarea")
            // The stop button is invisible until hovered, and so absent from the
            // accessibility tree; this keeps stopping one task reachable without a
            // pointer.
            .accessibilityAction(named: "Detener", onStop)

            RowStopButton(action: onStop)
                .opacity(hovering ? 0.8 : 0)
                .accessibilityLabel("Detener \(run.task.strippedName)")
                .padding(.trailing, 6)
        }
        .background {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(hovering ? Theme.parallelRowHover : .clear)
        }
        // Not `onHover`: that goes quiet over the button inside the row. See
        // `HoverTracker`.
        .background { HoverTracker { hovering = $0 } }
        .animation(Theme.hoverAnimation, value: hovering)
    }
}

private struct AddParallelRow: View {
    let isListOpen: Bool
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text("+")
                    .font(.system(size: 13))
                    .frame(width: Theme.rowIconWidth)
                Text("Añadir tarea en paralelo")
                    .font(Theme.parallelRowFont)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !isListOpen {
                    Text("⌘K")
                        .font(Theme.hintFont)
                        .foregroundColor(Theme.inkQuaternary)
                }
                Chevron(isExpanded: isListOpen)
            }
            .foregroundColor(hovering ? Theme.accent : Theme.inkSecondary)
            .padding(EdgeInsets(top: 6, leading: 9, bottom: 6, trailing: 9))
            .background {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(hovering ? Theme.parallelRowHover : .clear)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(Theme.hoverAnimation, value: hovering)
        .animation(Theme.listAnimation, value: isListOpen)
    }
}

/// Small round stop, in the same tint-and-outline treatment as "Detener".
struct RowStopButton: View {
    var size: CGFloat = Theme.rowStopSize
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            // The square keeps the prototype's proportion: 5pt in 18, 6pt in 22.
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(Theme.accent)
                .frame(width: (size * 0.28).rounded(), height: (size * 0.28).rounded())
                .frame(width: size, height: size)
                .background {
                    Circle()
                        .fill(Theme.stopFill)
                        .overlay { Circle().strokeBorder(Theme.stopStroke, lineWidth: Theme.strokeStop) }
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help("Detener y registrar")
    }
}
