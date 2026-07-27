import XCTest
@testable import ChronoTask

/// `@MainActor` because `TimerManager` is now isolated to it — the timer drives UI
/// state. The test bodies themselves are unchanged.
@MainActor
final class TimerManagerTests: XCTestCase {
    var timerManager: TimerManager!
    private var defaults: TestSupport.Defaults!
    private var api: MockClickUpAPI!

    // The `async` variants of setUp/tearDown are what inherit the class's actor
    // isolation; the synchronous overrides stay nonisolated and cannot touch
    // main-actor state.
    override func setUp() async throws {
        try await super.setUp()
        // Injected so the suite neither reaches the network nor writes to the
        // developer's real UserDefaults.
        defaults = TestSupport.Defaults()
        api = MockClickUpAPI()
        timerManager = TimerManager(
            api: api,
            sessionStore: SessionStore(defaults: defaults.store, key: "legacy.session")
        )
        timerManager.configure(teamId: "test-team")
    }

    override func tearDown() async throws {
        defaults.destroy()
        timerManager = nil
        api = nil
        defaults = nil
        try await super.tearDown()
    }

    // MARK: - State Transitions

    func testInitialState() {
        XCTAssertEqual(timerManager.state, .idle)
        XCTAssertEqual(timerManager.elapsed, 0)
        XCTAssertFalse(timerManager.isRunning)
        XCTAssertFalse(timerManager.isSyncing)
        XCTAssertNil(timerManager.syncError)
    }

    func testStartTransitionsToRunning() {
        let task = makeTask(id: "t1", name: "Test")
        timerManager.start(task: task)

        XCTAssertEqual(timerManager.state, .running)
        XCTAssertTrue(timerManager.isRunning)
    }

    func testStartIgnoredWhenNotIdle() {
        let task1 = makeTask(id: "t1", name: "Task 1")
        let task2 = makeTask(id: "t2", name: "Task 2")

        timerManager.start(task: task1)
        XCTAssertEqual(timerManager.state, .running)

        // Should not restart
        timerManager.start(task: task2)
        XCTAssertEqual(timerManager.state, .running)
    }

    func testStopTransitionsToSyncing() {
        let task = makeTask(id: "t1", name: "Test")
        timerManager.start(task: task)
        timerManager.stop()

        XCTAssertEqual(timerManager.state, .syncing)
    }

    func testStopIgnoredWhenNotRunning() {
        // Should be no-op when idle
        timerManager.stop()
        XCTAssertEqual(timerManager.state, .idle)
    }

    func testStartClearsSyncError() {
        let task = makeTask(id: "t1", name: "Test")
        timerManager.start(task: task)
        XCTAssertNil(timerManager.syncError)
    }

    func testRecalculateElapsedWhenRunning() {
        let task = makeTask(id: "t1", name: "Test")
        timerManager.start(task: task)

        // Recalculate should update elapsed
        timerManager.recalculateElapsed()
        XCTAssertGreaterThanOrEqual(timerManager.elapsed, 0)
    }

    func testRecalculateElapsedWhenNotRunning() {
        let initialElapsed = timerManager.elapsed
        timerManager.recalculateElapsed()
        XCTAssertEqual(timerManager.elapsed, initialElapsed)
    }

    // MARK: - Helpers

    private func makeTask(id: String, name: String) -> ClickUpTask {
        ClickUpTask(
            id: id,
            name: name,
            status: nil,
            list: nil,
            folder: nil,
            url: nil
        )
    }
}
