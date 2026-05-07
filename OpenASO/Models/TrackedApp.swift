import Foundation
import SwiftData

extension OpenASOSchemaV1 {
@Model
final class TrackedApp {
    @Attribute(.unique) var appStoreID: Int64
    var createdAt: Date
    var isPinned: Bool = false
    var sidebarSortOrder: Int = 0

    var storeApp: StoreApp
    var folder: AppFolder?
    var keywordTracks: [TrackedAppKeyword]

    init(
        appStoreID: Int64,
        storeApp: StoreApp,
        sidebarSortOrder: Int = 0,
        createdAt: Date = .now
    ) {
        self.appStoreID = appStoreID
        self.storeApp = storeApp
        self.createdAt = createdAt
        self.sidebarSortOrder = sidebarSortOrder
        self.folder = nil
        self.keywordTracks = []
    }

    convenience init(
        appStoreID: Int64,
        bundleID: String?,
        name: String,
        subtitle: String? = nil,
        sellerName: String?,
        defaultPlatform: AppPlatform,
        sidebarSortOrder: Int = 0,
        createdAt: Date = .now
    ) {
        let storeApp = StoreApp(
            appStoreID: appStoreID,
            bundleID: bundleID,
            name: name,
            subtitle: subtitle,
            sellerName: sellerName,
            iconURLString: nil,
            defaultPlatform: defaultPlatform
        )
        self.init(
            appStoreID: appStoreID,
            storeApp: storeApp,
            sidebarSortOrder: sidebarSortOrder,
            createdAt: createdAt
        )
    }

    var bundleID: String? {
        get { storeApp.bundleID }
        set { storeApp.bundleID = newValue }
    }

    var name: String {
        get { storeApp.name }
        set { storeApp.name = newValue }
    }

    var subtitle: String? {
        get { storeApp.subtitle }
        set { storeApp.subtitle = newValue }
    }

    var sellerName: String? {
        get { storeApp.sellerName }
        set { storeApp.sellerName = newValue }
    }

    var defaultPlatform: AppPlatform {
        get { storeApp.defaultPlatform }
        set { storeApp.defaultPlatform = newValue }
    }
}
}

typealias TrackedApp = OpenASOSchemaV1.TrackedApp
