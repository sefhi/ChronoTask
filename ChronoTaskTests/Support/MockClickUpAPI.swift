import Foundation
@testable import ChronoTask

/// Programmable stand-in for `ClickUpAPI`.
///
/// The real client is a singleton reaching the network; this is the seam that makes
/// `TimerManager`, `TaskStore` and `DailyTotalService` testable at all.
final class MockClickUpAPI: ClickUpAPIClient {
    var token: String = "mock-token"

    // Canned results
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

    // Recorded calls
    private(set) var createdEntries: [(teamId: String, taskId: String, start: Date, duration: TimeInterval)] = []
    private(set) var getTasksCallCount = 0
    private(set) var getTimeEntriesCallCount = 0
    private(set) var lastTimeEntriesRange: (start: Date, end: Date, assignee: Int?)?

    /// Set to block `createTimeEntry` until `releaseCreate()` is called, so tests can
    /// observe ordering rather than guessing with sleeps.
    var blockCreate = false
    private var createContinuations: [CheckedContinuation<Void, Never>] = []
    /// Set when `releaseCreate()` runs before anything got a chance to suspend, so a
    /// later call does not deadlock. Without this the ordering test is a coin flip.
    private var releasedEarly = false

    func releaseCreate() {
        blockCreate = false
        releasedEarly = true
        let pending = createContinuations
        createContinuations.removeAll()
        pending.forEach { $0.resume() }
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
        getTasksCallCount += 1
        if let tasksError { throw tasksError }
        return tasks
    }

    @discardableResult
    func createTimeEntry(teamId: String,
                         taskId: String,
                         startDate: Date,
                         duration: TimeInterval) async throws -> ClickUpTimeEntry {
        if blockCreate && !releasedEarly {
            await withCheckedContinuation { continuation in
                if releasedEarly {
                    continuation.resume()
                } else {
                    createContinuations.append(continuation)
                }
            }
        }
        createdEntries.append((teamId, taskId, startDate, duration))
        if let createError { throw createError }
        return createdEntry
    }

    func getTimeEntries(teamId: String,
                        startDate: Date,
                        endDate: Date,
                        assignee: Int?) async throws -> [ClickUpTimeEntry] {
        getTimeEntriesCallCount += 1
        lastTimeEntriesRange = (startDate, endDate, assignee)
        if let timeEntriesError { throw timeEntriesError }
        return timeEntries
    }
}
