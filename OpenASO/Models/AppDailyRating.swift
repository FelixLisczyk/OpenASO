import Foundation
import SwiftData

extension OpenASOSchemaV1 {
@Model
final class AppDailyRating {
    #Index<AppDailyRating>(
        [\.storefront],
        [\.storefront, \.appStoreID],
        [\.storefront, \.appStoreID, \.ratingDate],
        [\.appStoreID]
    )

    @Attribute(.unique) var identityKey: String
    var appStoreID: Int64
    var storefront: String
    var ratingDate: String
    var ratingCount: Int?
    var averageRating: Double?
    var oneStarRatingCount: Int?
    var twoStarRatingCount: Int?
    var threeStarRatingCount: Int?
    var fourStarRatingCount: Int?
    var fiveStarRatingCount: Int?
    var observedAt: Date
    var submissionCount: Int
    var winningCount: Int
    var confidenceRaw: String?
    var sourceRaw: String

    @Relationship(deleteRule: .nullify, inverse: \StoreApp.ratingSnapshots)
    var storeApp: StoreApp?

    init(
        appStoreID: Int64,
        storefront: String,
        ratingCount: Int?,
        averageRating: Double?,
        oneStarRatingCount: Int? = nil,
        twoStarRatingCount: Int? = nil,
        threeStarRatingCount: Int? = nil,
        fourStarRatingCount: Int? = nil,
        fiveStarRatingCount: Int? = nil,
        ratingDate: String? = nil,
        observedAt: Date = .now,
        submissionCount: Int = 1,
        winningCount: Int = 1,
        confidence: String? = nil,
        source: AppStorefrontSource = .appStorePage,
        storeApp: StoreApp? = nil
    ) {
        let normalizedStorefront = storefront.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedRatingDate = ratingDate ?? LatestAppRating.ratingDateString(for: observedAt)
        self.identityKey = Self.makeIdentityKey(
            appStoreID: appStoreID,
            storefront: normalizedStorefront,
            ratingDate: normalizedRatingDate
        )
        self.appStoreID = appStoreID
        self.storefront = normalizedStorefront
        self.ratingDate = normalizedRatingDate
        self.ratingCount = ratingCount
        self.averageRating = averageRating
        self.oneStarRatingCount = oneStarRatingCount
        self.twoStarRatingCount = twoStarRatingCount
        self.threeStarRatingCount = threeStarRatingCount
        self.fourStarRatingCount = fourStarRatingCount
        self.fiveStarRatingCount = fiveStarRatingCount
        self.observedAt = observedAt
        self.submissionCount = submissionCount
        self.winningCount = winningCount
        self.confidenceRaw = confidence
        self.sourceRaw = source.rawValue
        self.storeApp = storeApp
    }

    static func makeIdentityKey(appStoreID: Int64, storefront: String, ratingDate: String) -> String {
        return [
            String(appStoreID),
            storefront.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            ratingDate
        ].joined(separator: "::")
    }

    var source: AppStorefrontSource {
        get { AppStorefrontSource(rawValue: sourceRaw) ?? .appStorePage }
        set { sourceRaw = newValue.rawValue }
    }
}
}

typealias AppDailyRating = OpenASOSchemaV1.AppDailyRating
