import Foundation
import SwiftData
import Testing
@testable import OpenASO

@MainActor
struct ReviewTranslationIntegrationTests {
    @Test
    func publicReviewRefreshPreservesTranslationWhenReviewTextIsUnchanged() async throws {
        let container = try makeReviewTranslationTestContainer()
        let modelContext = ModelContext(container)
        let storeApp = Self.makeStoreApp()
        let review = AppStorefrontReview(
            appStoreID: storeApp.appStoreID,
            storefront: "us",
            reviewID: "9001",
            reviewerName: "Maya",
            title: "Great app",
            content: "Helpful every day.",
            rating: 5,
            reviewedAt: try #require(Self.reviewDate("2026-05-01T12:00:00-07:00")),
            storeApp: storeApp
        )
        review.translatedTitle = "Great app"
        review.translatedContent = "Helpful every day."
        review.translationLanguage = "English"
        review.translatedAt = Date(timeIntervalSince1970: 10)
        review.translationProviderRaw = AIProvider.appleFoundationModels.rawValue
        review.translationModelID = AIModelID.Apple.default.rawValue
        modelContext.insert(storeApp)
        modelContext.insert(review)
        try modelContext.save()

        let service = AppStorefrontReviewService(httpClient: MockHTTPClient { request in
            (
                Data(Self.reviewFeedJSON(entries: [
                    Self.reviewEntryJSON(
                        id: "9001",
                        author: "Maya Updated",
                        title: "Great app",
                        content: "Helpful every day.",
                        rating: 5,
                        updated: "2026-05-01T12:00:00-07:00",
                        version: "1.0"
                    )
                ]).utf8),
                makeHTTPURLResponse(url: try #require(request.url), statusCode: 200)
            )
        })

        _ = await service.refreshReviews(for: storeApp, storefronts: ["US"], in: modelContext)

        let storedReview = try #require(try modelContext.fetch(FetchDescriptor<AppStorefrontReview>()).first)
        #expect(storedReview.reviewerName == "Maya Updated")
        #expect(storedReview.translatedContent == "Helpful every day.")
        #expect(storedReview.translationLanguage == "English")
        #expect(storedReview.translationModelID == AIModelID.Apple.default.rawValue)
        #expect(storedReview.assumedLanguageCode == nil)

        let updatedCount = try ReviewLanguageDetectionService.processMissingLanguages(
            appStoreID: storeApp.appStoreID,
            in: modelContext
        )
        #expect(updatedCount == 1)
        #expect(storedReview.assumedLanguageCode == "en")
    }

    @Test
    func publicReviewRefreshClearsTranslationWhenReviewTextChanges() async throws {
        let container = try makeReviewTranslationTestContainer()
        let modelContext = ModelContext(container)
        let storeApp = Self.makeStoreApp()
        let review = AppStorefrontReview(
            appStoreID: storeApp.appStoreID,
            storefront: "us",
            reviewID: "9001",
            reviewerName: "Maya",
            title: "Great app",
            content: "Helpful every day.",
            rating: 5,
            reviewedAt: try #require(Self.reviewDate("2026-05-01T12:00:00-07:00")),
            storeApp: storeApp
        )
        review.translatedTitle = "Great app"
        review.translatedContent = "Helpful every day."
        review.translationLanguage = "English"
        review.translatedAt = Date(timeIntervalSince1970: 10)
        review.translationProviderRaw = AIProvider.appleFoundationModels.rawValue
        review.translationModelID = AIModelID.Apple.default.rawValue
        modelContext.insert(storeApp)
        modelContext.insert(review)
        try modelContext.save()

        let service = AppStorefrontReviewService(httpClient: MockHTTPClient { request in
            (
                Data(Self.reviewFeedJSON(entries: [
                    Self.reviewEntryJSON(
                        id: "9001",
                        author: "Maya",
                        title: "Still great",
                        content: "Helpful every day, especially for research.",
                        rating: 5,
                        updated: "2026-05-01T12:00:00-07:00",
                        version: "1.1"
                    )
                ]).utf8),
                makeHTTPURLResponse(url: try #require(request.url), statusCode: 200)
            )
        })

        _ = await service.refreshReviews(for: storeApp, storefronts: ["US"], in: modelContext)

        let storedReview = try #require(try modelContext.fetch(FetchDescriptor<AppStorefrontReview>()).first)
        #expect(storedReview.title == "Still great")
        #expect(storedReview.content == "Helpful every day, especially for research.")
        #expect(storedReview.translatedTitle == nil)
        #expect(storedReview.translatedContent == nil)
        #expect(storedReview.translationLanguage == nil)
        #expect(storedReview.translatedAt == nil)
        #expect(storedReview.translationProviderRaw == nil)
        #expect(storedReview.translationModelID == nil)
        #expect(storedReview.assumedLanguageCode == nil)

        let updatedCount = try ReviewLanguageDetectionService.processMissingLanguages(
            appStoreID: storeApp.appStoreID,
            in: modelContext
        )
        #expect(updatedCount == 1)
        #expect(storedReview.assumedLanguageCode == "en")
    }

    @Test
    func publicReviewRefreshStoresAssumedNonEnglishLanguage() async throws {
        let container = try makeReviewTranslationTestContainer()
        let modelContext = ModelContext(container)
        let storeApp = Self.makeStoreApp()
        modelContext.insert(storeApp)
        try modelContext.save()

        let service = AppStorefrontReviewService(httpClient: MockHTTPClient { request in
            (
                Data(Self.reviewFeedJSON(entries: [
                    Self.reviewEntryJSON(
                        id: "9002",
                        author: "Camille",
                        title: "Tres bonne application",
                        content: "Cette application est tres utile pour ecrire et faire des recherches.",
                        rating: 5,
                        updated: "2026-05-01T12:00:00-07:00",
                        version: "1.1"
                    )
                ]).utf8),
                makeHTTPURLResponse(url: try #require(request.url), statusCode: 200)
            )
        })

        _ = await service.refreshReviews(for: storeApp, storefronts: ["FR"], in: modelContext)

        let storedReview = try #require(try modelContext.fetch(FetchDescriptor<AppStorefrontReview>()).first)
        #expect(storedReview.storefront == "fr")
        #expect(storedReview.assumedLanguageCode == nil)
        #expect(storedReview.assumedLanguageConfidence == nil)

        let updatedCount = try ReviewLanguageDetectionService.processMissingLanguages(
            appStoreID: storeApp.appStoreID,
            in: modelContext
        )
        #expect(updatedCount == 1)
        #expect(storedReview.assumedLanguageCode == "fr")
        #expect(storedReview.assumedLanguageConfidence != nil)
    }

    @Test
    func backgroundLanguageDetectionStoresAssumedLanguage() async throws {
        let container = try makeReviewTranslationTestContainer()
        let modelContext = ModelContext(container)
        let storeApp = Self.makeStoreApp()
        let review = AppStorefrontReview(
            appStoreID: storeApp.appStoreID,
            storefront: "fr",
            reviewID: "9003",
            reviewerName: "Camille",
            title: "Tres bonne application",
            content: "Cette application est tres utile pour ecrire et faire des recherches.",
            rating: 5,
            reviewedAt: try #require(Self.reviewDate("2026-05-01T12:00:00-07:00")),
            storeApp: storeApp
        )
        modelContext.insert(storeApp)
        modelContext.insert(review)
        try modelContext.save()

        let backgroundModelStore = BackgroundModelStore(modelContainer: container)
        await backgroundModelStore.prepare()

        let updatedCount = try await ReviewLanguageDetectionService().processMissingLanguages(
            appStoreID: storeApp.appStoreID,
            using: backgroundModelStore
        )

        #expect(updatedCount == 1)

        let storedReview = try #require(try ModelContext(container).fetch(FetchDescriptor<AppStorefrontReview>()).first)
        #expect(storedReview.assumedLanguageCode == "fr")
        #expect(storedReview.assumedLanguageConfidence != nil)
    }

    private static func makeStoreApp() -> StoreApp {
        StoreApp(
            appStoreID: 123,
            bundleID: "com.example.app",
            name: "Example",
            sellerName: "Example Inc.",
            iconURLString: nil,
            defaultPlatform: .iphone
        )
    }

    private static func reviewFeedJSON(entries: [String]) -> String {
        """
        {
          "feed": {
            "entry": [
              \(entries.joined(separator: ","))
            ]
          }
        }
        """
    }

    private static func reviewEntryJSON(
        id: String,
        author: String,
        title: String,
        content: String,
        rating: Int,
        updated: String,
        version: String?
    ) -> String {
        """
        {
          "id": { "label": "\(id)" },
          "author": { "name": { "label": "\(author)" } },
          "title": { "label": "\(title)" },
          "content": { "label": "\(content)" },
          "im:rating": { "label": "\(rating)" },
          "updated": { "label": "\(updated)" },
          "im:version": { "label": "\(version ?? "")" }
        }
        """
    }

    private static func reviewDate(_ value: String) -> Date? {
        ISO8601DateFormatter().date(from: value)
    }
}

private func makeReviewTranslationTestContainer() throws -> ModelContainer {
    let schema = ModelContainerFactory.schema
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    return try ModelContainer(for: schema, configurations: [configuration])
}
