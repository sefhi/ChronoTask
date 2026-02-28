import Foundation

final class ClickUpAPI {
    static let shared = ClickUpAPI()
    private let baseURL = "https://api.clickup.com/api/v2"
    private let session = URLSession.shared
    private let maxRetries = 3

    var token: String = ""

    private init() {}

    // MARK: - Auth

    func validateToken(_ token: String) async throws -> ClickUpUser {
        self.token = token
        let response: ClickUpUserResponse = try await request(path: "/user")
        return response.user
    }

    // MARK: - Teams

    func getTeams() async throws -> [ClickUpTeam] {
        let response: ClickUpTeamsResponse = try await request(path: "/team")
        return response.teams
    }

    // MARK: - Tasks

    func getTasks(teamId: String, userId: Int) async throws -> [ClickUpTask] {
        var allTasks: [ClickUpTask] = []
        var page = 0
        let pageSize = 100

        while true {
            let path = "/team/\(teamId)/task?page=\(page)&assignees[]=\(userId)&subtasks=true&order_by=updated&reverse=true"
            NSLog("[ClickUpAPI] getTasks page=\(page) path=\(baseURL + path)")
            let response: ClickUpTasksResponse = try await request(path: path)
            NSLog("[ClickUpAPI] getTasks page=\(page) got \(response.tasks.count) tasks")
            allTasks.append(contentsOf: response.tasks)

            if response.tasks.count < pageSize {
                break
            }
            page += 1
        }

        NSLog("[ClickUpAPI] getTasks total: \(allTasks.count) tasks")
        return allTasks
    }

    // MARK: - Time Entries

    func createTimeEntry(
        teamId: String,
        taskId: String,
        startDate: Date,
        duration: TimeInterval
    ) async throws -> ClickUpTimeEntry {
        let body: [String: Any] = [
            "tid": taskId,
            "start": startDate.millisecondsSince1970,
            "duration": duration.milliseconds
        ]
        let jsonData = try JSONSerialization.data(withJSONObject: body)
        let response: ClickUpTimeEntryResponse = try await request(
            path: "/team/\(teamId)/time_entries",
            method: "POST",
            body: jsonData
        )
        return response.data
    }

    // MARK: - Networking

    private func request<T: Decodable>(
        path: String,
        method: String = "GET",
        body: Data? = nil
    ) async throws -> T {
        guard !token.isEmpty else { throw APIError.noToken }

        guard let url = URL(string: baseURL + path) else {
            throw APIError.invalidURL
        }

        var lastError: Error = APIError.invalidResponse

        for attempt in 0..<maxRetries {
            do {
                var urlRequest = URLRequest(url: url)
                urlRequest.httpMethod = method
                urlRequest.setValue(token, forHTTPHeaderField: "Authorization")
                urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                urlRequest.httpBody = body
                urlRequest.timeoutInterval = 30

                let (data, response) = try await session.data(for: urlRequest)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIError.invalidResponse
                }

                switch httpResponse.statusCode {
                case 200...299:
                    let decoder = JSONDecoder()
                    do {
                        return try decoder.decode(T.self, from: data)
                    } catch {
                        let preview = String(data: data.prefix(500), encoding: .utf8) ?? "<binary>"
                        NSLog("[ClickUpAPI] Decode error for \(T.self): \(error)")
                        NSLog("[ClickUpAPI] Response body: \(preview)")
                        throw error
                    }
                case 401:
                    throw APIError.unauthorized
                case 429:
                    // Exponential backoff for rate limiting
                    let delay = pow(2.0, Double(attempt)) * 1.0
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    lastError = APIError.rateLimited
                    continue
                case 500...599:
                    // Retry on server errors
                    let delay = pow(2.0, Double(attempt)) * 0.5
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    let body = String(data: data, encoding: .utf8) ?? ""
                    lastError = APIError.httpError(statusCode: httpResponse.statusCode, body: body)
                    continue
                default:
                    let body = String(data: data, encoding: .utf8) ?? ""
                    throw APIError.httpError(statusCode: httpResponse.statusCode, body: body)
                }
            } catch let error as APIError {
                if case .unauthorized = error { throw error }
                lastError = error
                if attempt < maxRetries - 1 { continue }
            } catch let error as URLError {
                lastError = APIError.networkError(error.localizedDescription)
                if attempt < maxRetries - 1 {
                    let delay = pow(2.0, Double(attempt)) * 0.5
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }
            }
        }

        throw lastError
    }
}

enum APIError: LocalizedError {
    case noToken
    case invalidURL
    case invalidResponse
    case unauthorized
    case rateLimited
    case networkError(String)
    case httpError(statusCode: Int, body: String)

    var errorDescription: String? {
        switch self {
        case .noToken:
            return "No API token configured"
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Invalid or expired token"
        case .rateLimited:
            return "Rate limited — please wait"
        case .networkError(let msg):
            return "Network error: \(msg)"
        case .httpError(let code, let body):
            return "HTTP \(code): \(body)"
        }
    }
}
