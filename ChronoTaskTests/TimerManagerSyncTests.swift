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

        let outcome = await timer.stopAll()

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

        let outcome = await timer.stopAll()

        if case .queued = outcome {} else {
            XCTFail("Expected a queued outcome, got \(outcome)")
        }
        XCTAssertEqual(queue.entries.count, 1)
        XCTAssertEqual(timer.elapsed, 0)
        XCTAssertEqual(timer.state, .idle)
    }

    /// With nothing left running, the status item shows the sync glyph until the
    /// last upload lands.
    func testStateIsSyncingWhileTheLastUploadIsInFlight() async {
        api.blockCreate = true
        timer.start(task: TestSupport.makeTask())

        let stopping = Task { await timer.stopAll() }
        let parked = await TestSupport.waitUntil { self.api.waitingCreateCount == 1 }
        XCTAssertTrue(parked, "the upload never reached the blocking point")

        XCTAssertEqual(timer.state, .syncing)
        XCTAssertTrue(timer.runs.isEmpty)

        api.releaseCreate()
        _ = await stopping.value
        XCTAssertEqual(timer.state, .idle)
    }

    /// Stopping must not hold anything else up: a new task can start while the
    /// previous entry is still on its way.
    func testANewTaskCanStartWhileAnUploadIsInFlight() async {
        api.blockCreate = true
        timer.start(task: TestSupport.makeTask(id: "first", name: "Primera"))

        let stopping = Task { await timer.stopAll() }
        let parked = await TestSupport.waitUntil { self.api.waitingCreateCount == 1 }
        XCTAssertTrue(parked, "the upload never reached the blocking point")

        timer.start(task: TestSupport.makeTask(id: "second", name: "Segunda"))
        XCTAssertEqual(timer.state, .running)
        XCTAssertEqual(timer.focusedRun?.id, "second")

        api.releaseCreate()
        _ = await stopping.value
        XCTAssertEqual(timer.state, .running)
        XCTAssertEqual(api.createdEntries.map(\.taskId), ["first"])
    }

    // MARK: - Parallel runs

    func testStoppingOneRunLeavesTheOthersRunning() async {
        timer.start(task: TestSupport.makeTask(id: "a", name: "A"))
        timer.start(task: TestSupport.makeTask(id: "b", name: "B"))
        timer.start(task: TestSupport.makeTask(id: "c", name: "C"))

        let outcome = await timer.stop(taskId: "b")

        if case .synced = outcome {} else { XCTFail("Expected synced, got \(outcome)") }
        XCTAssertEqual(api.createdEntries.map(\.taskId), ["b"])
        XCTAssertEqual(timer.runs.map(\.id), ["a", "c"])
        XCTAssertEqual(timer.state, .running)
        XCTAssertEqual(timer.focusedRun?.id, "c")
    }

    /// Stopping the focused run hands the focus to the oldest one left.
    func testStoppingTheFocusedRunMovesFocusToTheOldest() async {
        timer.start(task: TestSupport.makeTask(id: "a", name: "A"))
        timer.start(task: TestSupport.makeTask(id: "b", name: "B"))

        await timer.stop(taskId: "b")

        XCTAssertEqual(timer.focusedRun?.id, "a")
    }

    func testStopAllSendsOneEntryPerRun() async {
        timer.start(task: TestSupport.makeTask(id: "a", name: "A"))
        timer.start(task: TestSupport.makeTask(id: "b", name: "B"))

        let outcome = await timer.stopAll()

        if case .synced = outcome {} else { XCTFail("Expected synced, got \(outcome)") }
        XCTAssertEqual(Set(api.createdEntries.map(\.taskId)), ["a", "b"])
        XCTAssertTrue(timer.runs.isEmpty)
        XCTAssertEqual(timer.state, .idle)
        XCTAssertNil(sessionStore.load())
    }

    func testKeepOnlyStopsEverythingElseAndFocusesTheSurvivor() async {
        timer.start(task: TestSupport.makeTask(id: "a", name: "A"))
        timer.start(task: TestSupport.makeTask(id: "b", name: "B"))
        timer.start(task: TestSupport.makeTask(id: "c", name: "C"))

        await timer.keepOnly(taskId: "a")

        XCTAssertEqual(timer.runs.map(\.id), ["a"])
        XCTAssertEqual(timer.focusedRun?.id, "a")
        XCTAssertEqual(Set(api.createdEntries.map(\.taskId)), ["b", "c"])
        XCTAssertEqual(sessionStore.loadAll().map(\.taskId), ["a"])
    }

    /// Two quick clicks on the same stop button must not post the entry twice.
    func testStoppingTheSameRunTwiceSendsOneEntry() async {
        api.blockCreate = true
        timer.start(task: TestSupport.makeTask(id: "a", name: "A"))

        let first = Task { await timer.stop(taskId: "a") }
        let parked = await TestSupport.waitUntil { self.api.waitingCreateCount == 1 }
        XCTAssertTrue(parked, "the upload never reached the blocking point")
        let second = await timer.stop(taskId: "a")

        api.releaseCreate()
        _ = await first.value
        XCTAssertEqual(second, .noop)
        XCTAssertEqual(api.createdEntries.count, 1)
    }

    /// One failure is enough for the combined outcome to say "queued".
    func testStopAllReportsQueuedWhenAnyUploadFails() async {
        api.createError = APIError.networkError("sin red")
        timer.start(task: TestSupport.makeTask(id: "a", name: "A"))
        timer.start(task: TestSupport.makeTask(id: "b", name: "B"))

        let outcome = await timer.stopAll()

        if case .queued = outcome {} else { XCTFail("Expected queued, got \(outcome)") }
        XCTAssertEqual(queue.entries.count, 2)
    }

    func testCombinedOutcome() {
        XCTAssertEqual(StopOutcome.combined([]), .noop)
        XCTAssertEqual(StopOutcome.combined([.synced(duration: 60), .synced(duration: 30)]),
                       .synced(duration: 90))
        XCTAssertEqual(StopOutcome.combined([.synced(duration: 60), .queued(duration: 30)]),
                       .queued(duration: 90))
        XCTAssertEqual(StopOutcome.combined([.noop, .synced(duration: 10)]),
                       .synced(duration: 10))
    }

    // MARK: - Session persistence

    func testStartPersistsTheSession() {
        timer.start(task: TestSupport.makeTask(id: "t9", name: "Escribir"))

        let saved = sessionStore.load()
        XCTAssertEqual(saved?.taskId, "t9")
        XCTAssertEqual(saved?.teamId, "team-1")
    }

    func testEveryParallelRunIsPersisted() {
        timer.start(task: TestSupport.makeTask(id: "a", name: "A"))
        timer.start(task: TestSupport.makeTask(id: "b", name: "B"))

        XCTAssertEqual(sessionStore.loadAll().map(\.taskId), ["a", "b"])
    }

    func testStopClearsThePersistedSession() async {
        timer.start(task: TestSupport.makeTask())
        await timer.stopAll()

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
        XCTAssertEqual(timer.focusedRun?.id, "restored")
        XCTAssertGreaterThan(timer.elapsed, 1700)
    }

    func testRestoreResumesEveryRecentParallelSession() {
        let now = Date()
        sessionStore.saveAll([
            TestSupport.makeSession(taskId: "a", teamId: "team-1",
                                    startedAt: now.addingTimeInterval(-1800),
                                    savedAt: now.addingTimeInterval(-10)),
            TestSupport.makeSession(taskId: "b", teamId: "team-1",
                                    startedAt: now.addingTimeInterval(-600),
                                    savedAt: now.addingTimeInterval(-10))
        ])

        timer.restoreSession()

        XCTAssertEqual(timer.runs.map(\.id), ["a", "b"])
        XCTAssertEqual(timer.state, .running)
    }

    /// Parallel sessions that outlived a long gap are offered together, and
    /// accepting logs each one's known stretch as its own entry.
    func testParallelSessionsAfterALongGapAreOfferedTogether() async {
        let now = Date()
        sessionStore.saveAll([
            TestSupport.makeSession(taskId: "a", taskName: "A",
                                    startedAt: now.addingTimeInterval(-7200),
                                    savedAt: now.addingTimeInterval(-5400)),
            TestSupport.makeSession(taskId: "b", taskName: "B",
                                    startedAt: now.addingTimeInterval(-6600),
                                    savedAt: now.addingTimeInterval(-5400))
        ])

        timer.restoreSession()

        XCTAssertEqual(timer.pendingRecovery?.taskName, "2 tareas en paralelo")
        XCTAssertEqual(timer.pendingRecovery?.knownDuration ?? 0, 1800 + 1200, accuracy: 1)

        timer.acceptRecovery()
        let sent = await TestSupport.waitUntil { self.api.createdEntries.count == 2 }
        XCTAssertTrue(sent, "both recovered entries should be sent")
        XCTAssertEqual(Set(api.createdEntries.map(\.taskId)), ["a", "b"])
    }

    /// An unanswered prompt must survive another relaunch.
    func testUndecidedRecoveryStaysOnDisk() {
        let now = Date()
        sessionStore.save(TestSupport.makeSession(
            startedAt: now.addingTimeInterval(-7200),
            savedAt: now.addingTimeInterval(-5400)
        ))

        timer.restoreSession()

        XCTAssertNotNil(timer.pendingRecovery)
        XCTAssertNotNil(sessionStore.load())
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

        let sent = await TestSupport.waitUntil { !self.api.createdEntries.isEmpty }
        XCTAssertTrue(sent, "the recovered entry was never sent")

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
