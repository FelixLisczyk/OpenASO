import CoreGraphics
import Foundation
import ImageIO

actor AppIconStore {
    private let fileManager: FileManager
    private let cacheDirectoryURL: URL
    private let allowsNetworkFetches: Bool
    private let dataCache = NSCache<AppIconDataCacheKey, NSData>()
    private let imageCache = NSCache<AppIconImageCacheKey, CGImage>()
    private var inFlightRequests: [AppIconDataCacheKey: Task<Data?, Error>] = [:]
    private var inFlightImages: [AppIconImageCacheKey: Task<CGImage?, Error>] = [:]

    init(
        fileManager: FileManager = .default,
        namespace: AppNamespace = .current,
        allowsNetworkFetches: Bool = true
    ) {
        self.fileManager = fileManager
        self.cacheDirectoryURL = Self.makeCacheDirectoryURL(
            fileManager: fileManager,
            namespace: namespace
        )
        self.allowsNetworkFetches = allowsNetworkFetches
        self.dataCache.countLimit = 256
        self.dataCache.totalCostLimit = 16 * 1024 * 1024
        self.imageCache.countLimit = 512
        self.imageCache.totalCostLimit = 32 * 1024 * 1024
    }

    func image(
        for appStoreID: Int64,
        iconURLString: String?,
        pointSize: CGFloat,
        displayScale: CGFloat
    ) async throws -> CGImage? {
        let pixelSize = max(1, Int((pointSize * displayScale).rounded(.up)))
        let requestedIconURLString = Self.sizedArtworkURLString(iconURLString, pixelSize: pixelSize)
        let cacheKey = AppIconImageCacheKey(
            appStoreID: appStoreID,
            iconURLString: requestedIconURLString,
            pixelSize: pixelSize
        )

        if let cachedImage = imageCache.object(forKey: cacheKey) {
            return cachedImage
        }

        if let inFlightImage = inFlightImages[cacheKey] {
            return try await inFlightImage.value
        }

        let requestTask = Task<CGImage?, Error> {
            guard let data = try await self.imageData(for: appStoreID, iconURLString: requestedIconURLString) else {
                return nil
            }

            return Self.downsampleImage(data: data, pixelSize: pixelSize)
        }

        inFlightImages[cacheKey] = requestTask
        defer { inFlightImages[cacheKey] = nil }

        let image = try await requestTask.value
        if let image {
            imageCache.setObject(image, forKey: cacheKey, cost: image.memoryCost)
        }

        return image
    }

    nonisolated static func sizedArtworkURLString(_ iconURLString: String?, pixelSize: Int) -> String? {
        guard let iconURLString,
              pixelSize > 0,
              var components = URLComponents(string: iconURLString),
              components.host?.lowercased().hasSuffix("mzstatic.com") == true,
              components.path.contains("/image/thumb/")
        else {
            return iconURLString
        }

        let pathParts = components.path.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard let lastPathPart = pathParts.last,
              lastPathPart.range(
                of: #"^\d+x\d+[A-Za-z]*\.[A-Za-z0-9]+$"#,
                options: .regularExpression
              ) != nil
        else {
            return iconURLString
        }

        let suffix = lastPathPart.replacingOccurrences(
            of: #"^\d+x\d+"#,
            with: "",
            options: .regularExpression
        )
        guard !suffix.isEmpty else {
            return iconURLString
        }

        components.path = pathParts.dropLast().joined(separator: "/") + "/\(pixelSize)x\(pixelSize)\(suffix)"
        return components.url?.absoluteString ?? iconURLString
    }

    func imageData(for appStoreID: Int64, iconURLString: String?) async throws -> Data? {
        let cacheKey = AppIconDataCacheKey(appStoreID: appStoreID, iconURLString: iconURLString)
        if let cachedData = dataCache.object(forKey: cacheKey) {
            return Data(referencing: cachedData)
        }

        if let iconURLString,
           let diskData = try loadCachedDiskData(for: appStoreID, iconURLString: iconURLString) {
            dataCache.setObject(diskData as NSData, forKey: cacheKey, cost: diskData.count)
            return diskData
        }

        guard allowsNetworkFetches else {
            return nil
        }

        guard let iconURLString, let iconURL = URL(string: iconURLString) else {
            return nil
        }

        if let inFlightRequest = inFlightRequests[cacheKey] {
            return try await inFlightRequest.value
        }

        let cacheDirectoryURL = self.cacheDirectoryURL
        let requestTask = Task<Data?, Error> {
            var request = URLRequest(url: iconURL)
            request.timeoutInterval = 20

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  200 ..< 300 ~= httpResponse.statusCode else {
                return nil
            }

            try Self.persist(
                data: data,
                at: cacheDirectoryURL,
                for: appStoreID,
                iconURLString: iconURLString
            )
            return data
        }

        inFlightRequests[cacheKey] = requestTask
        defer { inFlightRequests[cacheKey] = nil }

        let downloadedData = try await requestTask.value
        if let downloadedData {
            dataCache.setObject(downloadedData as NSData, forKey: cacheKey, cost: downloadedData.count)
        }

        return downloadedData
    }

    func invalidate(appStoreID: Int64) {
        dataCache.removeAllObjects()
        imageCache.removeAllObjects()
        try? fileManager.removeItem(at: dataFileURL(for: appStoreID))
        try? fileManager.removeItem(at: metadataFileURL(for: appStoreID))
    }

    private func loadCachedDiskData(for appStoreID: Int64, iconURLString: String) throws -> Data? {
        let dataURL = dataFileURL(for: appStoreID)
        let metadataURL = metadataFileURL(for: appStoreID)

        guard fileManager.fileExists(atPath: dataURL.path) else {
            return nil
        }

        guard fileManager.fileExists(atPath: metadataURL.path) else {
            try? fileManager.removeItem(at: dataURL)
            return nil
        }

        let cachedIconURLString = try String(contentsOf: metadataURL, encoding: .utf8)
        guard cachedIconURLString == iconURLString else {
            try? fileManager.removeItem(at: dataURL)
            try? fileManager.removeItem(at: metadataURL)
            return nil
        }

        return try Data(contentsOf: dataURL)
    }

    private static func persist(data: Data, at cacheDirectoryURL: URL, for appStoreID: Int64, iconURLString: String) throws {
        try FileManager.default.createDirectory(at: cacheDirectoryURL, withIntermediateDirectories: true)
        try data.write(to: dataFileURL(for: appStoreID, cacheDirectoryURL: cacheDirectoryURL), options: .atomic)
        try iconURLString.write(
            to: metadataFileURL(for: appStoreID, cacheDirectoryURL: cacheDirectoryURL),
            atomically: true,
            encoding: .utf8
        )
    }

    private static func downsampleImage(data: Data, pixelSize: Int) -> CGImage? {
        let options = [
            kCGImageSourceShouldCache: false
        ] as CFDictionary

        guard let source = CGImageSourceCreateWithData(data as CFData, options) else {
            return nil
        }

        let downsampleOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: pixelSize
        ] as CFDictionary

        return CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions)
    }

    private func dataFileURL(for appStoreID: Int64) -> URL {
        Self.dataFileURL(for: appStoreID, cacheDirectoryURL: cacheDirectoryURL)
    }

    private func metadataFileURL(for appStoreID: Int64) -> URL {
        Self.metadataFileURL(for: appStoreID, cacheDirectoryURL: cacheDirectoryURL)
    }

    private static func dataFileURL(for appStoreID: Int64, cacheDirectoryURL: URL) -> URL {
        cacheDirectoryURL.appendingPathComponent("\(appStoreID).img", isDirectory: false)
    }

    private static func metadataFileURL(for appStoreID: Int64, cacheDirectoryURL: URL) -> URL {
        cacheDirectoryURL.appendingPathComponent("\(appStoreID).txt", isDirectory: false)
    }

    private static func makeCacheDirectoryURL(fileManager: FileManager, namespace: AppNamespace) -> URL {
        let baseURL = (try? namespace.cachesDirectoryURL(fileManager: fileManager)) ?? fileManager.temporaryDirectory
        return baseURL
            .appendingPathComponent("AppIconCache", isDirectory: true)
    }
}

private final class AppIconDataCacheKey: NSObject {
    private let appStoreID: Int64
    private let iconURLString: String?

    init(appStoreID: Int64, iconURLString: String?) {
        self.appStoreID = appStoreID
        self.iconURLString = iconURLString
    }

    override var hash: Int {
        var hasher = Hasher()
        hasher.combine(appStoreID)
        hasher.combine(iconURLString)
        return hasher.finalize()
    }

    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? AppIconDataCacheKey else {
            return false
        }

        return appStoreID == other.appStoreID && iconURLString == other.iconURLString
    }
}

private final class AppIconImageCacheKey: NSObject {
    private let appStoreID: Int64
    private let iconURLString: String?
    private let pixelSize: Int

    init(appStoreID: Int64, iconURLString: String?, pixelSize: Int) {
        self.appStoreID = appStoreID
        self.iconURLString = iconURLString
        self.pixelSize = pixelSize
    }

    override var hash: Int {
        var hasher = Hasher()
        hasher.combine(appStoreID)
        hasher.combine(iconURLString)
        hasher.combine(pixelSize)
        return hasher.finalize()
    }

    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? AppIconImageCacheKey else {
            return false
        }

        return appStoreID == other.appStoreID
            && iconURLString == other.iconURLString
            && pixelSize == other.pixelSize
    }
}

private extension CGImage {
    var memoryCost: Int {
        bytesPerRow * height
    }
}
