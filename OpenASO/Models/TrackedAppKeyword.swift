import Foundation
import SwiftData

extension OpenASOSchemaV1 {
@Model
final class TrackedAppKeyword {
    #Index<TrackedAppKeyword>(
        [\.appStoreID],
        [\.appStoreID, \.storefront],
        [\.appStoreID, \.createdAt],
        [\.identityKey]
    )

    @Attribute(.unique) var identityKey: String
    var appStoreID: Int64
    var term: String
    var storefront: String
    var platformRaw: String
    var rankingAppCount: Int?
    var lastRefreshAt: Date?
    var notes: String
    var statusMessage: String?
    var createdAt: Date

    var trackedApp: TrackedApp
    var query: KeywordQuery

    var snapshots: [TrackedKeywordDailyRanking]

    init(
        term: String,
        storefront: String,
        platform: AppPlatform,
        trackedApp: TrackedApp,
        query: KeywordQuery,
        createdAt: Date = .now
    ) {
        let normalizedTerm = term.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedStorefront = storefront.lowercased()
        self.identityKey = Self.makeIdentityKey(
            appStoreID: trackedApp.appStoreID,
            term: normalizedTerm,
            storefront: normalizedStorefront,
            platform: platform
        )
        self.appStoreID = trackedApp.appStoreID
        self.term = normalizedTerm
        self.storefront = normalizedStorefront
        self.platformRaw = platform.rawValue
        self.rankingAppCount = nil
        self.notes = ""
        self.statusMessage = nil
        self.trackedApp = trackedApp
        self.query = query
        self.lastRefreshAt = nil
        self.createdAt = createdAt
        self.snapshots = []
    }

    static func makeQueryKey(term: String, storefront: String, platform: AppPlatform) -> String {
        KeywordQuery.makeQueryKey(term: term, storefront: storefront, platform: platform)
    }

    static func makeIdentityKey(appStoreID: Int64, term: String, storefront: String, platform: AppPlatform) -> String {
        [
            String(appStoreID),
            makeQueryKey(term: term, storefront: storefront, platform: platform)
        ].joined(separator: "::")
    }

    var queryKey: String {
        Self.queryKey(fromIdentityKey: identityKey) ?? Self.makeQueryKey(
            term: term,
            storefront: storefront,
            platform: platform
        )
    }

    static func queryKey(fromIdentityKey identityKey: String) -> String? {
        let parts = identityKey.split(separator: "::", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else {
            return nil
        }
        return String(parts[1])
    }

    var platform: AppPlatform {
        get { AppPlatform(rawValue: platformRaw) ?? .iphone }
        set {
            platformRaw = newValue.rawValue
            appStoreID = trackedApp.appStoreID
            identityKey = Self.makeIdentityKey(
                appStoreID: trackedApp.appStoreID,
                term: term,
                storefront: storefront,
                platform: newValue
            )
        }
    }

    var sortedSnapshots: [TrackedKeywordDailyRanking] {
        snapshots.sorted { $0.searchedAt < $1.searchedAt }
    }

    var latestSnapshot: TrackedKeywordDailyRanking? {
        snapshots.max { $0.searchedAt < $1.searchedAt }
    }

    var previousSnapshot: TrackedKeywordDailyRanking? {
        let ordered = sortedSnapshots
        guard ordered.count > 1 else { return nil }
        return ordered[ordered.count - 2]
    }
}
}

typealias TrackedAppKeyword = OpenASOSchemaV1.TrackedAppKeyword
