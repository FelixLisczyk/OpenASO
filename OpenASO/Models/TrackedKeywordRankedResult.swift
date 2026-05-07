import Foundation
import SwiftData

extension OpenASOSchemaV1 {
@Model
final class TrackedKeywordRankedResult {
    var snapshotKey: String
    var position: Int
    var appStoreID: Int64
    var bundleID: String?
    var name: String
    var subtitle: String?
    var sellerName: String?

    var snapshot: TrackedKeywordDailyRanking

    init(
        position: Int,
        appStoreID: Int64,
        bundleID: String?,
        name: String,
        subtitle: String? = nil,
        sellerName: String?,
        snapshot: TrackedKeywordDailyRanking
    ) {
        self.snapshotKey = snapshot.snapshotKey
        self.position = position
        self.appStoreID = appStoreID
        self.bundleID = bundleID
        self.name = name
        self.subtitle = subtitle
        self.sellerName = sellerName
        self.snapshot = snapshot
    }
}
}

typealias TrackedKeywordRankedResult = OpenASOSchemaV1.TrackedKeywordRankedResult
