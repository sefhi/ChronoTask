import Foundation

/// Seam between the app and ClickUp.
///
/// `ClickUpAPI` is still a singleton for production use; this protocol exists so
/// services take their dependency by constructor and tests can hand them a stub.
/// `AnyObject` is required: consumers hold the client in a `let` and still need to
/// assign `token`.
protocol ClickUpAPIClient: AnyObject {
    var token: String { get set }

    func validateToken(_ token: String) async throws -> ClickUpUser
    func getTeams() async throws -> [ClickUpTeam]
    func getTasks(teamId: String, userId: Int) async throws -> [ClickUpTask]

    @discardableResult
    func createTimeEntry(teamId: String,
                         taskId: String,
                         startDate: Date,
                         duration: TimeInterval) async throws -> ClickUpTimeEntry

    func getTimeEntries(teamId: String,
                        startDate: Date,
                        endDate: Date,
                        assignee: Int?) async throws -> [ClickUpTimeEntry]
}

extension ClickUpAPI: ClickUpAPIClient {}
