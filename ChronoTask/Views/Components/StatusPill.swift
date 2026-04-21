import SwiftUI

enum PillState {
    case idle
    case running
    case empty
}

struct StatusPill: View {
    let state: PillState

    var body: some View {
        HStack(spacing: 6) {
            if state == .running {
                Circle()
                    .fill(Theme.accent)
                    .frame(width: Theme.statusDotSize, height: Theme.statusDotSize)
                    .overlay(
                        Circle()
                            .stroke(Theme.accentHalo, lineWidth: 3)
                            .frame(width: Theme.statusDotSize + 3,
                                   height: Theme.statusDotSize + 3)
                    )
            }
            Text(label)
                .font(Theme.labelFont)
                .tracking(1.8)
                .foregroundColor(color)
        }
    }

    private var label: String {
        switch state {
        case .idle:    return "READY"
        case .running: return "REC"
        case .empty:   return "EMPTY"
        }
    }

    private var color: Color {
        state == .running ? Theme.accent : Theme.muted
    }
}
