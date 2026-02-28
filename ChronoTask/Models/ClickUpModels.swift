import Foundation

// MARK: - Flexible Decoding

private extension KeyedDecodingContainer {
    /// Decodes a value that may be either a String or an Int, returning it as String?.
    func decodeFlexibleString(forKey key: Key) throws -> String? {
        if let stringValue = try? decodeIfPresent(String.self, forKey: key) {
            return stringValue
        }
        if let intValue = try? decodeIfPresent(Int.self, forKey: key) {
            return String(intValue)
        }
        return nil
    }
}

// MARK: - User

struct ClickUpUser: Codable {
    let id: Int
    let username: String
    let email: String
    let profilePicture: String?

    enum CodingKeys: String, CodingKey {
        case id, username, email
        case profilePicture = "profilePicture"
    }

    var initials: String {
        let parts = username.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(username.prefix(2)).uppercased()
    }
}

struct ClickUpUserResponse: Codable {
    let user: ClickUpUser
}

// MARK: - Team / Workspace

struct ClickUpTeam: Codable, Identifiable {
    let id: String
    let name: String
}

struct ClickUpTeamsResponse: Codable {
    let teams: [ClickUpTeam]
}

// MARK: - Space

struct ClickUpSpace: Codable, Identifiable {
    let id: String
    let name: String
}

struct ClickUpSpacesResponse: Codable {
    let spaces: [ClickUpSpace]
}

// MARK: - Task

struct ClickUpTask: Codable, Identifiable {
    let id: String
    let name: String
    let status: ClickUpStatus?
    let list: ClickUpListRef?
    let folder: ClickUpFolderRef?
    let url: String?

    /// Display name including list context
    var displayName: String {
        if let listName = list?.name {
            return "\(name) (\(listName))"
        }
        return name
    }
}

struct ClickUpStatus: Codable {
    let status: String
    let color: String?
    let type: String?
}

struct ClickUpListRef: Codable {
    let id: String
    let name: String?
}

struct ClickUpFolderRef: Codable {
    let id: String
    let name: String?
}

struct ClickUpTasksResponse: Codable {
    let tasks: [ClickUpTask]
}

// MARK: - Time Entry

struct ClickUpTimeEntry: Codable {
    let id: String?
    let task: ClickUpTimeEntryTask?
    let start: String?
    let end: String?
    let duration: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        task = try container.decodeIfPresent(ClickUpTimeEntryTask.self, forKey: .task)
        id = try container.decodeFlexibleString(forKey: .id)
        start = try container.decodeFlexibleString(forKey: .start)
        end = try container.decodeFlexibleString(forKey: .end)
        duration = try container.decodeFlexibleString(forKey: .duration)
    }

    private enum CodingKeys: String, CodingKey {
        case id, task, start, end, duration
    }
}

struct ClickUpTimeEntryTask: Codable {
    let id: String
    let name: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        // id can come as String or Int from the API
        if let stringId = try? container.decode(String.self, forKey: .id) {
            id = stringId
        } else if let intId = try? container.decode(Int.self, forKey: .id) {
            id = String(intId)
        } else {
            throw DecodingError.typeMismatch(
                String.self,
                DecodingError.Context(codingPath: container.codingPath + [CodingKeys.id],
                                      debugDescription: "Expected String or Int for id")
            )
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id, name
    }
}

struct ClickUpTimeEntryResponse: Codable {
    let data: ClickUpTimeEntry
}
