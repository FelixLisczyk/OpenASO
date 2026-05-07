import Foundation
import SwiftData
import Testing
@testable import OpenASO

struct AIServiceTests {
    @Test
    func reviewLanguageDetectorIdentifiesEnglishAndFrench() throws {
        let english = try #require(AppStorefrontReview.assumedLanguage(
            title: "Great app",
            content: "This app is very useful for writing and research."
        ))
        let french = try #require(AppStorefrontReview.assumedLanguage(
            title: "Tres bonne application",
            content: "Cette application est tres utile pour ecrire et faire des recherches."
        ))

        #expect(english.isEnglish)
        #expect(french.code == "fr")
        #expect(!french.isEnglish)
    }

    @Test
    func routerRoutesRequestToSelectedProviderAndModel() async throws {
        let provider = RecordingAIProvider(provider: .appleFoundationModels)
        let router = AIServiceRouter(providers: [provider])
        let selection = AIModelSelection(provider: .appleFoundationModels, model: "test-model")

        let response = try await router.respond(
            to: AIRequest(prompt: "Hello", instructions: "Be brief"),
            using: selection
        )

        #expect(response.text == "provider response")
        #expect(response.provider == .appleFoundationModels)
        #expect(response.model.rawValue == "test-model")

        let recorded = await provider.recordedRequests
        #expect(recorded.count == 1)
        #expect(recorded.first?.request.prompt == "Hello")
        #expect(recorded.first?.request.instructions == "Be brief")
        #expect(recorded.first?.model.rawValue == "test-model")
    }

    @Test
    func routerThrowsForUnavailableProvider() async throws {
        let router = AIServiceRouter(providers: [])

        await #expect(throws: AIServiceError.providerUnavailable(.appleFoundationModels)) {
            _ = try await router.respond(
                to: AIRequest(prompt: "Hello"),
                using: AIModelSelection(provider: .appleFoundationModels, model: "test-model")
            )
        }
    }

    @Test
    func foundationModelsProviderRejectsUnknownModelBeforeAvailabilityChecks() async throws {
        let service = FoundationModelsAIService()

        await #expect(throws: AIServiceError.unsupportedModel(provider: .appleFoundationModels, model: "unexpected-model")) {
            _ = try await service.respond(to: AIRequest(prompt: "Hello"), model: "unexpected-model")
        }
    }

    @Test
    func translationDecoderAcceptsJSONInsideMarkdownFence() throws {
        let result = try AITranslationService.decodeReviewTranslation(
            """
            ```json
            {"title":"Bonjour","content":"Tres utile."}
            ```
            """
        )

        #expect(result == ReviewTranslationResult(title: "Bonjour", content: "Tres utile."))
    }

    @Test
    func translationDecoderRejectsEmptyContent() throws {
        #expect(throws: AIServiceError.emptyResponse) {
            _ = try AITranslationService.decodeReviewTranslation(#"{"title":"Bonjour","content":"   "}"#)
        }
    }

    @Test
    func translationDecoderRejectsMalformedJSON() throws {
        #expect(throws: AIServiceError.malformedResponse("The translation response was not valid JSON.")) {
            _ = try AITranslationService.decodeReviewTranslation("Translated title: Bonjour")
        }
    }

    @MainActor
    @Test
    func reviewTranslationServicePersistsTranslatedReviewFields() async throws {
        let container = try makeAIServiceTestContainer()
        let modelContext = ModelContext(container)
        let review = AppStorefrontReview(
            appStoreID: 123,
            storefront: "fr",
            reviewID: "review-1",
            reviewerName: "Maya",
            title: "Tres bon",
            content: "Cette app est tres utile.",
            rating: 5,
            reviewedAt: .now
        )
        modelContext.insert(review)
        try modelContext.save()

        let service = ReviewTranslationService(
            aiService: MockAIService { request, selection in
                #expect(selection == .defaultAppleFoundationModel)
                #expect(request.prompt.contains("Translate this App Store review to English."))
                #expect(request.prompt.contains("Tres bon"))
                #expect(request.prompt.contains("Cette app est tres utile."))
                return #"{"title":"Very good","content":"This app is very useful."}"#
            },
            now: { Date(timeIntervalSince1970: 1_800) }
        )

        let result = try await service.translate(review: AppStoreReviewValue(review), to: "English", in: modelContext)

        #expect(result == ReviewTranslationResult(title: "Very good", content: "This app is very useful."))
        let storedReview = try #require(try modelContext.fetch(FetchDescriptor<AppStorefrontReview>()).first)
        #expect(storedReview.translatedTitle == "Very good")
        #expect(storedReview.translatedContent == "This app is very useful.")
        #expect(storedReview.translationLanguage == "English")
        #expect(storedReview.translatedAt == Date(timeIntervalSince1970: 1_800))
        #expect(storedReview.translationProviderRaw == AIProvider.appleFoundationModels.rawValue)
        #expect(storedReview.translationModelID == AIModelID.Apple.default.rawValue)
    }

    @MainActor
    @Test
    func reviewTranslationServiceThrowsWhenReviewWasDeletedBeforeSave() async throws {
        let container = try makeAIServiceTestContainer()
        let modelContext = ModelContext(container)
        let review = AppStorefrontReview(
            appStoreID: 123,
            storefront: "fr",
            reviewID: "review-1",
            reviewerName: "Maya",
            title: "Tres bon",
            content: "Cette app est tres utile.",
            rating: 5,
            reviewedAt: .now
        )
        let value = AppStoreReviewValue(review)
        modelContext.insert(review)
        try modelContext.save()
        modelContext.delete(review)
        try modelContext.save()

        let service = ReviewTranslationService(
            aiService: MockAIService { _, _ in
                #"{"title":"Very good","content":"This app is very useful."}"#
            }
        )

        await #expect(throws: OpenASOError.providerUnavailable("The review is no longer available.")) {
            _ = try await service.translate(review: value, to: "English", in: modelContext)
        }
    }
}

private actor RecordingAIProvider: AIProviderService {
    nonisolated let provider: AIProvider
    private(set) var recordedRequests: [(request: AIRequest, model: AIModelID)] = []

    init(provider: AIProvider) {
        self.provider = provider
    }

    func respond(to request: AIRequest, model: AIModelID) async throws -> AIResponse {
        recordedRequests.append((request, model))
        return AIResponse(text: "provider response", provider: provider, model: model)
    }
}

private func makeAIServiceTestContainer() throws -> ModelContainer {
    let schema = ModelContainerFactory.schema
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    return try ModelContainer(for: schema, configurations: [configuration])
}
