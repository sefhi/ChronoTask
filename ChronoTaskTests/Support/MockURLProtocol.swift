import Foundation

/// Intercepts URLSession traffic so the real client can be tested without a network.
///
/// This is only usable because `ClickUpAPI` now takes a `URLSession` — it used to
/// hard-code `URLSession.shared`, which is why the old `ClickUpAPITests` tested
/// formatters instead of the API.
final class MockURLProtocol: URLProtocol {

    /// Returns the response for a request. Set in each test.
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    /// Every request seen, in order.
    static private(set) var requests: [URLRequest] = []

    static func reset() {
        handler = nil
        requests = []
    }

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    static func respond(statusCode: Int, json: String) {
        handler = { request in
            let response = HTTPURLResponse(url: request.url!,
                                           statusCode: statusCode,
                                           httpVersion: nil,
                                           headerFields: nil)!
            return (response, Data(json.utf8))
        }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        MockURLProtocol.requests.append(request)

        guard let handler = MockURLProtocol.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
