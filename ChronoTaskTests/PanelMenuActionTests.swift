import XCTest
@testable import ChronoTask

final class PanelMenuActionTests: XCTestCase {

    /// Only Quit is set apart, and only Quit advertises a shortcut. Getting this
    /// backwards would put an accent hover on "Acerca de" and hide ⌘Q.
    func testQuitIsTheOnlyDangerousItem() {
        XCTAssertFalse(PanelMenuAction.about.isDangerous)
        XCTAssertFalse(PanelMenuAction.changeAPIKey.isDangerous)
        XCTAssertTrue(PanelMenuAction.quit.isDangerous)
    }

    func testQuitIsTheOnlyItemWithAShortcut() {
        XCTAssertNil(PanelMenuAction.about.shortcut)
        XCTAssertNil(PanelMenuAction.changeAPIKey.shortcut)
        XCTAssertEqual(PanelMenuAction.quit.shortcut, "⌘Q")
    }

    func testEveryItemHasATitleAndASymbol() {
        for action in [PanelMenuAction.about, .changeAPIKey, .quit] {
            XCTAssertFalse(action.title.isEmpty)
            XCTAssertFalse(action.symbol.isEmpty)
        }
    }
}

/// `ChronoKey` is what decides whether a keystroke reaches the panel at all.
final class ChronoKeyTests: XCTestCase {

    private func key(_ chars: String, keyCode: UInt16 = 0, command: Bool = false,
                     shift: Bool = false) -> ChronoKey? {
        var flags: NSEvent.ModifierFlags = []
        if command { flags.insert(.command) }
        if shift { flags.insert(.shift) }
        guard let event = NSEvent.keyEvent(
            with: .keyDown, location: .zero,
            modifierFlags: flags,
            timestamp: 0, windowNumber: 0, context: nil,
            characters: chars, charactersIgnoringModifiers: chars,
            isARepeat: false, keyCode: keyCode
        ) else { return nil }
        return ChronoKey(event: event)
    }

    func testCommandQIsRecognised() {
        XCTAssertEqual(key("q", command: true), .quit)
    }

    /// An agent app has no main menu to swallow ⌘Q, so the panel has to handle it —
    /// but a bare "q" is someone typing into the search field.
    func testPlainQIsNotQuit() {
        XCTAssertNil(key("q"))
    }

    func testCommandQDoesNotShadowTheSearchShortcuts() {
        XCTAssertEqual(key("k", command: true), .findShortcut)
        XCTAssertEqual(key("f", command: true), .findShortcut)
    }

    func testDigitsStillMapToQuickPick() {
        XCTAssertEqual(key("1", command: true), .quickPick(0))
        XCTAssertEqual(key("9", command: true), .quickPick(8))
    }

    func testEscapeIsRecognisedByKeyCode() {
        XCTAssertEqual(key("", keyCode: 53), .escape)
    }

    func testBothDeleteKeysStopTheFocusedTask() {
        XCTAssertEqual(key("\u{7F}", keyCode: 51), .delete)
        XCTAssertEqual(key("\u{F728}", keyCode: 117), .delete)
    }

    func testTabDirectionFollowsShift() {
        XCTAssertEqual(key("\t", keyCode: 48), .tab(backwards: false))
        XCTAssertEqual(key("\u{19}", keyCode: 48, shift: true), .tab(backwards: true))
    }
}
