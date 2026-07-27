import XCTest
@testable import ChronoTask

/// The guiding rule under test: logging time the user did not work is worse than
/// losing time they did.
final class SessionRecoveryTests: XCTestCase {

    private let start = TestSupport.date("2026-07-27T09:00:00Z")

    func testReopenedImmediatelyResumesSilently() {
        // Crash and relaunch: the gap is tiny, so keep counting.
        let session = TestSupport.makeSession(startedAt: start,
                                              savedAt: start.addingTimeInterval(1800))
        let now = start.addingTimeInterval(1810)

        XCTAssertEqual(SessionRecoveryPolicy.evaluate(session, now: now), .resume)
    }

    func testLongGapAsksTheUserAndOffersOnlyTheKnownStretch() {
        // The Mac may have been asleep for most of this — only the stretch up to the
        // last heartbeat can be vouched for.
        let session = TestSupport.makeSession(startedAt: start,
                                              savedAt: start.addingTimeInterval(1800))
        let now = start.addingTimeInterval(3600)

        XCTAssertEqual(SessionRecoveryPolicy.evaluate(session, now: now),
                       .prompt(knownDuration: 1800))
    }

    func testVeryOldSessionIsDiscarded() {
        let session = TestSupport.makeSession(startedAt: start,
                                              savedAt: start.addingTimeInterval(3600))
        let now = start.addingTimeInterval(13 * 3600)

        XCTAssertEqual(SessionRecoveryPolicy.evaluate(session, now: now), .discard(.tooLong))
    }

    func testBarelyStartedSessionIsDiscardedAsNoise() {
        let session = TestSupport.makeSession(startedAt: start,
                                              savedAt: start.addingTimeInterval(20))
        let now = start.addingTimeInterval(600)

        XCTAssertEqual(SessionRecoveryPolicy.evaluate(session, now: now), .discard(.tooShort))
    }

    /// A crash-and-relaunch resumes even if barely any time had been logged — the
    /// user is still sitting there working.
    func testShortSessionReopenedImmediatelyStillResumes() {
        let session = TestSupport.makeSession(startedAt: start,
                                              savedAt: start.addingTimeInterval(20))
        let now = start.addingTimeInterval(25)

        XCTAssertEqual(SessionRecoveryPolicy.evaluate(session, now: now), .resume)
    }

    func testSessionStartingInTheFutureIsDiscarded() {
        // Clock change or NTP correction.
        let session = TestSupport.makeSession(startedAt: start.addingTimeInterval(600),
                                              savedAt: start.addingTimeInterval(900))

        XCTAssertEqual(SessionRecoveryPolicy.evaluate(session, now: start),
                       .discard(.clockWentBackwards))
    }

    func testGapExactlyAtTheGraceLimitStillResumes() {
        let session = TestSupport.makeSession(startedAt: start,
                                              savedAt: start.addingTimeInterval(1800))
        let now = session.savedAt.addingTimeInterval(SessionRecoveryPolicy.resumeGraceGap)

        XCTAssertEqual(SessionRecoveryPolicy.evaluate(session, now: now), .resume)
    }
}
