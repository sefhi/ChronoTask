import Foundation
@testable import ChronoTask

/// Programmable stand-in for `ClickUpAPI`.
///
/// The real client is a singleton reaching the network; this is the seam that makes
/// `TimerManager`, `TaskStore` and `DailyTotalService` testable at all.
///
/// This is a plain class, not an actor, so its `async` methods run on the concurrent
/// executor while the tests that drive it live on the main actor. Everything the two
/// sides share therefore goes through `lock`. That is not belt-and-braces: the
/// blocking hook below deadlocked outright when `releaseCreate()` drained the
/// continuation list a moment before `createTimeEntry` appended to it.
final class MockClickUpAPI: ClickUpAPIClient {
    var token: String = "mock-token"

    // Canned results. Set before the exercise phase and not mutated afterwards, so
    // these need no locking.
    var user: ClickUpUser?
    var teams: [ClickUpTeam] = []
    var tasks: [ClickUpTask] = []
    var timeEntries: [ClickUpTimeEntry] = []
    var createdEntry: ClickUpTimeEntry = ClickUpTimeEntry(id: "entry-1")

    // Canned failures
    var validateError: Error?
    var teamsError: Error?
    var tasksError: Error?
    var createError: Error?
    var timeEntriesError: Error?

    private let lock = NSLock()

    // Recorded calls — written from the API side, read from the test side.
    private var _createdEntries: [(teamId: String, taskId: String, start: Date, duration: TimeInterval)] = []
    private var _getTasksCallCount = 0
    private var _getTimeEntriesCallCount = 0
    private var _lastTimeEntriesRange: (start: Date, end: Date, assignee: Int?)?

    var createdEntries: [(teamId: String, taskId: String, start: Date, duration: TimeInterval)] {
        withLock { _createdEntries }
    }
    var getTasksCallCount: Int { withLock { _getTasksCallCount } }
    var getTimeEntriesCallCount: Int { withLock { _getTimeEntriesCallCount } }
    var lastTimeEntriesRange: (start: Date, end: Date, assignee: Int?)? {
        withLock { _lastTimeEntriesRange }
    }

    // Blocking hook: set `blockCreate` to hold `createTimeEntry` until
    // `releaseCreate()` is called, so tests can observe ordering rather than guess
    // with sleeps.
    private var _blockCreate = false
    private var createContinuations: [CheckedContinuation<Void, Never>] = []

    var blockCreate: Bool {
        get { withLock { _blockCreate } }
        set { withLock { _blockCreate = newValue } }
    }

    /// How many calls are parked right now. Tests wait on this before releasing, so
    /// that they are provably observing the ordering rather than racing past it.
    var waitingCreateCount: Int { withLock { createContinuations.count } }

    /// Releases anything already waiting and lets later calls straight through. Safe
    /// to call before, during or after the call it unblocks.
    func releaseCreate() {
        lock.lock()
        _blockCreate = false
        let waiting = createContinuations
        createContinuations.removeAll()
        lock.unlock()
        // Resumed outside the lock: a continuation can run its caller synchronously,
        // and that caller may come straight back in here.
        waiting.forEach { $0.resume() }
    }

    func validateToken(_ token: String) async throws -> ClickUpUser {
        if let validateError { throw validateError }
        self.token = token
        guard let user else { throw APIError.invalidResponse }
        return user
    }

    func getTeams() async throws -> [ClickUpTeam] {
        if let teamsError { throw teamsError }
        return teams
    }

    func getTasks(teamId: String, userId: Int) async throws -> [ClickUpTask] {
        withLock { _getTasksCallCount += 1 }
        if let tasksError { throw tasksError }
        return tasks
    }

    @discardableResult
    func createTimeEntry(teamId: String,
                         taskId: String,
                         startDate: Date,
                         duration: TimeInterval) async throws -> ClickUpTimeEntry {
        await waitIfBlocked()
        withLock { _createdEntries.append((teamId, taskId, startDate, duration)) }
        if let createError { throw createError }
        return createdEntry
    }

    /// Deciding to wait and enqueueing the continuation happen under one lock, so a
    /// concurrent `releaseCreate()` either sees the continuation and resumes it, or
    /// has already cleared `_blockCreate` and this returns without suspending. There
    /// is no window in between for a continuation to be stranded.
    private func waitIfBlocked() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            lock.lock()
            guard _blockCreate else {
                lock.unlock()
                continuation.resume()
                return
            }
            createContinuations.append(continuation)
            lock.unlock()
        }
    }

    func getTimeEntries(teamId: String,
                        startDate: Date,
                        endDate: Date,
                        assignee: Int?) async throws -> [ClickUpTimeEntry] {
        withLock {
            _getTimeEntriesCallCount += 1
            _lastTimeEntriesRange = (startDate, endDate, assignee)
        }
        if let timeEntriesError { throw timeEntriesError }
        return timeEntries
    }

    /// Spelled out rather than using `NSLocking.withLock`, which cannot take a
    /// throwing body on this toolchain.
    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}
