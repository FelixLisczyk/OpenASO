import Foundation
import NaturalLanguage
import SwiftData

extension OpenASOSchemaV1 {
@Model
final class AppStorefrontReview {
    @Attribute(.unique) var reviewKey: String
    var appStoreID: Int64
    var storefront: String
    var reviewID: String
    var reviewerName: String
    var title: String
    var content: String
    var rating: Int
    var reviewedAt: Date
    var version: String?
    var sourceRaw: String
    var observedAt: Date
    var ascReviewID: String?
    var developerResponseID: String?
    var developerResponseBody: String?
    var developerResponseState: String?
    var developerResponseModifiedAt: Date?
    var translatedTitle: String?
    var translatedContent: String?
    var translationLanguage: String?
    var translatedAt: Date?
    var translationProviderRaw: String?
    var translationModelID: String?
    var assumedLanguageCode: String?
    var assumedLanguageConfidence: Double?

    var storeApp: StoreApp?

    init(
        appStoreID: Int64,
        storefront: String,
        reviewID: String,
        reviewerName: String,
        title: String,
        content: String,
        rating: Int,
        reviewedAt: Date,
        version: String? = nil,
        source: AppStorefrontReviewSource = .iTunesCustomerReviewsRSS,
        observedAt: Date = .now,
        storeApp: StoreApp? = nil
    ) {
        let normalizedStorefront = StorefrontCatalog.normalizedStorefrontCode(storefront)
        self.reviewKey = Self.makeReviewKey(
            appStoreID: appStoreID,
            storefront: normalizedStorefront,
            reviewID: reviewID
        )
        self.appStoreID = appStoreID
        self.storefront = normalizedStorefront
        self.reviewID = reviewID
        self.reviewerName = reviewerName
        self.title = title
        self.content = content
        self.rating = rating
        self.reviewedAt = reviewedAt
        self.version = version
        self.sourceRaw = source.rawValue
        self.observedAt = observedAt
        self.ascReviewID = nil
        self.developerResponseID = nil
        self.developerResponseBody = nil
        self.developerResponseState = nil
        self.developerResponseModifiedAt = nil
        self.translatedTitle = nil
        self.translatedContent = nil
        self.translationLanguage = nil
        self.translatedAt = nil
        self.translationProviderRaw = nil
        self.translationModelID = nil
        self.assumedLanguageCode = nil
        self.assumedLanguageConfidence = nil
        self.storeApp = storeApp
    }

    static func makeReviewKey(appStoreID: Int64, storefront: String, reviewID: String) -> String {
        [
            String(appStoreID),
            StorefrontCatalog.normalizedStorefrontCode(storefront),
            reviewID
        ].joined(separator: "::")
    }

    var source: AppStorefrontReviewSource {
        get { AppStorefrontReviewSource(rawValue: sourceRaw) ?? .iTunesCustomerReviewsRSS }
        set { sourceRaw = newValue.rawValue }
    }

    func clearTranslation() {
        translatedTitle = nil
        translatedContent = nil
        translationLanguage = nil
        translatedAt = nil
        translationProviderRaw = nil
        translationModelID = nil
    }

    func updateAssumedLanguage() {
        let language = Self.assumedLanguage(title: title, content: content)
        assumedLanguageCode = language?.code
        assumedLanguageConfidence = language?.confidence
    }

    static func assumedLanguage(title: String, content: String) -> AssumedReviewLanguage? {
        let text = [title, content]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
        guard !text.isEmpty else { return nil }

        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        guard let language = recognizer.dominantLanguage else { return nil }

        let code = language.rawValue
        let confidence = recognizer.languageHypotheses(withMaximum: 1)[language]
        return AssumedReviewLanguage(code: code, confidence: confidence)
    }
}
}

typealias AppStorefrontReview = OpenASOSchemaV1.AppStorefrontReview

struct AssumedReviewLanguage: Equatable, Sendable {
    let code: String
    let confidence: Double?

    var isEnglish: Bool {
        code.lowercased().split(separator: "-").first == "en"
    }
}

enum AppStorefrontReviewSource: String, Codable, Sendable {
    case iTunesCustomerReviewsRSS
    case appStoreConnect
}
