import Foundation
import SwiftData

extension OpenASOSchemaV1 {
@Model
final class StoreApp {
    #Index<StoreApp>(
        [\.appStoreID]
    )

    @Attribute(.unique) var appStoreID: Int64
    var bundleID: String?
    var name: String
    var subtitle: String?
    var sellerName: String?
    var iconURLString: String?
    var defaultStorefront: String
    var supportedLanguageCodes: [String]
    var supportedLanguageCodesSourceRaw: String?
    var supportedLanguageCodesFetchedAt: Date?
    var releaseDate: Date?
    var currentVersionReleaseDate: Date?
    var version: String?
    var primaryGenreID: Int?
    var primaryGenreName: String?
    var defaultPlatformRaw: String
    var lastMetadataRefreshAt: Date

    var storefrontMetadata: [AppStorefrontMetadata]
    var storefrontLatest: [LatestAppRating]
    var ratingSnapshots: [AppDailyRating]
    var reviews: [AppStorefrontReview]

    init(
        appStoreID: Int64,
        bundleID: String?,
        name: String,
        subtitle: String? = nil,
        sellerName: String?,
        iconURLString: String?,
        defaultStorefront: String = "us",
        supportedLanguageCodes: [String] = [],
        supportedLanguageCodesSource: AppStorefrontMetadataSource? = nil,
        supportedLanguageCodesFetchedAt: Date? = nil,
        releaseDate: Date? = nil,
        currentVersionReleaseDate: Date? = nil,
        version: String? = nil,
        primaryGenreID: Int? = nil,
        primaryGenreName: String? = nil,
        defaultPlatform: AppPlatform,
        lastMetadataRefreshAt: Date = .now
    ) {
        self.appStoreID = appStoreID
        self.bundleID = bundleID
        self.name = name
        self.subtitle = subtitle
        self.sellerName = sellerName
        self.iconURLString = iconURLString
        self.defaultStorefront = defaultStorefront.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self.supportedLanguageCodes = supportedLanguageCodes
        self.supportedLanguageCodesSourceRaw = supportedLanguageCodesSource?.rawValue
        self.supportedLanguageCodesFetchedAt = supportedLanguageCodesFetchedAt
        self.releaseDate = releaseDate
        self.currentVersionReleaseDate = currentVersionReleaseDate
        self.version = version
        self.primaryGenreID = primaryGenreID
        self.primaryGenreName = primaryGenreName
        self.defaultPlatformRaw = defaultPlatform.rawValue
        self.lastMetadataRefreshAt = lastMetadataRefreshAt
        self.storefrontMetadata = []
        self.storefrontLatest = []
        self.ratingSnapshots = []
        self.reviews = []
    }

    var defaultPlatform: AppPlatform {
        get { AppPlatform(rawValue: defaultPlatformRaw) ?? .iphone }
        set { defaultPlatformRaw = newValue.rawValue }
    }

    var supportedLanguageCodesSource: AppStorefrontMetadataSource? {
        get {
            guard let supportedLanguageCodesSourceRaw else { return nil }
            return AppStorefrontMetadataSource(rawValue: supportedLanguageCodesSourceRaw)
        }
        set {
            supportedLanguageCodesSourceRaw = newValue?.rawValue
        }
    }
}
}

typealias StoreApp = OpenASOSchemaV1.StoreApp
