import Foundation
import SwiftData

extension OpenASOSchemaV1 {
@Model
final class AppStoreScreenshot {
    @Attribute(.unique) var identityKey: String
    var appStoreID: Int64
    var storefront: String
    var platformRaw: String
    var displayTypeRaw: String
    var sortOrder: Int
    var urlString: String
    var width: Int?
    var height: Int?
    var sourceRaw: String
    var lastFetchedAt: Date

    var metadata: AppStorefrontMetadata

    init(
        appStoreID: Int64,
        storefront: String,
        platformRaw: String,
        displayTypeRaw: String = "default",
        sortOrder: Int,
        urlString: String,
        width: Int? = nil,
        height: Int? = nil,
        source: AppStorefrontMetadataSource,
        lastFetchedAt: Date = .now,
        metadata: AppStorefrontMetadata
    ) {
        let normalizedStorefront = AppStorefrontMetadata.normalizedStorefront(storefront)
        let normalizedPlatform = platformRaw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self.identityKey = Self.makeIdentityKey(
            appStoreID: appStoreID,
            storefront: normalizedStorefront,
            platformRaw: normalizedPlatform,
            displayTypeRaw: displayTypeRaw,
            sortOrder: sortOrder,
            urlString: urlString
        )
        self.appStoreID = appStoreID
        self.storefront = normalizedStorefront
        self.platformRaw = normalizedPlatform
        self.displayTypeRaw = Self.normalizedDisplayType(displayTypeRaw)
        self.sortOrder = sortOrder
        self.urlString = urlString
        self.width = width
        self.height = height
        self.sourceRaw = source.rawValue
        self.lastFetchedAt = lastFetchedAt
        self.metadata = metadata
    }

    static func makeIdentityKey(
        appStoreID: Int64,
        storefront: String,
        platformRaw: String,
        displayTypeRaw: String,
        sortOrder: Int,
        urlString: String
    ) -> String {
        [
            String(appStoreID),
            AppStorefrontMetadata.normalizedStorefront(storefront),
            platformRaw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            normalizedDisplayType(displayTypeRaw),
            String(sortOrder),
            urlHash(urlString)
        ].joined(separator: "::")
    }

    var source: AppStorefrontMetadataSource {
        get { AppStorefrontMetadataSource(rawValue: sourceRaw) ?? .iTunesSearch }
        set { sourceRaw = newValue.rawValue }
    }

    private static func urlHash(_ value: String) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(hash, radix: 16)
    }

    private static func normalizedDisplayType(_ value: String) -> String {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized.isEmpty ? "default" : normalized
    }
}
}

typealias AppStoreScreenshot = OpenASOSchemaV1.AppStoreScreenshot
