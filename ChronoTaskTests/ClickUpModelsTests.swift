import XCTest
@testable import ChronoTask

final class ClickUpModelsTests: XCTestCase {

    // MARK: - User Decoding

    func testDecodeUser() throws {
        let json = """
        {
            "user": {
                "id": 12345,
                "username": "testuser",
                "email": "test@example.com",
                "profilePicture": "https://example.com/pic.jpg"
            }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(ClickUpUserResponse.self, from: json)
        XCTAssertEqual(response.user.id, 12345)
        XCTAssertEqual(response.user.username, "testuser")
        XCTAssertEqual(response.user.email, "test@example.com")
        XCTAssertEqual(response.user.profilePicture, "https://example.com/pic.jpg")
    }

    func testDecodeUserWithoutProfilePicture() throws {
        let json = """
        {
            "user": {
                "id": 1,
                "username": "u",
                "email": "u@e.com",
                "profilePicture": null
            }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(ClickUpUserResponse.self, from: json)
        XCTAssertNil(response.user.profilePicture)
    }

    // MARK: - Team Decoding

    func testDecodeTeams() throws {
        let json = """
        {
            "teams": [
                {"id": "123", "name": "Workspace A"},
                {"id": "456", "name": "Workspace B"}
            ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(ClickUpTeamsResponse.self, from: json)
        XCTAssertEqual(response.teams.count, 2)
        XCTAssertEqual(response.teams[0].id, "123")
        XCTAssertEqual(response.teams[0].name, "Workspace A")
    }

    // MARK: - Task Decoding

    func testDecodeTask() throws {
        let json = """
        {
            "tasks": [
                {
                    "id": "abc123",
                    "name": "Fix bug",
                    "status": {
                        "status": "in progress",
                        "color": "#4194f6",
                        "type": "custom"
                    },
                    "list": {
                        "id": "list1",
                        "name": "Sprint 42"
                    },
                    "folder": {
                        "id": "folder1",
                        "name": "Development"
                    },
                    "url": "https://app.clickup.com/t/abc123"
                }
            ],
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(ClickUpTasksResponse.self, from: json)
        XCTAssertEqual(response.tasks.count, 1)

        let task = response.tasks[0]
        XCTAssertEqual(task.id, "abc123")
        XCTAssertEqual(task.name, "Fix bug")
        XCTAssertEqual(task.status?.status, "in progress")
        XCTAssertEqual(task.list?.name, "Sprint 42")
        XCTAssertEqual(task.displayName, "Fix bug (Sprint 42)")
    }

    func testDecodeTaskMinimalFields() throws {
        let json = """
        {
            "tasks": [
                {
                    "id": "t1",
                    "name": "Minimal task"
                }
            ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(ClickUpTasksResponse.self, from: json)
        let task = response.tasks[0]
        XCTAssertNil(task.status)
        XCTAssertNil(task.list)
        XCTAssertEqual(response.tasks.count, 1)
        XCTAssertEqual(task.displayName, "Minimal task")
    }

    // MARK: - Time Entry Decoding

    func testDecodeTimeEntry() throws {
        let json = """
        {
            "data": {
                "id": "te123",
                "task": {
                    "id": "t1",
                    "name": "Some task"
                },
                "start": "1700000000000",
                "end": "1700003600000",
                "duration": "3600000"
            }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(ClickUpTimeEntryResponse.self, from: json)
        XCTAssertEqual(response.data.id, "te123")
        XCTAssertEqual(response.data.task?.id, "t1")
        XCTAssertEqual(response.data.duration, "3600000")
    }

    func testDecodeTimeEntryWithNumericFields() throws {
        let json = """
        {
            "data": {
                "id": 99887766,
                "task": {
                    "id": 12345,
                    "name": "Numeric task"
                },
                "start": 1700000000000,
                "end": 1700003600000,
                "duration": 3600000
            }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(ClickUpTimeEntryResponse.self, from: json)
        XCTAssertEqual(response.data.id, "99887766")
        XCTAssertEqual(response.data.task?.id, "12345")
        XCTAssertEqual(response.data.task?.name, "Numeric task")
        XCTAssertEqual(response.data.start, "1700000000000")
        XCTAssertEqual(response.data.end, "1700003600000")
        XCTAssertEqual(response.data.duration, "3600000")
    }

    func testDecodeTimeEntryWithMixedTypes() throws {
        let json = """
        {
            "data": {
                "id": "te_mixed",
                "task": {
                    "id": 54321,
                    "name": "Mixed task"
                },
                "start": 1700000000000,
                "end": "1700003600000",
                "duration": 3600000
            }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(ClickUpTimeEntryResponse.self, from: json)
        XCTAssertEqual(response.data.id, "te_mixed")
        XCTAssertEqual(response.data.task?.id, "54321")
        XCTAssertEqual(response.data.start, "1700000000000")
        XCTAssertEqual(response.data.end, "1700003600000")
        XCTAssertEqual(response.data.duration, "3600000")
    }
}
