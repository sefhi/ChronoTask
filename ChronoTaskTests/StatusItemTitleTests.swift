import XCTest
@testable import ChronoTask

@MainActor
final class StatusItemTitleTests: XCTestCase {

    func testFormatsWithoutALeadingZeroOnHours() {
        XCTAssertEqual(StatusItemController.menuBarTime(0), "0:00:00")
        XCTAssertEqual(StatusItemController.menuBarTime(59), "0:00:59")
        XCTAssertEqual(StatusItemController.menuBarTime(60), "0:01:00")
        XCTAssertEqual(StatusItemController.menuBarTime(3600), "1:00:00")
    }

    func testHoursAreNotTruncatedPastNine() {
        XCTAssertEqual(StatusItemController.menuBarTime(36_000), "10:00:00")
        XCTAssertEqual(StatusItemController.menuBarTime(359_999), "99:59:59")
    }

    func testFractionsOfASecondAreDropped() {
        XCTAssertEqual(StatusItemController.menuBarTime(59.99), "0:00:59")
    }

    /// A negative value can appear briefly if the clock jumps backwards; it must not
    /// render as "-1:-1:-1".
    func testNegativeElapsedClampsToZero() {
        XCTAssertEqual(StatusItemController.menuBarTime(-30), "0:00:00")
    }

    /// The width only changes when the digit count does — once an hour rather than
    /// once a second.
    func testStringLengthIsStableWithinAnHourBand() {
        let lengths = [0, 59, 600, 3599].map { StatusItemController.menuBarTime(TimeInterval($0)).count }
        XCTAssertEqual(Set(lengths).count, 1)
    }

    func testParallelSuffixCountsOnlyTheExtraRuns() {
        XCTAssertEqual(StatusItemController.parallelSuffix(0), "")
        XCTAssertEqual(StatusItemController.parallelSuffix(2), "+2")
    }
}
