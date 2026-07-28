import XCTest
@testable import ChronoTask

final class SyncLabelTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func label(secondsAgo: TimeInterval, isSyncing: Bool = false) -> String? {
        SyncLabel.text(lastLoaded: now.addingTimeInterval(-secondsAgo),
                       now: now,
                       isSyncing: isSyncing)
    }

    func testSyncingOutranksEverythingElse() {
        XCTAssertEqual(label(secondsAgo: 3600, isSyncing: true), SyncLabel.syncing)
        XCTAssertEqual(SyncLabel.text(lastLoaded: nil, now: now, isSyncing: true),
                       SyncLabel.syncing)
    }

    /// Claiming a freshness the app cannot back is the one thing this must not do —
    /// the same rule the daily total follows when it has never loaded.
    func testNeverLoadedSaysNothingAtAll() {
        XCTAssertNil(SyncLabel.text(lastLoaded: nil, now: now, isSyncing: false))
    }

    func testUnderAMinuteReadsAsAMoment() {
        XCTAssertEqual(label(secondsAgo: 0), SyncLabel.justNow)
        XCTAssertEqual(label(secondsAgo: 59), SyncLabel.justNow)
    }

    func testMinutesAreCountedFromExactlyOne() {
        XCTAssertEqual(label(secondsAgo: 60), "Actualizado hace 1 min")
        XCTAssertEqual(label(secondsAgo: 119), "Actualizado hace 1 min")
        XCTAssertEqual(label(secondsAgo: 120), "Actualizado hace 2 min")
        XCTAssertEqual(label(secondsAgo: 59 * 60), "Actualizado hace 59 min")
    }

    /// The prototype only counts minutes, but a failing network makes that unbounded
    /// and "hace 143 min" is not a duration anyone parses.
    func testAnHourAndBeyondSwitchesToHours() {
        XCTAssertEqual(label(secondsAgo: 3600), "Actualizado hace 1 h")
        XCTAssertEqual(label(secondsAgo: 3600 + 300), "Actualizado hace 1 h 5 min")
        XCTAssertEqual(label(secondsAgo: 7200), "Actualizado hace 2 h")
    }

    /// A clock correction can put the last load in the future; "hace -3 min" would be
    /// worse than saying nothing changed.
    func testAFutureTimestampDoesNotRenderNegatively() {
        XCTAssertEqual(label(secondsAgo: -600), SyncLabel.justNow)
    }
}
