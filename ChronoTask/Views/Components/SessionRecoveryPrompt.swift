import SwiftUI

/// Shown when the app finds a session left behind by a previous run and cannot tell
/// how much of it was real work.
///
/// The gap between the last heartbeat and now is unaccounted for — the Mac may have
/// been asleep — so only the known stretch is ever offered.
struct SessionRecoveryPrompt: View {
    let taskName: String
    let knownDuration: TimeInterval
    let onAccept: () -> Void
    let onDiscard: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.accent)
                Text("SESIÓN SIN CERRAR")
                    .font(Theme.labelFont)
                    .tracking(Theme.trackingLabel)
                    .foregroundColor(Theme.accent)
            }

            Text(taskName)
                .font(Theme.captionFont)
                .foregroundColor(Theme.ink)
                .lineLimit(1)
                .truncationMode(.tail)

            Text("Se registraron \(knownDuration.todayFormatted) antes de que la app se cerrara.")
                .font(Theme.subtitleFont)
                .foregroundColor(Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Button(action: onAccept) {
                    Text("Registrar \(knownDuration.todayFormatted)")
                        .font(Theme.ctaFont)
                        .foregroundColor(Theme.onAccent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                }
                .buttonStyle(.chronoAccent)

                Button(action: onDiscard) {
                    Text("Descartar")
                        .font(Theme.ctaFont)
                        .foregroundColor(Theme.inkSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                }
                .buttonStyle(.chronoInset(radius: Theme.radiusControl))
            }
        }
        .padding(12)
        .insetSurface(radius: Theme.radiusSurface)
    }
}
