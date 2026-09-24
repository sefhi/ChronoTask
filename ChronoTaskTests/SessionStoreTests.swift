import XCTest
@testable import ChronoTask

final class SessionStoreTests: XCTestCase {

    private var defaults: TestSupport.Defaults!
    private var store: SessionStore!

    override func setUp() {
        super.setUp()
        defaults = TestSupport.Defaults()
        store = SessionStore(defaults: defaults.store, key: "session.test")
    }

    override func tearDown() {
        defaults.destroy()
        store = nil
        defaults = nil
        super.tearDown()
    }

    func testRoundTrip() {
        let session = TestSupport.makeSession(
            taskId: "abc",
            taskName: "Revisar propuesta",
            teamId: "team-9",
            startedAt: TestSupport.date("2026-07-27T09:00:00Z"),
            savedAt: TestSupport.date("2026-07-27T09:30:00Z")
        )
        store.save(session)

        let loaded = store.load()
        XCTAssertEqual(loaded?.taskId, "abc")
        XCTAssertEqual(loaded?.taskName, "Revisar propuesta")
        XCTAssertEqual(loaded?.teamId, "team-9")
        // Unwrapped first: XCTAssertEqual's `accuracy:` overload does not take optionals.
        XCTAssertEqual(loaded?.startedAt.timeIntervalSince1970 ?? 0,
                       session.startedAt.timeIntervalSince1970, accuracy: 1)
    }

    func testLoadWithNothingStoredReturnsNil() {
        XCTAssertNil(store.load())
    }

    /// A corrupt blob must never stop the app from launching.
    func testCorruptPayloadReturnsNilInsteadOfThrowing() {
        defaults.store.set(Data("not json".utf8), forKey: "session.test")
        XCTAssertNil(store.load())
    }

    func testClearRemovesTheSession() {
        store.save(TestSupport.makeSession(startedAt: Date(), savedAt: Date()))
        store.clear()
        XCTAssertNil(store.load())
    }

    func testSavingTwiceKeepsTheLatest() {
        let first = TestSupport.makeSession(taskId: "one",
                                            startedAt: TestSupport.date("2026-07-27T09:00:00Z"),
                                            savedAt: TestSupport.date("2026-07-27T09:05:00Z"))
        let second = TestSupport.makeSession(taskId: "two",
                                             startedAt: TestSupport.date("2026-07-27T10:00:00Z"),
                                             savedAt: TestSupport.date("2026-07-27T10:05:00Z"))
        store.save(first)
        store.save(second)

        XCTAssertEqual(store.load()?.taskId, "two")
    }

    func testSeveralSessionsRoundTripInOrder() {
        let start = TestSupport.date("2026-07-27T09:00:00Z")
        store.saveAll([
            TestSupport.makeSession(taskId: "a", startedAt: start, savedAt: start),
            TestSupport.makeSession(taskId: "b", startedAt: start, savedAt: start)
        ])

        XCTAssertEqual(store.loadAll().map(\.taskId), ["a", "b"])
    }

    func testSavingAnEmptyListClears() {
        store.save(TestSupport.makeSession(startedAt: Date(), savedAt: Date()))
        store.saveAll([])
        XCTAssertNil(defaults.store.data(forKey: "session.test"))
    }

    /// Builds before multitasking stored one bare object. A session running across
    /// the upgrade must still be found.
    func testReadsTheSingleSessionFormatOfEarlierBuilds() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let legacy = TestSupport.makeSession(taskId: "old",
                                             startedAt: TestSupport.date("2026-07-27T09:00:00Z"),
                                             savedAt: TestSupport.date("2026-07-27T09:05:00Z"))
        defaults.store.set(try encoder.encode(legacy), forKey: "session.test")

        XCTAssertEqual(store.loadAll().map(\.taskId), ["old"])
    }
}
