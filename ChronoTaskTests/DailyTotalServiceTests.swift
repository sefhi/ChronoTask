import XCTest
@testable import ChronoTask

@MainActor
final class DailyTotalServiceTests: XCTestCase {

    private var api: MockClickUpAPI!
    private var service: DailyTotalService!
    private var clock: Date!

    override func setUp() async throws {
        try await super.setUp()
        api = MockClickUpAPI()
        clock = TestSupport.date("2026-07-27T12:00:00Z")
        service = makeService()
        service.configure(teamId: "team", userId: 7)
    }

    override func tearDown() async throws {
        service = nil
        api = nil
        try await super.tearDown()
    }

    private func makeService(minimumRefreshInterval: TimeInterval = 30) -> DailyTotalService {
        DailyTotalService(api: api,
                          calendar: TestSupport.utcCalendar,
                          now: { [weak self] in self?.clock ?? Date() },
                          minimumRefreshInterval: minimumRefreshInterval)
    }

    func testFirstLoadSumsTodaysEntries() async {
        api.timeEntries = [
            TestSupport.makeEntry(start: TestSupport.date("2026-07-27T09:00:00Z"), durationSeconds: 3600, userId: 7)
        ]

        await service.refresh(force: true)

        XCTAssertEqual(service.syncedSeconds ?? 0, 3600, accuracy: 0.001)
        XCTAssertFalse(service.isStale)
    }

    func testRequestsTheWholeDayAndOmitsTheAssigneeFilter() async {
        await service.refresh(force: true)

        let range = api.lastTimeEntriesRange
        XCTAssertEqual(range?.start, TestSupport.date("2026-07-27T00:00:00Z"))
        XCTAssertEqual(range?.end, TestSupport.date("2026-07-28T00:00:00Z"))
        // Owner/Admin-only parameter: sending it 400s for a regular member.
        XCTAssertNil(range?.assignee)
    }

    /// A stale figure beats a blank one.
    func testFailureKeepsThePreviousValue() async {
        api.timeEntries = [
            TestSupport.makeEntry(start: TestSupport.date("2026-07-27T09:00:00Z"), durationSeconds: 1200)
        ]
        await service.refresh(force: true)

        api.timeEntriesError = APIError.networkError("sin red")
        await service.refresh(force: true)

        XCTAssertEqual(service.syncedSeconds ?? 0, 1200, accuracy: 0.001)
        XCTAssertTrue(service.isStale)
        XCTAssertNotNil(service.lastError)
    }

    /// Showing `0h 0m` when nothing ever loaded would be a claim we cannot back.
    func testFailureWithNoPreviousValueLeavesItUnknown() async {
        api.timeEntriesError = APIError.networkError("sin red")

        await service.refresh(force: true)

        XCTAssertNil(service.syncedSeconds)
    }

    func testThrottleSuppressesRapidRefreshes() async {
        await service.refresh(force: true)
        await service.refresh()

        XCTAssertEqual(api.getTimeEntriesCallCount, 1)
    }

    func testThrottleExpiresWithTime() async {
        await service.refresh(force: true)
        clock = clock.addingTimeInterval(31)
        await service.refresh()

        XCTAssertEqual(api.getTimeEntriesCallCount, 2)
    }

    func testOptimisticCreditShowsImmediately() async {
        api.timeEntries = []
        await service.refresh(force: true)

        service.applyOptimistic(seconds: 900)

        XCTAssertEqual(service.syncedSeconds ?? 0, 900, accuracy: 0.001)
    }

    // MARK: - Display total

    func testDisplayTotalAddsTheRunningSession() async {
        api.timeEntries = [
            TestSupport.makeEntry(start: TestSupport.date("2026-07-27T09:00:00Z"), durationSeconds: 600)
        ]
        await service.refresh(force: true)

        let total = service.displayTotal(runningSince: TestSupport.date("2026-07-27T11:00:00Z"),
                                         elapsed: 300)

        XCTAssertEqual(total ?? 0, 900, accuracy: 0.001)
    }

    func testDisplayTotalIgnoresASessionStartedYesterday() async {
        api.timeEntries = [
            TestSupport.makeEntry(start: TestSupport.date("2026-07-27T09:00:00Z"), durationSeconds: 600)
        ]
        await service.refresh(force: true)

        let total = service.displayTotal(runningSince: TestSupport.date("2026-07-26T23:50:00Z"),
                                         elapsed: 3000)

        XCTAssertEqual(total ?? 0, 600, accuracy: 0.001)
    }

    func testDisplayTotalIsUnknownBeforeTheFirstLoad() {
        XCTAssertNil(service.displayTotal(runningSince: nil, elapsed: 0))
    }

    // MARK: - Midnight

    func testDayRolloverResetsTheTotal() async {
        api.timeEntries = [
            TestSupport.makeEntry(start: TestSupport.date("2026-07-27T09:00:00Z"), durationSeconds: 3600)
        ]
        await service.refresh(force: true)
        XCTAssertEqual(service.syncedSeconds ?? 0, 3600, accuracy: 0.001)

        clock = TestSupport.date("2026-07-28T00:30:00Z")
        api.timeEntries = []
        service.rolloverIfNeeded()

        XCTAssertEqual(service.day, TestSupport.date("2026-07-28T00:00:00Z"))
    }

    func testRolloverIsANoOpWithinTheSameDay() async {
        await service.refresh(force: true)
        let before = service.day

        clock = clock.addingTimeInterval(3600)
        service.rolloverIfNeeded()

        XCTAssertEqual(service.day, before)
    }
}
