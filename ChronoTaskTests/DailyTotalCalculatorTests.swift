import XCTest
@testable import ChronoTask

final class DailyTotalCalculatorTests: XCTestCase {

    private let calendar = TestSupport.utcCalendar
    private lazy var day = TestSupport.date("2026-07-27T00:00:00Z")

    // MARK: - Summing

    func testSumsEntriesStartedOnTheDay() {
        let entries = [
            TestSupport.makeEntry(id: "a", start: TestSupport.date("2026-07-27T09:00:00Z"), durationSeconds: 3600),
            TestSupport.makeEntry(id: "b", start: TestSupport.date("2026-07-27T14:30:00Z"), durationSeconds: 1800)
        ]
        let total = DailyTotalCalculator.total(from: entries, day: day, calendar: calendar)
        XCTAssertEqual(total, 5400, accuracy: 0.001)
    }

    func testEmptyListIsZero() {
        XCTAssertEqual(DailyTotalCalculator.total(from: [], day: day, calendar: calendar), 0)
    }

    /// The important one: ClickUp marks a running timer with a negative duration, and
    /// counting it yields absurd totals (~1.7e12 seconds).
    func testExcludesRunningEntries() {
        let entries = [
            TestSupport.makeEntry(id: "a", start: TestSupport.date("2026-07-27T09:00:00Z"), durationSeconds: 600),
            TestSupport.makeRunningEntry(start: TestSupport.date("2026-07-27T10:00:00Z"))
        ]
        let total = DailyTotalCalculator.total(from: entries, day: day, calendar: calendar)
        XCTAssertEqual(total, 600, accuracy: 0.001)
    }

    func testExcludesEntriesFromOtherDays() {
        let entries = [
            TestSupport.makeEntry(id: "yesterday", start: TestSupport.date("2026-07-26T23:59:00Z"), durationSeconds: 600),
            TestSupport.makeEntry(id: "today", start: TestSupport.date("2026-07-27T00:01:00Z"), durationSeconds: 300),
            TestSupport.makeEntry(id: "tomorrow", start: TestSupport.date("2026-07-28T00:01:00Z"), durationSeconds: 900)
        ]
        let total = DailyTotalCalculator.total(from: entries, day: day, calendar: calendar)
        XCTAssertEqual(total, 300, accuracy: 0.001)
    }

    /// The list endpoint's `assignee` filter is Owner/Admin-only, so the client has to
    /// filter defensively.
    func testExcludesOtherUsersEntries() {
        let entries = [
            TestSupport.makeEntry(id: "mine", start: TestSupport.date("2026-07-27T09:00:00Z"), durationSeconds: 600, userId: 42),
            TestSupport.makeEntry(id: "theirs", start: TestSupport.date("2026-07-27T10:00:00Z"), durationSeconds: 600, userId: 99)
        ]
        let total = DailyTotalCalculator.total(from: entries, day: day, calendar: calendar, userId: 42)
        XCTAssertEqual(total, 600, accuracy: 0.001)
    }

    func testEntriesWithoutUserAreKept() {
        let entries = [
            TestSupport.makeEntry(id: "anon", start: TestSupport.date("2026-07-27T09:00:00Z"), durationSeconds: 600)
        ]
        let total = DailyTotalCalculator.total(from: entries, day: day, calendar: calendar, userId: 42)
        XCTAssertEqual(total, 600, accuracy: 0.001)
    }

    // MARK: - Day bounds

    func testDayBoundsSpanExactlyOneDay() {
        let bounds = DailyTotalCalculator.dayBounds(for: TestSupport.date("2026-07-27T15:20:00Z"),
                                                   calendar: calendar)
        XCTAssertEqual(bounds.start, TestSupport.date("2026-07-27T00:00:00Z"))
        XCTAssertEqual(bounds.end, TestSupport.date("2026-07-28T00:00:00Z"))
    }

    /// Derived through `Calendar`, so a 23-hour spring-forward day stays correct.
    func testDayBoundsHandleDaylightSavingTransition() {
        var madrid = Calendar(identifier: .gregorian)
        madrid.timeZone = TimeZone(identifier: "Europe/Madrid")!

        let duringDST = TestSupport.date("2026-03-29T12:00:00Z")
        let bounds = DailyTotalCalculator.dayBounds(for: duringDST, calendar: madrid)
        let length = bounds.end.timeIntervalSince(bounds.start)

        XCTAssertEqual(length, 23 * 3600, accuracy: 1,
                       "The spring-forward day is 23 hours long")
    }

    // MARK: - Running session

    func testRunningSessionCountsWhenStartedToday() {
        let contribution = DailyTotalCalculator.runningContribution(
            startedAt: TestSupport.date("2026-07-27T08:00:00Z"),
            elapsed: 1200,
            day: day,
            calendar: calendar
        )
        XCTAssertEqual(contribution, 1200, accuracy: 0.001)
    }

    /// A session that began yesterday is filed against yesterday, exactly as ClickUp
    /// will file it — so today's figure does not drop when the entry syncs.
    func testRunningSessionStartedYesterdayContributesNothing() {
        let contribution = DailyTotalCalculator.runningContribution(
            startedAt: TestSupport.date("2026-07-26T23:50:00Z"),
            elapsed: 2400,
            day: day,
            calendar: calendar
        )
        XCTAssertEqual(contribution, 0)
    }

    func testNegativeElapsedIsClampedToZero() {
        let contribution = DailyTotalCalculator.runningContribution(
            startedAt: TestSupport.date("2026-07-27T08:00:00Z"),
            elapsed: -50,
            day: day,
            calendar: calendar
        )
        XCTAssertEqual(contribution, 0)
    }
}
