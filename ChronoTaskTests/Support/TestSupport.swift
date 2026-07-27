import Foundation
@testable import ChronoTask

enum TestSupport {

    /// A `UserDefaults` suite that cannot touch the developer's real preferences.
    /// Call `destroy()` in `tearDown`.
    final class Defaults {
        let suiteName: String
        let store: UserDefaults

        init() {
            suiteName = "chronotask.tests.\(UUID().uuidString)"
            store = UserDefaults(suiteName: suiteName)!
        }

        func destroy() {
            store.removePersistentDomain(forName: suiteName)
        }
    }

    static func makeTask(id: String = "t1",
                         name: String = "Tarea",
                         status: String? = nil,
                         statusType: String? = nil,
                         color: String? = nil) -> ClickUpTask {
        let clickUpStatus = status.map {
            ClickUpStatus(status: $0, color: color, type: statusType)
        }
        return ClickUpTask(id: id, name: name, status: clickUpStatus)
    }

    /// A time entry as the list endpoint returns it: epoch milliseconds as strings.
    static func makeEntry(id: String = "e1",
                          start: Date,
                          durationSeconds: Double,
                          userId: Int? = nil) -> ClickUpTimeEntry {
        ClickUpTimeEntry(
            id: id,
            start: String(start.millisecondsSince1970),
            duration: String(Int(durationSeconds * 1000)),
            user: userId.map { ClickUpTimeEntryUser(id: $0) }
        )
    }

    /// A running entry — ClickUp encodes these with a negative duration.
    static func makeRunningEntry(id: String = "running", start: Date) -> ClickUpTimeEntry {
        ClickUpTimeEntry(
            id: id,
            start: String(start.millisecondsSince1970),
            duration: "-1700000000000"
        )
    }

    static func makeSession(taskId: String = "t1",
                            taskName: String = "Tarea",
                            teamId: String = "team",
                            startedAt: Date,
                            savedAt: Date) -> PersistedSession {
        PersistedSession(taskId: taskId,
                         taskName: taskName,
                         teamId: teamId,
                         startedAt: startedAt,
                         savedAt: savedAt)
    }

    /// A fixed calendar so day-boundary tests do not depend on the machine's locale.
    static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    static func date(_ iso: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.date(from: iso)!
    }

    /// Polls until `condition` holds, returning whether it did before the timeout.
    ///
    /// The work being waited on runs on the concurrent executor with nothing to
    /// await from the main actor, so polling is the honest option — but the result
    /// must be asserted, or a timeout reads as success.
    static func waitUntil(timeout: TimeInterval = 3,
                          _ condition: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() >= deadline { return condition() }
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        return true
    }
}
