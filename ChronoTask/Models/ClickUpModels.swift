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

// MARK: - Task

struct ClickUpTask: Codable, Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let status: ClickUpStatus?
    let list: ClickUpListRef?
    let folder: ClickUpFolderRef?
    let url: String?

    /// Written out rather than synthesised so that adding a field later does not
    /// silently break every call site that relies on the memberwise initialiser.
    init(id: String,
         name: String,
         status: ClickUpStatus? = nil,
         list: ClickUpListRef? = nil,
         folder: ClickUpFolderRef? = nil,
         url: String? = nil) {
        self.id = id
        self.name = name
        self.status = status
        self.list = list
        self.folder = folder
        self.url = url
    }

    /// Display name including list context
    var displayName: String {
        if let listName = list?.name {
            return "\(name) (\(listName))"
        }
        return name
    }
}

struct ClickUpStatus: Codable, Equatable, Hashable {
    let status: String
    let color: String?
    let type: String?
}

struct ClickUpListRef: Codable, Equatable, Hashable {
    let id: String
    let name: String?
}

struct ClickUpFolderRef: Codable, Equatable, Hashable {
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
    /// Present when listing entries. Used to defensively drop other people's rows —
    /// the list endpoint's `assignee` filter is Owner/Admin-only, so we cannot rely
    /// on the server to scope the response for a regular member.
    let user: ClickUpTimeEntryUser?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        task = try container.decodeIfPresent(ClickUpTimeEntryTask.self, forKey: .task)
        user = try container.decodeIfPresent(ClickUpTimeEntryUser.self, forKey: .user)
        id = try container.decodeFlexibleString(forKey: .id)
        start = try container.decodeFlexibleString(forKey: .start)
        end = try container.decodeFlexibleString(forKey: .end)
        duration = try container.decodeFlexibleString(forKey: .duration)
    }

    init(id: String? = nil,
         task: ClickUpTimeEntryTask? = nil,
         start: String? = nil,
         end: String? = nil,
         duration: String? = nil,
         user: ClickUpTimeEntryUser? = nil) {
        self.id = id
        self.task = task
        self.start = start
        self.end = end
        self.duration = duration
        self.user = user
    }

    private enum CodingKeys: String, CodingKey {
        case id, task, start, end, duration, user
    }
}

extension ClickUpTimeEntry {
    var durationMilliseconds: Int? { duration.flatMap { Int($0) } }

    var startDate: Date? {
        start.flatMap { Int($0) }.map { Date(timeIntervalSince1970: Double($0) / 1000) }
    }

    /// ClickUp reports a *running* timer as a negative duration. Such entries must be
    /// excluded from any total — treating one as elapsed time yields ~1.7e12 seconds.
    var isRunning: Bool { (durationMilliseconds ?? 0) < 0 }

    var trackedSeconds: TimeInterval { max(0, Double(durationMilliseconds ?? 0) / 1000) }
}

struct ClickUpTimeEntryUser: Codable {
    let id: Int?
    let username: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        username = try container.decodeIfPresent(String.self, forKey: .username)
        // The API sends this id as a number in some payloads and a string in others.
        if let intId = try? container.decode(Int.self, forKey: .id) {
            id = intId
        } else if let stringId = try? container.decode(String.self, forKey: .id) {
            id = Int(stringId)
        } else {
            id = nil
        }
    }

    init(id: Int?, username: String? = nil) {
        self.id = id
        self.username = username
    }

    private enum CodingKeys: String, CodingKey {
        case id, username
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

/// The list endpoint returns an array under `data`, unlike the create endpoint which
/// returns a single object under the same key.
struct ClickUpTimeEntriesResponse: Codable {
    let data: [ClickUpTimeEntry]
}
