import XCTest
@testable import ChronoTask

@MainActor
final class PendingEntryQueueTests: XCTestCase {

    private var defaults: TestSupport.Defaults!
    private var api: MockClickUpAPI!
    private var queue: PendingEntryQueue!

    override func setUp() async throws {
        try await super.setUp()
        defaults = TestSupport.Defaults()
        api = MockClickUpAPI()
        queue = PendingEntryQueue(api: api, defaults: defaults.store, key: "pending.test")
    }

    override func tearDown() async throws {
        defaults.destroy()
        queue = nil
        api = nil
        defaults = nil
        try await super.tearDown()
    }

    private func makeEntry(id: UUID = UUID(), attempts: Int = 0, lastAttemptAt: Date? = nil) -> PendingTimeEntry {
        PendingTimeEntry(id: id,
                         teamId: "team",
                         taskId: "task",
                         taskName: "Tarea",
                         startedAt: TestSupport.date("2026-07-27T09:00:00Z"),
                         duration: 600,
                         attempts: attempts,
                         lastAttemptAt: lastAttemptAt)
    }

    func testEnqueuePersistsAcrossInstances() {
        queue.enqueue(makeEntry())
        XCTAssertTrue(queue.hasPending)

        let reloaded = PendingEntryQueue(api: api, defaults: defaults.store, key: "pending.test")
        XCTAssertEqual(reloaded.entries.count, 1)
    }

    func testSuccessfulFlushEmptiesTheQueue() async {
        queue.enqueue(makeEntry())

        let synced = await queue.flush()

        XCTAssertEqual(synced, 1)
        XCTAssertFalse(queue.hasPending)
        XCTAssertEqual(api.createdEntries.count, 1)
        XCTAssertEqual(api.createdEntries.first?.duration, 600)
    }

    func testFailedFlushKeepsTheEntryAndCountsTheAttempt() async {
        api.createError = APIError.networkError("sin red")
        queue.enqueue(makeEntry())

        let synced = await queue.flush()

        XCTAssertEqual(synced, 0)
        XCTAssertEqual(queue.entries.count, 1)
        XCTAssertEqual(queue.entries.first?.attempts, 1)
        XCTAssertNotNil(queue.entries.first?.lastError)
    }

    /// An expired token will not fix itself by retrying, but the work is real and must
    /// not be thrown away.
    func testUnauthorizedKeepsTheEntry() async {
        api.createError = APIError.unauthorized
        queue.enqueue(makeEntry())

        _ = await queue.flush()

        XCTAssertEqual(queue.entries.count, 1)
    }

    func testQueueIsCappedAndDropsTheOldest() {
        let capped = PendingEntryQueue(api: api, defaults: defaults.store, key: "capped.test", maxEntries: 3)
        let ids = (0..<5).map { _ in UUID() }
        ids.forEach { capped.enqueue(makeEntry(id: $0)) }

        XCTAssertEqual(capped.entries.count, 3)
        XCTAssertEqual(capped.entries.map(\.id), Array(ids.suffix(3)))
    }

    func testRemoveDropsASingleEntry() {
        let id = UUID()
        queue.enqueue(makeEntry(id: id))
        queue.enqueue(makeEntry())

        queue.remove(id: id)

        XCTAssertEqual(queue.entries.count, 1)
        XCTAssertFalse(queue.entries.contains { $0.id == id })
    }

    // MARK: - Backoff

    func testNeverAttemptedEntryIsDueImmediately() {
        XCTAssertTrue(PendingEntryQueue.isDue(makeEntry(), now: Date()))
    }

    func testBackoffGrowsWithAttempts() {
        let now = TestSupport.date("2026-07-27T12:00:00Z")

        // After one failed attempt the wait is 60s.
        XCTAssertTrue(PendingEntryQueue.isDue(
            makeEntry(attempts: 1, lastAttemptAt: now.addingTimeInterval(-61)), now: now))
        XCTAssertFalse(PendingEntryQueue.isDue(
            makeEntry(attempts: 1, lastAttemptAt: now.addingTimeInterval(-30)), now: now))

        // After two, 120s.
        XCTAssertFalse(PendingEntryQueue.isDue(
            makeEntry(attempts: 2, lastAttemptAt: now.addingTimeInterval(-90)), now: now))
        XCTAssertTrue(PendingEntryQueue.isDue(
            makeEntry(attempts: 2, lastAttemptAt: now.addingTimeInterval(-121)), now: now))
    }

    func testBackoffIsCappedAtFiveMinutes() {
        let now = TestSupport.date("2026-07-27T12:00:00Z")
        let many = makeEntry(attempts: 20, lastAttemptAt: now.addingTimeInterval(-301))
        XCTAssertTrue(PendingEntryQueue.isDue(many, now: now))
    }
}
