import SwiftUI

enum PillState {
    /// No task chosen yet.
    case noTask
    /// A task is selected and the timer is stopped.
    case ready
    /// Timing.
    case recording
}

struct StatusPill: View {
    let state: PillState

    var body: some View {
        HStack(spacing: 6) {
            // The dot only exists while recording — in the other states the label
            // carries the meaning on its own.
            if state == .recording {
                Circle()
                    .fill(Theme.accent)
                    .frame(width: Theme.dotSize, height: Theme.dotSize)
                    .background {
                        // A solid ring *outside* the dot. Stroking the dot itself
                        // centres the line on its path and eats into the dot.
                        Circle()
                            .fill(Theme.accentHalo)
                            .frame(width: Theme.dotSize + Theme.haloRing * 2,
                                   height: Theme.dotSize + Theme.haloRing * 2)
                    }
            }

            Text(label)
                .font(Theme.labelFont)
                .tracking(Theme.trackingLabel)
                .foregroundColor(state == .recording ? Theme.accent : Theme.inkSecondary)
        }
        .animation(Theme.panelAnimation, value: state)
    }

    private var label: String {
        switch state {
        case .noTask:    return "SIN TAREA"
        case .ready:     return "READY"
        case .recording: return "REC"
        }
    }
}
