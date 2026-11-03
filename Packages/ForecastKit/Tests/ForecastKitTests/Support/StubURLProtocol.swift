import Foundation
import Synchronization

/// Serves canned responses to a `URLSession` without touching the network.
///
/// The handler is process-wide (URLProtocol is instantiated by the URL loading system),
/// so suites that use it must be `.serialized`.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    enum Reply: Sendable {
        case response(status: Int, body: Data)
        case failure(any Error & Sendable)
    }

    typealias Handler = @Sendable (URLRequest) -> Reply

    private static let handler = Mutex<Handler?>(nil)
    private static let recorded = Mutex<[URLRequest]>([])

    /// Installs `handler` and clears previously recorded requests.
    static func stub(_ handler: @escaping Handler) {
        self.handler.withLock { $0 = handler }
        recorded.withLock { $0.removeAll() }
    }

    /// Requests received since the last `stub(_:)`.
    static var requests: [URLRequest] { recorded.withLock { $0 } }

    /// An ephemeral session that routes every request through this protocol.
    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.recorded.withLock { $0.append(request) }
        guard let handler = Self.handler.withLock({ $0 }) else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        switch handler(request) {
        case let .response(status, body):
            let response = HTTPURLResponse(url: request.url!, statusCode: status,
                                           httpVersion: "HTTP/1.1",
                                           headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: body)
            client?.urlProtocolDidFinishLoading(self)
        case let .failure(error):
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
