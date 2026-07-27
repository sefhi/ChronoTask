import Foundation

/// Turns ClickUp time entries into "how much did I log today".
///
/// Kept free of networking and of `Date()` so every rule below is directly testable.
enum DailyTotalCalculator {

    /// Half-open day boundaries, `[startOfDay, startOfNextDay)`.
    ///
    /// Derived through `Calendar` rather than by adding 86 400 seconds so DST
    /// transitions (23- and 25-hour days) stay correct.
    static func dayBounds(for date: Date, calendar: Calendar = .current) -> (start: Date, end: Date) {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        return (start, end)
    }

    /// Sum of the entries that belong to `day`.
    ///
    /// Drops running timers (ClickUp encodes them as a negative duration), entries
    /// that started on another day, and — when `userId` is given — entries belonging
    /// to somebody else.
    static func total(from entries: [ClickUpTimeEntry],
                      day: Date,
                      calendar: Calendar = .current,
                      userId: Int? = nil) -> TimeInterval {
        let bounds = dayBounds(for: day, calendar: calendar)

        return entries.reduce(into: TimeInterval(0)) { sum, entry in
            guard !entry.isRunning else { return }
            guard let start = entry.startDate, start >= bounds.start, start < bounds.end else { return }
            if let userId, let entryUser = entry.user?.id, entryUser != userId { return }
            sum += entry.trackedSeconds
        }
    }

    /// What the in-flight session contributes to `day`'s total.
    ///
    /// A session is credited to the day it *started*, matching how ClickUp will file
    /// it on sync. Crossing midnight therefore leaves the day total untouched rather
    /// than having it drop when the entry is finally posted to the previous day.
    static func runningContribution(startedAt: Date,
                                    elapsed: TimeInterval,
                                    day: Date,
                                    calendar: Calendar = .current) -> TimeInterval {
        calendar.isDate(startedAt, inSameDayAs: day) ? max(0, elapsed) : 0
    }
}
