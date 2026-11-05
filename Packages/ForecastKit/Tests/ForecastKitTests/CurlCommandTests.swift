import Foundation
import Testing
@testable import ForecastKit

/// The `curl` command logged for each request reproduces it in a POSIX shell (specs/010 FR-003).
@Suite("curl command")
struct CurlCommandTests {
    @Test("A GET request becomes curl with its headers and single-quoted URL")
    func getRequest() throws {
        let request = OpenMeteoClient.searchRequest(name: "New York", language: "be")
        let url = try #require(request.url?.absoluteString)

        #expect(OpenMeteoClient.curlCommand(for: request) == "curl -H 'Accept: application/json' '\(url)'")
        #expect(url.contains("name=New%20York") && url.contains("language=be"))
    }

    @Test("Another method is named, and headers come in name order")
    func methodAndHeaders() throws {
        var request = URLRequest(url: try #require(URL(string: "https://example.com/v1/x?a=1")))
        request.httpMethod = "POST"
        request.setValue("b", forHTTPHeaderField: "X-B")
        request.setValue("a", forHTTPHeaderField: "X-A")

        #expect(OpenMeteoClient.curlCommand(for: request)
                == "curl -X POST -H 'X-A: a' -H 'X-B: b' 'https://example.com/v1/x?a=1'")
    }

    @Test("A single quote in the URL is escaped for the shell")
    func singleQuote() throws {
        let request = OpenMeteoClient.searchRequest(name: "O'Hare", language: nil)
        let url = try #require(request.url?.absoluteString)
        #expect(url.contains("O'Hare"))

        let escaped = url.replacingOccurrences(of: "'", with: #"'\''"#)
        #expect(OpenMeteoClient.curlCommand(for: request) == "curl -H 'Accept: application/json' '\(escaped)'")
    }
}
