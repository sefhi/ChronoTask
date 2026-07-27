import Foundation

/// Retry/backoff timings. Injectable so tests can exercise the error paths without
/// actually sleeping through three exponential backoffs.
struct RetryPolicy {
    var maxRetries: Int = 3
    var baseDelay: TimeInterval = 1.0        // 429
    var serverErrorDelay: TimeInterval = 0.5 // 5xx and transport errors

    static let `default` = RetryPolicy()
    static let noRetry = RetryPolicy(maxRetries: 1, baseDelay: 0, serverErrorDelay: 0)
}

final class ClickUpAPI {
    static let shared = ClickUpAPI()
    private let baseURL: String
    private let session: URLSession
    private let retryPolicy: RetryPolicy

    var token: String = ""

    init(session: URLSession = .shared,
         baseURL: String = "https://api.clickup.com/api/v2",
         retryPolicy: RetryPolicy = .default) {
        self.session = session
        self.baseURL = baseURL
        self.retryPolicy = retryPolicy
    }

    private var maxRetries: Int { retryPolicy.maxRetries }

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
        // Backstop: a server that keeps returning full pages would otherwise loop
        // forever. 20 pages is 2000 tasks, far past anything one person is assigned.
        let maxPages = 20

        while page < maxPages {
            let query = Self.query([
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "assignees[]", value: String(userId)),
                URLQueryItem(name: "subtasks", value: "true"),
                URLQueryItem(name: "order_by", value: "updated"),
                URLQueryItem(name: "reverse", value: "true")
            ])
            let path = "/team/\(teamId)/task" + query
            NSLog("[ClickUpAPI] getTasks page=\(page)")
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

    /// Time entries whose *start* falls within the given range.
    ///
    /// `assignee` is deliberately optional and unset by default: the parameter is
    /// Owner/Admin-only and returns 400 for a regular member, while the endpoint
    /// already scopes results to the authenticated user. Callers should still filter
    /// by user id on the way out.
    func getTimeEntries(
        teamId: String,
        startDate: Date,
        endDate: Date,
        assignee: Int? = nil
    ) async throws -> [ClickUpTimeEntry] {
        var items = [
            URLQueryItem(name: "start_date", value: String(startDate.millisecondsSince1970)),
            URLQueryItem(name: "end_date", value: String(endDate.millisecondsSince1970))
        ]
        if let assignee {
            items.append(URLQueryItem(name: "assignee", value: String(assignee)))
        }
        let response: ClickUpTimeEntriesResponse = try await request(
            path: "/team/\(teamId)/time_entries" + Self.query(items)
        )
        return response.data
    }

    // MARK: - Networking

    /// Percent-encodes a query string. `assignees[]` in particular must not be
    /// interpolated raw.
    private static func query(_ items: [URLQueryItem]) -> String {
        var components = URLComponents()
        components.queryItems = items
        guard let encoded = components.percentEncodedQuery else { return "" }
        return "?" + encoded
    }

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
                    let delay = pow(2.0, Double(attempt)) * retryPolicy.baseDelay
                    try await Self.sleep(delay)
                    lastError = APIError.rateLimited
                    continue
                case 500...599:
                    // Retry on server errors
                    let delay = pow(2.0, Double(attempt)) * retryPolicy.serverErrorDelay
                    try await Self.sleep(delay)
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
                    let delay = pow(2.0, Double(attempt)) * retryPolicy.serverErrorDelay
                    try await Self.sleep(delay)
                    continue
                }
            }
        }

        throw lastError
    }

    private static func sleep(_ seconds: TimeInterval) async throws {
        guard seconds > 0 else { return }
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
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
