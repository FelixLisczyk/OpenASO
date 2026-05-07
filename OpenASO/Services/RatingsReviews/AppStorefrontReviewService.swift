import Foundation
import OSLog
import SwiftData

final class AppStorefrontReviewService: Sendable {
    private let fetcher: AppStorefrontReviewFetcher

    init(httpClient: HTTPClient) {
        self.fetcher = AppStorefrontReviewFetcher(httpClient: httpClient)
    }

    @MainActor
    func refreshReviews(
        for storeApp: StoreApp,
        storefronts: [String],
        in modelContext: ModelContext,
        progress: (@Sendable (_ completed: Int, _ total: Int, _ failureCount: Int) async -> Void)? = nil
    ) async -> [AppStorefrontReviewRefreshOutcome] {
        let targetStorefronts = Self.normalizedStorefronts(from: storefronts)

        guard !targetStorefronts.isEmpty else {
            return [
                AppStorefrontReviewRefreshOutcome(storefront: "all", fetchedReviews: 0, storedReviews: 0, error: .providerUnavailable("No storefronts were available for reviews refresh."))
            ]
        }

        var outcomes: [AppStorefrontReviewRefreshOutcome] = []
        var completedCount = 0
        var failureCount = 0
        await progress?(0, targetStorefronts.count, 0)
        for storefront in targetStorefronts {
            do {
                let counts = try await refreshStorefrontReviews(
                    appStoreID: storeApp.appStoreID,
                    storefront: storefront,
                    storeApp: storeApp,
                    in: modelContext
                )
                outcomes.append(AppStorefrontReviewRefreshOutcome(
                    storefront: storefront,
                    fetchedReviews: counts.fetched,
                    storedReviews: counts.stored,
                    error: nil
                ))
            } catch {
                failureCount += 1
                outcomes.append(AppStorefrontReviewRefreshOutcome(
                    storefront: storefront,
                    fetchedReviews: 0,
                    storedReviews: 0,
                    error: OpenASOError.map(error)
                ))
            }
            completedCount += 1
            await progress?(completedCount, targetStorefronts.count, failureCount)
        }
        return outcomes
    }

    static func normalizedStorefronts(from storefronts: [String]) -> [String] {
        Array(Set(storefronts.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }.filter { !$0.isEmpty })).sorted()
    }

    func fetchReviews(
        appStoreID: Int64,
        storefront: String
    ) async throws -> [AppStorefrontReviewResult] {
        try await fetcher.fetchReviews(
            appStoreID: appStoreID,
            storefront: storefront
        )
    }

    func fetchReviewPages(
        appStoreID: Int64,
        storefront: String,
        handlePage: ([AppStorefrontReviewResult]) async throws -> Bool
    ) async throws -> Int {
        try await fetcher.fetchReviewPages(
            appStoreID: appStoreID,
            storefront: storefront,
            handlePage: handlePage
        )
    }

    @MainActor
    func refreshStorefrontReviews(
        appStoreID: Int64,
        storefront: String,
        storeApp: StoreApp,
        in modelContext: ModelContext
    ) async throws -> (fetched: Int, stored: Int) {
        let normalizedStorefront = storefront.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var seenReviewIDs = Set<String>()
        var fetchedCount = 0
        var storedCount = 0
        var page = 1

        while true {
            let pageReviews = try await fetcher.fetchPage(
                page: page,
                appStoreID: appStoreID,
                storefront: normalizedStorefront
            )
            guard !pageReviews.isEmpty else {
                break
            }

            let newReviews = pageReviews.filter { review in
                seenReviewIDs.insert(review.reviewID).inserted
            }
            guard !newReviews.isEmpty else {
                break
            }

            fetchedCount += newReviews.count
            let pageStoredCount = try upsert(newReviews, storeApp: storeApp, in: modelContext)
            storedCount += pageStoredCount
            try modelContext.save()
            guard pageStoredCount == newReviews.count else {
                break
            }
            page += 1
        }
        return (fetchedCount, storedCount)
    }

    func upsert(
        _ results: [AppStorefrontReviewResult],
        storeApp: StoreApp,
        in modelContext: ModelContext
    ) throws -> Int {
        let existingReviews = try fetchReviews(for: results, in: modelContext)
        var storedCount = 0
        for result in results {
            let reviewKey = AppStorefrontReview.makeReviewKey(
                appStoreID: result.appStoreID,
                storefront: result.storefront,
                reviewID: result.reviewID
            )
            let review: AppStorefrontReview
            if let existing = existingReviews[reviewKey] {
                review = existing
            } else {
                review = AppStorefrontReview(
                    appStoreID: result.appStoreID,
                    storefront: result.storefront,
                    reviewID: result.reviewID,
                    reviewerName: result.reviewerName,
                    title: result.title,
                    content: result.content,
                    rating: result.rating,
                    reviewedAt: result.reviewedAt,
                    version: result.version,
                    source: result.source,
                    observedAt: result.observedAt,
                    storeApp: storeApp
                )
                modelContext.insert(review)
                storedCount += 1
            }

            if review.title != result.title || review.content != result.content {
                review.clearTranslation()
            }

            updateIfChanged(&review.reviewerName, result.reviewerName)
            updateIfChanged(&review.title, result.title)
            updateIfChanged(&review.content, result.content)
            updateIfChanged(&review.rating, result.rating)
            updateIfChanged(&review.reviewedAt, result.reviewedAt)
            updateIfChanged(&review.version, result.version)
            if review.source != result.source {
                review.source = result.source
            }
            updateIfChanged(&review.observedAt, result.observedAt)
            if review.storeApp?.persistentModelID != storeApp.persistentModelID {
                review.storeApp = storeApp
            }
            updateIfChanged(&review.ascReviewID, result.ascReviewID)
            updateIfChanged(&review.developerResponseID, result.developerResponseID)
            updateIfChanged(&review.developerResponseBody, result.developerResponseBody)
            updateIfChanged(&review.developerResponseState, result.developerResponseState)
            updateIfChanged(&review.developerResponseModifiedAt, result.developerResponseModifiedAt)
        }

        return storedCount
    }

    private func updateIfChanged<Value: Equatable>(_ value: inout Value, _ newValue: Value) {
        if value != newValue {
            value = newValue
        }
    }

    private func fetchReviews(
        for results: [AppStorefrontReviewResult],
        in modelContext: ModelContext
    ) throws -> [String: AppStorefrontReview] {
        let reviewKeys = results.map {
            AppStorefrontReview.makeReviewKey(
                appStoreID: $0.appStoreID,
                storefront: $0.storefront,
                reviewID: $0.reviewID
            )
        }
        guard !reviewKeys.isEmpty else {
            return [:]
        }
        let descriptor = FetchDescriptor<AppStorefrontReview>(
            predicate: #Predicate { review in
                reviewKeys.contains(review.reviewKey)
            }
        )
        return Dictionary(uniqueKeysWithValues: try modelContext.fetch(descriptor).map { ($0.reviewKey, $0) })
    }
}

struct AppStorefrontReviewRefreshOutcome: Sendable {
    let storefront: String
    let fetchedReviews: Int
    let storedReviews: Int
    let error: OpenASOError?
}

struct AppStorefrontReviewResult: Sendable, Hashable {
    let appStoreID: Int64
    let storefront: String
    let reviewID: String
    let reviewerName: String
    let title: String
    let content: String
    let rating: Int
    let reviewedAt: Date
    let version: String?
    let source: AppStorefrontReviewSource
    let observedAt: Date
    let ascReviewID: String?
    let developerResponseID: String?
    let developerResponseBody: String?
    let developerResponseState: String?
    let developerResponseModifiedAt: Date?

    init(
        appStoreID: Int64,
        storefront: String,
        reviewID: String,
        reviewerName: String,
        title: String,
        content: String,
        rating: Int,
        reviewedAt: Date,
        version: String?,
        source: AppStorefrontReviewSource,
        observedAt: Date,
        ascReviewID: String? = nil,
        developerResponseID: String? = nil,
        developerResponseBody: String? = nil,
        developerResponseState: String? = nil,
        developerResponseModifiedAt: Date? = nil
    ) {
        self.appStoreID = appStoreID
        self.storefront = storefront
        self.reviewID = reviewID
        self.reviewerName = reviewerName
        self.title = title
        self.content = content
        self.rating = rating
        self.reviewedAt = reviewedAt
        self.version = version
        self.source = source
        self.observedAt = observedAt
        self.ascReviewID = ascReviewID
        self.developerResponseID = developerResponseID
        self.developerResponseBody = developerResponseBody
        self.developerResponseState = developerResponseState
        self.developerResponseModifiedAt = developerResponseModifiedAt
    }
}

private struct AppStorefrontReviewFetcher: Sendable {
    private let httpClient: HTTPClient

    init(httpClient: HTTPClient) {
        self.httpClient = httpClient
    }

    func fetchReviews(
        appStoreID: Int64,
        storefront: String
    ) async throws -> [AppStorefrontReviewResult] {
        var results: [AppStorefrontReviewResult] = []
        _ = try await fetchReviewPages(appStoreID: appStoreID, storefront: storefront) { pageReviews in
            results.append(contentsOf: pageReviews)
            return true
        }
        return results
    }

    func fetchReviewPages(
        appStoreID: Int64,
        storefront: String,
        handlePage: ([AppStorefrontReviewResult]) async throws -> Bool
    ) async throws -> Int {
        let normalizedStorefront = storefront.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var seenReviewIDs = Set<String>()
        var fetchedCount = 0
        var page = 1

        while true {
            let pageReviews = try await fetchPage(
                page: page,
                appStoreID: appStoreID,
                storefront: normalizedStorefront
            )
            guard !pageReviews.isEmpty else {
                break
            }

            let newReviews = pageReviews.filter { review in
                seenReviewIDs.insert(review.reviewID).inserted
            }

            guard !newReviews.isEmpty else {
                break
            }

            fetchedCount += newReviews.count
            let shouldContinue = try await handlePage(newReviews)
            guard shouldContinue else {
                break
            }
            page += 1
        }

        return fetchedCount
    }

    func fetchPage(
        page: Int,
        appStoreID: Int64,
        storefront: String
    ) async throws -> [AppStorefrontReviewResult] {
        var request = URLRequest(url: try makeReviewsURL(page: page, appStoreID: appStoreID, storefront: storefront))
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data = try await validatedData(for: request, using: httpClient)
        let payload = try Self.decoder.decode(CustomerReviewsFeedResponse.self, from: data)
        let observedAt = Date()
        return payload.feed.entries.compactMap {
            AppStorefrontReviewResult(
                appStoreID: appStoreID,
                storefront: storefront,
                reviewID: $0.id.label,
                reviewerName: $0.author.name.label,
                title: $0.title.label,
                content: $0.content.label,
                rating: Int($0.rating.label) ?? 0,
                reviewedAt: Self.reviewDate(from: $0.updated.label) ?? observedAt,
                version: $0.version?.label,
                source: .iTunesCustomerReviewsRSS,
                observedAt: observedAt
            )
        }
        .filter { (1...5).contains($0.rating) && !$0.reviewID.isEmpty }
    }

    private func makeReviewsURL(page: Int, appStoreID: Int64, storefront: String) throws -> URL {
        var components = URLComponents(string: "https://itunes.apple.com/rss/customerreviews/page=\(page)/id=\(appStoreID)/sortby=mostrecent/json")!
        components.queryItems = [
            URLQueryItem(name: "cc", value: storefront)
        ]

        guard let url = components.url else {
            throw OpenASOError.unexpectedResponse
        }
        return url
    }

    private static let decoder = JSONDecoder()

    private static func reviewDate(from value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }
}

private struct CustomerReviewsFeedResponse: Decodable {
    let feed: CustomerReviewsFeed
}

private struct CustomerReviewsFeed: Decodable {
    let entry: OneOrMany<CustomerReviewEntry>?

    var entries: [CustomerReviewEntry] {
        entry?.values ?? []
    }
}

private struct CustomerReviewEntry: Decodable {
    let author: CustomerReviewAuthor
    let updated: LabeledValue
    let rating: LabeledValue
    let version: LabeledValue?
    let id: LabeledValue
    let title: LabeledValue
    let content: LabeledValue

    enum CodingKeys: String, CodingKey {
        case author
        case updated
        case rating = "im:rating"
        case version = "im:version"
        case id
        case title
        case content
    }
}

private struct CustomerReviewAuthor: Decodable {
    let name: LabeledValue
}

private struct LabeledValue: Decodable {
    let label: String
}

private enum OneOrMany<Value: Decodable>: Decodable {
    case one(Value)
    case many([Value])

    var values: [Value] {
        switch self {
        case .one(let value):
            return [value]
        case .many(let values):
            return values
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let values = try? container.decode([Value].self) {
            self = .many(values)
        } else {
            self = .one(try container.decode(Value.self))
        }
    }
}
