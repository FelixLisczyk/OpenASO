import Foundation
import SwiftData

struct ReviewsPageLoader: Sendable {
    let appStoreID: Int64
    let storefrontCode: String?
    let cutoffDate: Date?
    let rating: Int?
    let source: AppStorefrontReviewSource?
    let backgroundModelStore: BackgroundModelStore?

    func load(request: PaginatedListPageRequest) async throws -> PaginatedListPage<AppStoreReviewValue> {
        guard let backgroundModelStore else {
            throw OpenASOError.providerUnavailable("Reviews are unavailable until the model store is ready.")
        }

        let pageSize = request.limit
        let fetchLimit = pageSize + 1
        let appStoreID = appStoreID
        let storefrontCode = storefrontCode
        let cutoffDate = cutoffDate
        let rating = rating
        let sourceRaw = source?.rawValue

        let reviews = try await backgroundModelStore.read { modelContext in
            let descriptor = Self.makeDescriptor(
                appStoreID: appStoreID,
                storefrontCode: storefrontCode,
                cutoffDate: cutoffDate,
                rating: rating
            )
            let fetchedReviews = try modelContext.fetch(descriptor).map(AppStoreReviewValue.init)
            let filteredReviews = sourceRaw.map { raw in
                fetchedReviews.filter { $0.sourceRaw == raw }
            } ?? fetchedReviews
            return Array(filteredReviews.dropFirst(request.offset).prefix(fetchLimit))
        }

        return PaginatedListPage(
            items: Array(reviews.prefix(pageSize)),
            hasMore: reviews.count > pageSize
        )
    }

    func count() async throws -> Int {
        guard let backgroundModelStore else {
            throw OpenASOError.providerUnavailable("Reviews are unavailable until the model store is ready.")
        }

        let appStoreID = appStoreID
        let storefrontCode = storefrontCode
        let cutoffDate = cutoffDate
        let rating = rating
        let sourceRaw = source?.rawValue

        return try await backgroundModelStore.read { modelContext in
            let descriptor = Self.makeDescriptor(
                appStoreID: appStoreID,
                storefrontCode: storefrontCode,
                cutoffDate: cutoffDate,
                rating: rating
            )

            guard let sourceRaw else {
                return try modelContext.fetchCount(descriptor)
            }

            return try modelContext.fetch(descriptor)
                .lazy
                .filter { $0.sourceRaw == sourceRaw }
                .count
        }
    }

    private static func makeDescriptor(
        appStoreID: Int64,
        storefrontCode: String?,
        cutoffDate: Date?,
        rating: Int?
    ) -> FetchDescriptor<AppStorefrontReview> {
        let sortBy = [SortDescriptor(\AppStorefrontReview.reviewedAt, order: .reverse)]
        let storefrontCodes = storefrontCode.map(StorefrontCatalog.storefrontCodeAliases)

        switch (storefrontCodes, cutoffDate, rating) {
        case (.some(let targetStorefronts), .some(let targetCutoffDate), .some(let targetRating)):
            return FetchDescriptor(
                predicate: #Predicate { review in
                    review.appStoreID == appStoreID
                        && targetStorefronts.contains(review.storefront)
                        && review.reviewedAt >= targetCutoffDate
                        && review.rating == targetRating
                },
                sortBy: sortBy
            )
        case (.some(let targetStorefronts), .some(let targetCutoffDate), .none):
            return FetchDescriptor(
                predicate: #Predicate { review in
                    review.appStoreID == appStoreID
                        && targetStorefronts.contains(review.storefront)
                        && review.reviewedAt >= targetCutoffDate
                },
                sortBy: sortBy
            )
        case (.some(let targetStorefronts), .none, .some(let targetRating)):
            return FetchDescriptor(
                predicate: #Predicate { review in
                    review.appStoreID == appStoreID
                        && targetStorefronts.contains(review.storefront)
                        && review.rating == targetRating
                },
                sortBy: sortBy
            )
        case (.some(let targetStorefronts), .none, .none):
            return FetchDescriptor(
                predicate: #Predicate { review in
                    review.appStoreID == appStoreID
                        && targetStorefronts.contains(review.storefront)
                },
                sortBy: sortBy
            )
        case (.none, .some(let targetCutoffDate), .some(let targetRating)):
            return FetchDescriptor(
                predicate: #Predicate { review in
                    review.appStoreID == appStoreID
                        && review.reviewedAt >= targetCutoffDate
                        && review.rating == targetRating
                },
                sortBy: sortBy
            )
        case (.none, .some(let targetCutoffDate), .none):
            return FetchDescriptor(
                predicate: #Predicate { review in
                    review.appStoreID == appStoreID
                        && review.reviewedAt >= targetCutoffDate
                },
                sortBy: sortBy
            )
        case (.none, .none, .some(let targetRating)):
            return FetchDescriptor(
                predicate: #Predicate { review in
                    review.appStoreID == appStoreID
                        && review.rating == targetRating
                },
                sortBy: sortBy
            )
        case (.none, .none, .none):
            return FetchDescriptor(
                predicate: #Predicate { review in
                    review.appStoreID == appStoreID
                },
                sortBy: sortBy
            )
        }
    }
}
