import XCTest
@testable import ChronoTask

final class ClickUpAPITests: XCTestCase {

    // MARK: - Extension Tests

    func testTimerFormatted() {
        XCTAssertEqual(TimeInterval(0).timerFormatted, "00:00:00")
        XCTAssertEqual(TimeInterval(59).timerFormatted, "00:00:59")
        XCTAssertEqual(TimeInterval(60).timerFormatted, "00:01:00")
        XCTAssertEqual(TimeInterval(3661).timerFormatted, "01:01:01")
        XCTAssertEqual(TimeInterval(86399).timerFormatted, "23:59:59")
    }

    func testMilliseconds() {
        XCTAssertEqual(TimeInterval(1.0).milliseconds, 1000)
        XCTAssertEqual(TimeInterval(0.5).milliseconds, 500)
        XCTAssertEqual(TimeInterval(3600).milliseconds, 3600000)
    }

    func testDateMillisecondsSince1970() {
        let date = Date(timeIntervalSince1970: 1700000000)
        XCTAssertEqual(date.millisecondsSince1970, 1700000000000)
    }

    // MARK: - API Error Descriptions

    func testAPIErrorDescriptions() {
        XCTAssertNotNil(APIError.noToken.errorDescription)
        XCTAssertNotNil(APIError.invalidURL.errorDescription)
        XCTAssertNotNil(APIError.invalidResponse.errorDescription)
        XCTAssertNotNil(APIError.unauthorized.errorDescription)
        XCTAssertNotNil(APIError.rateLimited.errorDescription)
        XCTAssertNotNil(APIError.networkError("timeout").errorDescription)
        XCTAssertNotNil(APIError.httpError(statusCode: 500, body: "error").errorDescription)

        XCTAssertTrue(APIError.unauthorized.errorDescription!.contains("token"))
        XCTAssertTrue(APIError.networkError("timeout").errorDescription!.contains("timeout"))
    }

    // MARK: - Color Extension

    func testColorHexInit() {
        // Just verify no crash - we can't easily compare SwiftUI Colors
        _ = SwiftUI.Color(hex: "FF0000")
        _ = SwiftUI.Color(hex: "#00FF00")
        _ = SwiftUI.Color(hex: "0000FF")
        _ = SwiftUI.Color(hex: "FF00FF00") // ARGB
    }
}

import SwiftUI
