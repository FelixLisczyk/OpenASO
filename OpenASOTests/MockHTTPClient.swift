import Foundation
@testable import OpenASO

@MainActor
final class MockHTTPClient: HTTPClient {
    private let handler: (URLRequest) throws -> (Data, URLResponse)

    init(handler: @escaping (URLRequest) throws -> (Data, URLResponse)) {
        self.handler = handler
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try handler(request)
    }
}

func makeHTTPURLResponse(
    url: URL,
    statusCode: Int,
    headerFields: [String: String]? = nil
) -> HTTPURLResponse {
    HTTPURLResponse(
        url: url,
        statusCode: statusCode,
        httpVersion: nil,
        headerFields: headerFields
    )!
}
