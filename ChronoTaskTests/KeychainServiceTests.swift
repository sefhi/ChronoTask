import XCTest
@testable import ChronoTask

final class KeychainServiceTests: XCTestCase {

    override func tearDown() {
        KeychainService.deleteToken()
        super.tearDown()
    }

    func testSaveAndLoadToken() throws {
        let token = "pk_test_token_12345"
        try KeychainService.saveToken(token)

        let loaded = KeychainService.loadToken()
        XCTAssertEqual(loaded, token)
    }

    func testLoadTokenWhenEmpty() {
        KeychainService.deleteToken()
        let loaded = KeychainService.loadToken()
        XCTAssertNil(loaded)
    }

    func testDeleteToken() throws {
        try KeychainService.saveToken("pk_to_delete")
        KeychainService.deleteToken()

        let loaded = KeychainService.loadToken()
        XCTAssertNil(loaded)
    }

    func testOverwriteToken() throws {
        try KeychainService.saveToken("pk_first")
        try KeychainService.saveToken("pk_second")

        let loaded = KeychainService.loadToken()
        XCTAssertEqual(loaded, "pk_second")
    }
}
