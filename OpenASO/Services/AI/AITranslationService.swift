import Foundation
import SwiftData

struct ReviewTranslationResult: Equatable, Sendable {
    let title: String
    let content: String
}

struct AITranslationService: Sendable {
    private let aiService: any AIService
    private let selection: AIModelSelection

    init(
        aiService: any AIService,
        selection: AIModelSelection = .defaultAppleFoundationModel
    ) {
        self.aiService = aiService
        self.selection = selection
    }

    func translateReview(title: String, content: String, to language: String) async throws -> ReviewTranslationResult {
        let trimmedLanguage = language.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLanguage.isEmpty else {
            throw OpenASOError.providerUnavailable("Choose a language before translating.")
        }

        let request = AIRequest(
            prompt: """
            Translate this App Store review to \(trimmedLanguage).
            Return only minified JSON with keys "title" and "content".

            Title:
            \(title)

            Review:
            \(content)
            """,
            instructions: "You translate App Store reviews accurately. Preserve meaning, product names, punctuation, and line breaks. Do not add commentary.",
            temperature: 0,
            maximumResponseTokens: 1_200
        )

        let response = try await aiService.respond(to: request, using: selection)
        return try Self.decodeReviewTranslation(response.text)
    }

    static func decodeReviewTranslation(_ text: String) throws -> ReviewTranslationResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw AIServiceError.emptyResponse
        }

        let jsonText = trimmed.extractingJSONObjectText()
        guard let data = jsonText.data(using: .utf8) else {
            throw AIServiceError.malformedResponse("The translation response could not be read.")
        }

        do {
            let payload = try JSONDecoder().decode(ReviewTranslationPayload.self, from: data)
            let translatedContent = payload.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !translatedContent.isEmpty else {
                throw AIServiceError.emptyResponse
            }
            return ReviewTranslationResult(
                title: payload.title.trimmingCharacters(in: .whitespacesAndNewlines),
                content: translatedContent
            )
        } catch let error as AIServiceError {
            throw error
        } catch {
            throw AIServiceError.malformedResponse("The translation response was not valid JSON.")
        }
    }
}

@MainActor
final class ReviewTranslationService {
    private let translationService: AITranslationService
    private let selection: AIModelSelection
    private let now: () -> Date

    init(
        aiService: any AIService,
        selection: AIModelSelection = .defaultAppleFoundationModel,
        now: @escaping () -> Date = { Date() }
    ) {
        self.translationService = AITranslationService(aiService: aiService, selection: selection)
        self.selection = selection
        self.now = now
    }

    var canTranslateReviews: Bool {
        switch selection.provider {
        case .appleFoundationModels:
            return FoundationModelsAIService.isDefaultModelAvailable
        }
    }

    func translate(review: AppStoreReviewValue, to language: String, in modelContext: ModelContext) async throws -> ReviewTranslationResult {
        let result = try await translationService.translateReview(
            title: review.title,
            content: review.content,
            to: language
        )

        try saveTranslation(result, reviewKey: review.reviewKey, language: language, in: modelContext)
        return result
    }

    private func saveTranslation(
        _ translation: ReviewTranslationResult,
        reviewKey: String,
        language: String,
        in modelContext: ModelContext
    ) throws {
        let targetReviewKey = reviewKey
        let descriptor = FetchDescriptor<AppStorefrontReview>(
            predicate: #Predicate { review in
                review.reviewKey == targetReviewKey
            }
        )
        guard let review = try modelContext.fetch(descriptor).first else {
            throw OpenASOError.providerUnavailable("The review is no longer available.")
        }

        review.translatedTitle = translation.title
        review.translatedContent = translation.content
        review.translationLanguage = language.trimmingCharacters(in: .whitespacesAndNewlines)
        review.translatedAt = now()
        review.translationProviderRaw = selection.provider.rawValue
        review.translationModelID = selection.model.rawValue
        try modelContext.save()
    }
}

private struct ReviewTranslationPayload: Decodable {
    let title: String
    let content: String
}

private extension String {
    func extractingJSONObjectText() -> String {
        guard let start = firstIndex(of: "{"), let end = lastIndex(of: "}"), start <= end else {
            return self
        }
        return String(self[start...end])
    }
}
