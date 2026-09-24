import SwiftUI

/// The 14pt leading glyph of a task row: its leading emoji, or a dot in the
/// colour ClickUp gives its status.
///
/// `isLive` marks a task that is being timed right now: the dot breathes with a
/// soft halo (`.ico.live i` in the prototype), so running rows read apart from the
/// pickable ones at a glance.
struct TaskIcon: View {
    let task: ClickUpTask
    var isLive = false

    @State private var pulsing = false

    var body: some View {
        Group {
            if let emoji = task.leadingEmoji {
                Text(emoji)
                    .font(.system(size: 11))
            } else {
                Circle()
                    .fill(task.statusTint)
                    .frame(width: Theme.taskDotSize, height: Theme.taskDotSize)
                    .background {
                        if isLive {
                            Circle()
                                .fill(Theme.accentHalo)
                                .frame(width: Theme.taskDotSize + Theme.haloRing * 2,
                                       height: Theme.taskDotSize + Theme.haloRing * 2)
                                .opacity(pulsing ? 1 : 0)
                                // Scoped to the halo. A `withAnimation` in `onAppear`
                                // would sweep every sibling change of that transaction
                                // into a forever-repeating animation — the clock beside
                                // this icon included.
                                .animation(Theme.livePulseAnimation, value: pulsing)
                        }
                    }
            }
        }
        .frame(width: Theme.rowIconWidth)
        .onAppear { pulsing = isLive }
        .accessibilityHidden(true)
    }
}
