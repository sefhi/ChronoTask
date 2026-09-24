import SwiftUI

/// The line under the clock.
///
/// With one task or none it is today's total, "Hoy · 2h 10m". With several running
/// it becomes their sum, "Total · 01:02:03 en 3 tareas" — today's total then moves
/// out of the way rather than competing with it.
struct SummaryLine: View {
    enum Content: Equatable {
        /// `nil` until the figure has loaded from ClickUp. A dash is shown rather
        /// than `0m`, which would be a claim we cannot back.
        case today(TimeInterval?, isStale: Bool)
        case parallel(total: TimeInterval, count: Int)
    }

    let content: Content

    var body: some View {
        text
            .font(Theme.subtitleFont)
            .foregroundColor(Theme.inkSecondary)
            .opacity(isStale ? 0.6 : 1)
            .lineLimit(1)
    }

    private var text: Text {
        switch content {
        case .today(let total, _):
            return Text("Hoy · ") + figure(total?.todayFormatted ?? "—", muted: total == nil)
        case .parallel(let total, let count):
            return Text("Total · ") + figure(total.timerFormatted) + Text(" en \(count) tareas")
        }
    }

    private func figure(_ value: String, muted: Bool = false) -> Text {
        Text(value)
            .font(Theme.subtitleFigure)
            .foregroundColor(muted ? Theme.inkTertiary : Theme.ink)
    }

    private var isStale: Bool {
        if case .today(_, let stale) = content { return stale }
        return false
    }
}
