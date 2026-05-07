import Foundation

final class ITunesSearchFallbackProvider: SearchRankingProvider {
    private let httpClient: HTTPClient

    init(httpClient: HTTPClient) {
        self.httpClient = httpClient
    }

    func search(keyword: String, storefrontCode: String, platform: AppPlatform, limit: Int) async throws -> SearchRankingPage {
        let trimmedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKeyword.isEmpty else {
            throw OpenASOError.emptyQuery
        }
        let cappedLimit = min(max(1, limit), SearchRankingCrawl.fullKeywordRankingLimit)

        var components = URLComponents(string: "https://itunes.apple.com/search")!
        components.queryItems = [
            URLQueryItem(name: "term", value: trimmedKeyword),
            URLQueryItem(name: "entity", value: "software"),
            URLQueryItem(name: "country", value: storefrontCode.lowercased()),
            URLQueryItem(name: "limit", value: String(cappedLimit))
        ]

        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 20

        let data = try await validatedData(for: request, using: httpClient)
        guard let response = try? Self.decoder.decode(ITunesRankingResponse.self, from: data) else {
            throw OpenASOError.decodingFailed
        }

        let items = response.results.enumerated().map { index, payload in
            SearchRankingItem(
                position: index + 1,
                appStoreID: payload.trackId,
                bundleID: payload.bundleId,
                name: payload.trackName,
                subtitle: payload.subtitle,
                sellerName: payload.sellerName,
                iconURLString: payload.artworkUrl100,
                releaseDate: payload.releaseDate,
                currentVersionReleaseDate: payload.currentVersionReleaseDate,
                version: payload.version,
                primaryGenreID: payload.primaryGenreId,
                primaryGenreName: payload.primaryGenreName,
                descriptionText: payload.description,
                releaseNotes: payload.releaseNotes,
                supportedLanguageCodes: payload.languageCodesISO2A ?? [],
                screenshotURLs: payload.screenshotUrls ?? [],
                ipadScreenshotURLs: payload.ipadScreenshotUrls ?? [],
                appletvScreenshotURLs: payload.appletvScreenshotUrls ?? [],
                ratingCount: payload.userRatingCount,
                averageRating: payload.averageUserRating,
                platform: platform
            )
        }

        return SearchRankingPage(items: items, source: .iTunesFallback)
    }

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

private struct ITunesRankingResponse: Decodable {
    let results: [ITunesRankingPayload]
}

private struct ITunesRankingPayload: Decodable {
    let trackId: Int64
    let bundleId: String?
    let trackName: String
    let subtitle: String?
    let sellerName: String?
    let artworkUrl100: String?
    let releaseDate: Date?
    let currentVersionReleaseDate: Date?
    let version: String?
    let primaryGenreId: Int?
    let primaryGenreName: String?
    let description: String?
    let releaseNotes: String?
    let languageCodesISO2A: [String]?
    let screenshotUrls: [String]?
    let ipadScreenshotUrls: [String]?
    let appletvScreenshotUrls: [String]?
    let userRatingCount: Int?
    let averageUserRating: Double?
}
