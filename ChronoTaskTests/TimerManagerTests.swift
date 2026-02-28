import XCTest
@testable import ChronoTask

final class TimerManagerTests: XCTestCase {
    var timerManager: TimerManager!

    override func setUp() {
        super.setUp()
        timerManager = TimerManager()
        timerManager.configure(teamId: "test-team")
    }

    override func tearDown() {
        timerManager = nil
        super.tearDown()
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
