import Foundation
import SwiftData

struct ReviewLanguageDetectionService: Sendable {
    func processMissingLanguages(appStoreID: Int64, using backgroundModelStore: BackgroundModelStore) async throws -> Int {
        try await backgroundModelStore.write { modelContext in
            try Self.processMissingLanguages(appStoreID: appStoreID, in: modelContext)
        }
    }

    static func processMissingLanguages(appStoreID: Int64, in modelContext: ModelContext) throws -> Int {
        let targetAppStoreID = appStoreID
        let descriptor = FetchDescriptor<AppStorefrontReview>(
            predicate: #Predicate { review in
                review.appStoreID == targetAppStoreID
                    && review.assumedLanguageCode == nil
            },
            sortBy: [SortDescriptor(\.reviewedAt, order: .reverse)]
        )

        let reviews = try modelContext.fetch(descriptor)
        for review in reviews {
            review.updateAssumedLanguage()
        }
        return reviews.count
    }
}
