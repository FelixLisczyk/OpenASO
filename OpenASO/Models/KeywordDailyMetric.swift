import Foundation
import SwiftData

extension OpenASOSchemaV1 {
@Model
final class KeywordDailyMetric {
    #Index<KeywordDailyMetric>(
        [\.queryKey],
        [\.updatedAt]
    )

    @Attribute(.unique) var queryKey: String
    var keyword: String
    var storefront: String
    var platformRaw: String
    var popularityScore: Int?
    var difficultyScore: Int?
    var sourceRaw: String
    var popularityDate: String?
    var submissionCount: Int
    var winningCount: Int
    var confidenceRaw: String?
    var updatedAt: Date
    var notes: String?

    init(
        queryKey: String,
        keyword: String,
        storefront: String,
        platform: AppPlatform,
        popularityScore: Int?,
        difficultyScore: Int?,
        source: KeywordMetricsSource,
        popularityDate: String? = nil,
        submissionCount: Int = 1,
        winningCount: Int = 1,
        confidence: String? = nil,
        updatedAt: Date = .now,
        notes: String? = nil
    ) {
        self.queryKey = queryKey
        self.keyword = keyword
        self.storefront = storefront.lowercased()
        self.platformRaw = platform.rawValue
        self.popularityScore = popularityScore
        self.difficultyScore = difficultyScore
        self.sourceRaw = source.rawValue
        self.popularityDate = popularityDate
        self.submissionCount = submissionCount
        self.winningCount = winningCount
        self.confidenceRaw = confidence
        self.updatedAt = updatedAt
        self.notes = notes
    }

    var platform: AppPlatform {
        get { AppPlatform(rawValue: platformRaw) ?? .iphone }
        set { platformRaw = newValue.rawValue }
    }

    var source: KeywordMetricsSource {
        get { KeywordMetricsSource(rawValue: sourceRaw) ?? .appleAdsPopularity }
        set { sourceRaw = newValue.rawValue }
    }
}
}

typealias KeywordDailyMetric = OpenASOSchemaV1.KeywordDailyMetric
