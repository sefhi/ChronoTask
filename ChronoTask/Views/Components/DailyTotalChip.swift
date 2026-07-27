import SwiftUI

/// Fixed-width companion to the primary button, showing today's total.
///
/// This is the *legible* copy of the figure: sitting on an inset surface it keeps its
/// contrast over any desktop, unlike the subtitle line above the task caption.
struct DailyTotalChip: View {
    let total: TimeInterval?

    var body: some View {
        Text(total?.todayFormatted ?? "—")
            .font(Theme.chipFont)
            .monospacedDigit()
            .foregroundColor(total == nil ? Theme.inkTertiary : Theme.ink)
            .frame(width: Theme.chipWidth, height: Theme.controlHeight)
            .insetSurface(radius: Theme.radiusSurface)
            .accessibilityLabel("Tiempo registrado hoy")
            .accessibilityValue(total?.todayFormatted ?? "sin datos")
    }
}
