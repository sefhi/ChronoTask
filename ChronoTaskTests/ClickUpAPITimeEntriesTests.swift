import XCTest
@testable import ChronoTask

final class ClickUpAPITimeEntriesTests: XCTestCase {

    private var api: ClickUpAPI!

    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
        // `.noRetry` keeps the error-path tests instant instead of sleeping through
        // three exponential backoffs.
        api = ClickUpAPI(session: MockURLProtocol.makeSession(),
                         baseURL: "https://api.test/v2",
                         retryPolicy: .noRetry)
        api.token = "pk_test"
    }

    override func tearDown() {
        MockURLProtocol.reset()
        api = nil
        super.tearDown()
    }

    func testDecodesTheEntryArrayUnderData() async throws {
        MockURLProtocol.respond(statusCode: 200, json: """
        {"data":[
          {"id":"1","start":"1774598400000","duration":"3600000"},
          {"id":"2","start":1774602000000,"duration":1800000}
        ]}
        """)

        let entries = try await api.getTimeEntries(
            teamId: "team",
            startDate: TestSupport.date("2026-07-27T00:00:00Z"),
            endDate: TestSupport.date("2026-07-28T00:00:00Z"),
            assignee: nil
        )

        XCTAssertEqual(entries.count, 2)
        // The API mixes strings and numbers for the same fields.
        XCTAssertEqual(entries[0].durationMilliseconds, 3_600_000)
        XCTAssertEqual(entries[1].durationMilliseconds, 1_800_000)
    }

    func testSendsTheDayRangeInMilliseconds() async throws {
        MockURLProtocol.respond(statusCode: 200, json: #"{"data":[]}"#)
        let start = TestSupport.date("2026-07-27T00:00:00Z")
        let end = TestSupport.date("2026-07-28T00:00:00Z")

        _ = try await api.getTimeEntries(teamId: "team", startDate: start, endDate: end, assignee: nil)

        let query = MockURLProtocol.requests.first?.url?.query ?? ""
        XCTAssertTrue(query.contains("start_date=\(start.millisecondsSince1970)"), query)
        XCTAssertTrue(query.contains("end_date=\(end.millisecondsSince1970)"), query)
        XCTAssertFalse(query.contains("assignee"), "assignee is Owner/Admin-only; omit it by default")
    }

    func testIncludesTheAssigneeOnlyWhenAsked() async throws {
        MockURLProtocol.respond(statusCode: 200, json: #"{"data":[]}"#)

        _ = try await api.getTimeEntries(teamId: "team",
                                         startDate: Date(),
                                         endDate: Date(),
                                         assignee: 42)

        XCTAssertTrue((MockURLProtocol.requests.first?.url?.query ?? "").contains("assignee=42"))
    }

    func testRunningEntriesAreFlaggedByTheirNegativeDuration() async throws {
        MockURLProtocol.respond(statusCode: 200, json: """
        {"data":[{"id":"1","start":"1774598400000","duration":"-1774598400000"}]}
        """)

        let entries = try await api.getTimeEntries(teamId: "team",
                                                   startDate: Date(),
                                                   endDate: Date(),
                                                   assignee: nil)

        XCTAssertTrue(entries[0].isRunning)
        XCTAssertEqual(entries[0].trackedSeconds, 0, "A running entry contributes nothing")
    }

    func testUnauthorizedIsSurfacedWithoutRetrying() async {
        MockURLProtocol.respond(statusCode: 401, json: #"{"err":"Token invalid"}"#)

        do {
            _ = try await api.getTimeEntries(teamId: "team",
                                             startDate: Date(),
                                             endDate: Date(),
                                             assignee: nil)
            XCTFail("Expected the call to throw")
        } catch let error as APIError {
            guard case .unauthorized = error else {
                return XCTFail("Expected .unauthorized, got \(error)")
            }
            XCTAssertEqual(MockURLProtocol.requests.count, 1, "401 must not be retried")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testMissingTokenFailsBeforeAnyRequest() async {
        api.token = ""

        do {
            _ = try await api.getTimeEntries(teamId: "team",
                                             startDate: Date(),
                                             endDate: Date(),
                                             assignee: nil)
            XCTFail("Expected the call to throw")
        } catch {
            XCTAssertTrue(MockURLProtocol.requests.isEmpty)
        }
    }

    func testTaskQueryIsPercentEncoded() async throws {
        MockURLProtocol.respond(statusCode: 200, json: #"{"tasks":[]}"#)

        _ = try await api.getTasks(teamId: "team", userId: 7)

        let query = MockURLProtocol.requests.first?.url?.query ?? ""
        // `assignees[]` used to be interpolated raw into the URL.
        XCTAssertTrue(query.contains("assignees%5B%5D=7"), query)
    }
}
