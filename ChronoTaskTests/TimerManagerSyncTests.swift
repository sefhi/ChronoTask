import XCTest
@testable import ChronoTask

/// Covers what the original suite could not: the sync side of stopping, which was
/// unreachable while `TimerManager` hard-coded `ClickUpAPI.shared`.
@MainActor
final class TimerManagerSyncTests: XCTestCase {

    private var defaults: TestSupport.Defaults!
    private var api: MockClickUpAPI!
    private var sessionStore: SessionStore!
    private var queue: PendingEntryQueue!
    private var timer: TimerManager!

    override func setUp() async throws {
        try await super.setUp()
        defaults = TestSupport.Defaults()
        api = MockClickUpAPI()
        sessionStore = SessionStore(defaults: defaults.store, key: "sync.session")
        queue = PendingEntryQueue(api: api, defaults: defaults.store, key: "sync.pending")
        timer = TimerManager(api: api, sessionStore: sessionStore, pendingQueue: queue)
        timer.configure(teamId: "team-1")
    }

    override func tearDown() async throws {
        defaults.destroy()
        timer = nil
        queue = nil
        sessionStore = nil
        api = nil
        defaults = nil
        try await super.tearDown()
    }

    func testStopSendsTheEntryWithTheRightFields() async {
        let task = TestSupport.makeTask(id: "task-7", name: "Deploy")
        timer.start(task: task)

        let outcome = await timer.stopAndSync()

        XCTAssertEqual(api.createdEntries.count, 1)
        XCTAssertEqual(api.createdEntries.first?.teamId, "team-1")
        XCTAssertEqual(api.createdEntries.first?.taskId, "task-7")
        if case .synced = outcome {} else {
            XCTFail("Expected a synced outcome, got \(outcome)")
        }
        XCTAssertEqual(timer.state, .idle)
        XCTAssertEqual(timer.elapsed, 0)
    }

    /// The time is safe on disk, so it is no longer an error the user must act on.
    func testFailedSyncQueuesTheEntryAndClearsTheTimer() async {
        api.createError = APIError.networkError("sin red")
        timer.start(task: TestSupport.makeTask())

        let outcome = await timer.stopAndSync()

        if case .queued = outcome {} else {
            XCTFail("Expected a queued outcome, got \(outcome)")
        }
        XCTAssertEqual(queue.entries.count, 1)
        XCTAssertEqual(timer.elapsed, 0)
        XCTAssertEqual(timer.state, .idle)
    }

    /// `stop()` must land on `.syncing` before returning — the original tests assert
    /// this synchronously.
    func testStopIsSynchronouslyObservableAsSyncing() {
        timer.start(task: TestSupport.makeTask())
        timer.stop()
        XCTAssertEqual(timer.state, .syncing)
    }

    /// The old implementation guessed with a fixed 0.5s delay and could start the new
    /// timer while the POST was still in flight, silently dropping the new session.
    func testSwitchTaskWaitsForTheUploadBeforeStartingTheNextOne() async {
        api.blockCreate = true
        timer.start(task: TestSupport.makeTask(id: "first", name: "Primera"))

        timer.switchTask(to: TestSupport.makeTask(id: "second", name: "Segunda"))

        // While the upload is blocked, the new task must not be running yet.
        await Task.yield()
        XCTAssertNotEqual(timer.currentTask?.id, "second",
                          "The next task started before the previous entry was sent")

        api.releaseCreate()

        // Give the continuation a chance to complete the switch.
        for _ in 0..<50 where timer.currentTask?.id != "second" {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }

        XCTAssertEqual(timer.currentTask?.id, "second")
        XCTAssertEqual(timer.state, .running)
        XCTAssertEqual(api.createdEntries.first?.taskId, "first")
    }

    // MARK: - Session persistence

    func testStartPersistsTheSession() {
        timer.start(task: TestSupport.makeTask(id: "t9", name: "Escribir"))

        let saved = sessionStore.load()
        XCTAssertEqual(saved?.taskId, "t9")
        XCTAssertEqual(saved?.teamId, "team-1")
    }

    func testStopClearsThePersistedSession() async {
        timer.start(task: TestSupport.makeTask())
        await timer.stopAndSync()

        XCTAssertNil(sessionStore.load())
    }

    func testRestoreResumesARecentSession() {
        let now = Date()
        sessionStore.save(TestSupport.makeSession(
            taskId: "restored",
            taskName: "Recuperada",
            teamId: "team-1",
            startedAt: now.addingTimeInterval(-1800),
            savedAt: now.addingTimeInterval(-10)
        ))

        timer.restoreSession()

        XCTAssertEqual(timer.state, .running)
        XCTAssertEqual(timer.currentTask?.id, "restored")
        XCTAssertGreaterThan(timer.elapsed, 1700)
    }

    func testRestoreOffersALongGapInsteadOfResuming() {
        let now = Date()
        sessionStore.save(TestSupport.makeSession(
            startedAt: now.addingTimeInterval(-7200),
            savedAt: now.addingTimeInterval(-5400)
        ))

        timer.restoreSession()

        XCTAssertEqual(timer.state, .idle)
        XCTAssertNotNil(timer.pendingRecovery)
        XCTAssertEqual(timer.pendingRecovery?.knownDuration ?? 0, 1800, accuracy: 1)
    }

    func testAcceptingRecoveryLogsOnlyTheKnownStretch() async {
        let now = Date()
        sessionStore.save(TestSupport.makeSession(
            startedAt: now.addingTimeInterval(-7200),
            savedAt: now.addingTimeInterval(-5400)
        ))
        timer.restoreSession()

        timer.acceptRecovery()

        for _ in 0..<50 where api.createdEntries.isEmpty {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }

        XCTAssertEqual(api.createdEntries.count, 1)
        XCTAssertEqual(api.createdEntries.first?.duration ?? 0, 1800, accuracy: 1)
        XCTAssertNil(timer.pendingRecovery)
        XCTAssertNil(sessionStore.load())
    }

    func testDiscardingRecoveryLogsNothing() {
        let now = Date()
        sessionStore.save(TestSupport.makeSession(
            startedAt: now.addingTimeInterval(-7200),
            savedAt: now.addingTimeInterval(-5400)
        ))
        timer.restoreSession()

        timer.discardRecovery()

        XCTAssertTrue(api.createdEntries.isEmpty)
        XCTAssertNil(sessionStore.load())
    }

    func testStaleSessionIsDroppedWithoutPrompting() {
        let now = Date()
        sessionStore.save(TestSupport.makeSession(
            startedAt: now.addingTimeInterval(-14 * 3600),
            savedAt: now.addingTimeInterval(-13 * 3600)
        ))

        timer.restoreSession()

        XCTAssertEqual(timer.state, .idle)
        XCTAssertNil(timer.pendingRecovery)
        XCTAssertNil(sessionStore.load())
    }
}
