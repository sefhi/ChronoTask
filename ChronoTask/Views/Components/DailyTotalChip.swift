import SwiftUI

/// Fixed-width companion to the primary button, showing today's total.
///
/// Deliberately bare: no fill, no border. Dressed as a surface it read as a second
/// button sitting beside the real one, and there is nothing here to press. It keeps
/// its width so the primary button does not resize when the figure changes.
struct DailyTotalChip: View {
    let total: TimeInterval?

    var body: some View {
        Text(total?.todayFormatted ?? "—")
            .font(Theme.chipFont)
            .monospacedDigit()
            .foregroundColor(total == nil ? Theme.inkTertiary : Theme.ink)
            .frame(width: Theme.chipWidth, height: Theme.controlHeight)
            .accessibilityLabel("Tiempo registrado hoy")
            .accessibilityValue(total?.todayFormatted ?? "sin datos")
    }
}
