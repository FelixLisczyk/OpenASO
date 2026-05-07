import Foundation
import SwiftData

extension OpenASOSchemaV1 {
@Model
final class AppKeywordStats {
    @Attribute(.unique) var identityKey: String
    var appStoreID: Int64
    var queryKey: String
    var keyword: String
    var storefront: String
    var platformRaw: String
    var bestRank: Int?
    var latestRank: Int?
    var averageRank: Double?
    var observationCount: Int
    var firstSeenAt: Date
    var lastSeenAt: Date
    var popularityScore: Int?
    var difficultyScore: Int?

    init(
        appStoreID: Int64,
        queryKey: String,
        keyword: String,
        storefront: String,
        platform: AppPlatform,
        rank: Int,
        observedAt: Date,
        popularityScore: Int? = nil,
        difficultyScore: Int? = nil
    ) {
        self.identityKey = Self.makeIdentityKey(appStoreID: appStoreID, queryKey: queryKey)
        self.appStoreID = appStoreID
        self.queryKey = queryKey
        self.keyword = keyword
        self.storefront = storefront.lowercased()
        self.platformRaw = platform.rawValue
        self.bestRank = rank
        self.latestRank = rank
        self.averageRank = Double(rank)
        self.observationCount = 1
        self.firstSeenAt = observedAt
        self.lastSeenAt = observedAt
        self.popularityScore = popularityScore
        self.difficultyScore = difficultyScore
    }

    static func makeIdentityKey(appStoreID: Int64, queryKey: String) -> String {
        [String(appStoreID), queryKey].joined(separator: "::")
    }

    var platform: AppPlatform {
        get { AppPlatform(rawValue: platformRaw) ?? .iphone }
        set { platformRaw = newValue.rawValue }
    }
}
}

typealias AppKeywordStats = OpenASOSchemaV1.AppKeywordStats
