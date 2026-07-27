import XCTest
@testable import ChronoTask

/// This logic used to be private inside `MainView` and could not be reached from a
/// test at all.
final class TaskEligibilityTests: XCTestCase {

    func testTaskWithoutStatusIsEligible() {
        let task = TestSupport.makeTask(status: nil)
        XCTAssertTrue(TaskEligibility.isEligibleForTracking(task))
    }

    func testOpenStatusIsEligible() {
        let task = TestSupport.makeTask(status: "in progress", statusType: "custom")
        XCTAssertTrue(TaskEligibility.isEligibleForTracking(task))
    }

    func testExcludedStatusNamesAreRejected() {
        for name in ["tip", "closed", "recently closed"] {
            let task = TestSupport.makeTask(status: name)
            XCTAssertFalse(TaskEligibility.isEligibleForTracking(task),
                           "'\(name)' should not be trackable")
        }
    }

    func testStatusMatchingIgnoresCaseAndSurroundingSpace() {
        for name in ["TIP", "  Closed  ", "Recently Closed"] {
            let task = TestSupport.makeTask(status: name)
            XCTAssertFalse(TaskEligibility.isEligibleForTracking(task),
                           "'\(name)' should not be trackable")
        }
    }

    func testClosedTypeIsRejectedEvenWithACustomStatusName() {
        let task = TestSupport.makeTask(status: "Shipped", statusType: "closed")
        XCTAssertFalse(TaskEligibility.isEligibleForTracking(task))
    }

    func testFilterKeepsApiOrder() {
        let tasks = [
            TestSupport.makeTask(id: "1", name: "Uno"),
            TestSupport.makeTask(id: "2", name: "Dos", status: "closed"),
            TestSupport.makeTask(id: "3", name: "Tres"),
            TestSupport.makeTask(id: "4", name: "Cuatro", status: "tip")
        ]
        XCTAssertEqual(TaskEligibility.filter(tasks).map(\.id), ["1", "3"])
    }
}
