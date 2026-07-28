import Foundation

/// The "Actualizado hace X min" line under the task list.
///
/// Pure so the wording can be tested without a view: the interesting cases are the
/// boundaries and, above all, "never loaded" — which must not claim a freshness the
/// app cannot back, the same rule the daily total follows.
enum SyncLabel {

    static let syncing = "Sincronizando con ClickUp…"
    static let justNow = "Actualizado hace un momento"

    /// `nil` means draw nothing: there is no honest thing to say yet.
    static func text(lastLoaded: Date?, now: Date, isSyncing: Bool) -> String? {
        if isSyncing { return syncing }
        guard let lastLoaded else { return nil }

        let seconds = now.timeIntervalSince(lastLoaded)
        // A clock that jumped backwards would otherwise render "hace -3 min".
        guard seconds >= 60 else { return justNow }

        let minutes = Int(seconds / 60)
        guard minutes >= 60 else { return "Actualizado hace \(minutes) min" }

        // The prototype only ever counts minutes, but its list refreshes on a 5 min
        // TTL. If the network is down that grows unbounded, and "hace 143 min" is a
        // number nobody reads as time.
        let hours = minutes / 60
        let remainder = minutes % 60
        return remainder == 0
            ? "Actualizado hace \(hours) h"
            : "Actualizado hace \(hours) h \(remainder) min"
    }
}
