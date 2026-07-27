import SwiftUI

/// "Hoy · 2h 10m registrados".
///
/// `total` is `nil` until the figure has loaded from ClickUp. A dash is shown rather
/// than `0m`, which would be a claim we cannot back.
struct TodaySummaryLine: View {
    let total: TimeInterval?
    var isStale: Bool = false

    var body: some View {
        Text(text)
            .font(Theme.subtitleFont)
            .foregroundColor(total == nil ? Theme.inkTertiary : Theme.inkSecondary)
            .opacity(isStale ? 0.6 : 1)
            .lineLimit(1)
    }

    private var text: String {
        guard let total else { return "Hoy · — registrados" }
        return "Hoy · \(total.todayFormatted) registrados"
    }
}
