import SwiftUI

enum PillState: Equatable {
    /// Nothing running.
    case ready
    /// Timing `count` tasks at once.
    case recording(count: Int)

    var isRecording: Bool {
        if case .recording = self { return true }
        return false
    }
}

struct StatusPill: View {
    let state: PillState

    var body: some View {
        HStack(spacing: 6) {
            // The dot only exists while recording — in the other states the label
            // carries the meaning on its own.
            if state.isRecording {
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
                .foregroundColor(state.isRecording ? Theme.accent : Theme.inkSecondary)
        }
        .animation(Theme.panelAnimation, value: state)
    }

    private var label: String {
        switch state {
        case .ready:
            return "READY"
        case .recording(let count):
            return count > 1 ? "REC · \(count) EN PARALELO" : "REC"
        }
    }
}
