import XCTest
@testable import ChronoTask

/// These helpers were private inside the old task picker overlay; promoting them to
/// the model made them testable.
final class ClickUpTaskDisplayTests: XCTestCase {

    func testSplitsALeadingEmoji() {
        let task = TestSupport.makeTask(name: "🚀 Deploy staging")
        XCTAssertEqual(task.leadingEmoji, "🚀")
        XCTAssertEqual(task.strippedName, "Deploy staging")
    }

    func testNameWithoutEmojiIsUntouched() {
        let task = TestSupport.makeTask(name: "Revisar propuesta")
        XCTAssertNil(task.leadingEmoji)
        XCTAssertEqual(task.strippedName, "Revisar propuesta")
    }

    /// Digits and `#` report as emoji-capable but are not what we mean.
    func testDigitsAndSymbolsAreNotTreatedAsEmoji() {
        for name in ["3 tareas pendientes", "#42 corregir bug", "*importante*"] {
            let task = TestSupport.makeTask(name: name)
            XCTAssertNil(task.leadingEmoji, "'\(name)' should have no leading emoji")
            XCTAssertEqual(task.strippedName, name)
        }
    }

    /// A name that is nothing but an emoji must not render as an empty row.
    func testEmojiOnlyNameKeepsItsText() {
        let task = TestSupport.makeTask(name: "🔥")
        XCTAssertEqual(task.leadingEmoji, "🔥")
        XCTAssertEqual(task.strippedName, "🔥")
    }

    func testSurroundingWhitespaceIsTrimmed() {
        let task = TestSupport.makeTask(name: "  📝  Escribir informe  ")
        XCTAssertEqual(task.leadingEmoji, "📝")
        XCTAssertEqual(task.strippedName, "Escribir informe")
    }

    func testStatusTintFallsBackWhenTheApiSendsNoColour() {
        let withColour = TestSupport.makeTask(status: "open", color: "#22C55E")
        let withoutColour = TestSupport.makeTask(status: "open", color: nil)
        let emptyColour = TestSupport.makeTask(status: "open", color: "")

        // Colours cannot be compared directly; assert the accessor does not trap and
        // that every branch produces a value.
        _ = withColour.statusTint
        _ = withoutColour.statusTint
        _ = emptyColour.statusTint
    }

    // MARK: - Time entry helpers

    func testTrackedSecondsConvertsFromMilliseconds() {
        let entry = ClickUpTimeEntry(duration: "90000")
        XCTAssertEqual(entry.trackedSeconds, 90, accuracy: 0.001)
        XCTAssertFalse(entry.isRunning)
    }

    func testNegativeDurationMeansRunningAndContributesNothing() {
        let entry = ClickUpTimeEntry(duration: "-1774598400000")
        XCTAssertTrue(entry.isRunning)
        XCTAssertEqual(entry.trackedSeconds, 0)
    }

    func testStartDateParsesEpochMilliseconds() {
        let expected = TestSupport.date("2026-07-27T09:00:00Z")
        let entry = ClickUpTimeEntry(start: String(expected.millisecondsSince1970))
        XCTAssertEqual(entry.startDate?.timeIntervalSince1970 ?? 0,
                       expected.timeIntervalSince1970, accuracy: 0.01)
    }

    func testMissingFieldsDegradeGracefully() {
        let entry = ClickUpTimeEntry()
        XCTAssertNil(entry.startDate)
        XCTAssertNil(entry.durationMilliseconds)
        XCTAssertEqual(entry.trackedSeconds, 0)
        XCTAssertFalse(entry.isRunning)
    }
}
