import SwiftUI

/// One running task, as the peek lists it.
struct PeekRow: Identifiable, Equatable {
    let task: ClickUpTask
    let elapsed: TimeInterval
    var id: String { task.id }
}

/// Contents of the hover peek: every task being timed, at a glance, without
/// opening the panel. Read-only on purpose — stopping lives in the panel, where the
/// user can see which task they are about to stop.
struct PeekView: View {
    let rows: [PeekRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if rows.isEmpty {
                idle
            } else {
                ForEach(rows) { row in
                    HStack(spacing: 8) {
                        TaskIcon(task: row.task, isLive: true)
                        Text(row.task.strippedName)
                            .font(Theme.peekRowFont)
                            .foregroundColor(Theme.ink)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(row.elapsed.timerFormatted)
                            .font(Theme.peekRowTimeFont)
                            .monospacedDigit()
                            .foregroundColor(Theme.ink)
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 4)
                }

                if rows.count > 1 {
                    totalLine
                }
            }
        }
        .padding(EdgeInsets(top: 10, leading: 10, bottom: 8, trailing: 10))
        .frame(width: Theme.peekWidth)
        // Sized by its content so the peek window can measure itself.
        .fixedSize(horizontal: false, vertical: true)
        .glassSurface(radius: Theme.radiusPeek)
    }

    private var idle: some View {
        HStack(spacing: 8) {
            ChronoMarkView(isRunning: false, size: 14, color: Theme.inkSecondary)
            Text("Sin tareas en marcha")
                .font(Theme.peekRowFont)
                .foregroundColor(Theme.inkSecondary)
        }
        .padding(4)
    }

    private var totalLine: some View {
        HStack(spacing: 8) {
            Text("Σ \(rows.count) tareas")
                .font(Theme.subtitleFont)
                .foregroundColor(Theme.inkSecondary)
            Spacer(minLength: 8)
            Text(rows.reduce(0) { $0 + $1.elapsed }.timerFormatted)
                .font(Theme.peekTotalFont)
                .monospacedDigit()
                .foregroundColor(Theme.ink)
        }
        .padding(EdgeInsets(top: 7, leading: 4, bottom: 2, trailing: 4))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Theme.menuSeparator)
                .frame(height: Theme.strokeHairline)
        }
        .padding(.top, 5)
    }
}
