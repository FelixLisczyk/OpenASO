import Foundation

protocol HTTPClient: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

struct URLSessionHTTPClient: HTTPClient {
    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await session.data(for: request)
    }
}

func validatedData(for request: URLRequest, using client: HTTPClient) async throws -> Data {
    let (data, response) = try await client.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
        throw OpenASOError.unexpectedResponse
    }

    switch httpResponse.statusCode {
    case 200 ..< 300:
        return data
    case 404:
        throw OpenASOError.appNotFound
    case 429:
        throw OpenASOError.rateLimited
    default:
        throw OpenASOError.providerUnavailable("HTTP \(httpResponse.statusCode)")
    }
}
