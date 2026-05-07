import Foundation
import SwiftData

extension OpenASOSchemaV1 {
@Model
final class KeywordQuery {
    @Attribute(.unique) var queryKey: String
    var term: String
    var storefront: String
    var platformRaw: String

    var tracks: [TrackedAppKeyword]
    var observations: [KeywordRankingCrawl]

    init(term: String, storefront: String, platform: AppPlatform) {
        let normalizedTerm = term.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedStorefront = storefront.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self.queryKey = Self.makeQueryKey(term: normalizedTerm, storefront: normalizedStorefront, platform: platform)
        self.term = normalizedTerm
        self.storefront = normalizedStorefront
        self.platformRaw = platform.rawValue
        self.tracks = []
        self.observations = []
    }

    static func makeQueryKey(term: String, storefront: String, platform: AppPlatform) -> String {
        [
            term.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            storefront.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            platform.rawValue
        ].joined(separator: "::")
    }

    static func fetchOrInsert(
        term: String,
        storefront: String,
        platform: AppPlatform,
        in modelContext: ModelContext
    ) throws -> KeywordQuery {
        let queryKey = makeQueryKey(term: term, storefront: storefront, platform: platform)
        var descriptor = FetchDescriptor<KeywordQuery>(
            predicate: #Predicate { query in
                query.queryKey == queryKey
            }
        )
        descriptor.fetchLimit = 1

        if let existing = try modelContext.fetch(descriptor).first {
            return existing
        }

        let query = KeywordQuery(term: term, storefront: storefront, platform: platform)
        modelContext.insert(query)
        return query
    }

    static func components(from queryKey: String) -> (term: String, storefront: String, platform: AppPlatform)? {
        let parts = queryKey.split(separator: "::", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 3, let platform = AppPlatform(rawValue: parts[2]) else {
            return nil
        }

        return (parts[0], parts[1], platform)
    }

    var platform: AppPlatform {
        get { AppPlatform(rawValue: platformRaw) ?? .iphone }
        set {
            platformRaw = newValue.rawValue
            queryKey = Self.makeQueryKey(term: term, storefront: storefront, platform: newValue)
        }
    }
}
}

typealias KeywordQuery = OpenASOSchemaV1.KeywordQuery
