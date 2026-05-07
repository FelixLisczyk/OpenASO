import Foundation

struct AppNamespace: Sendable {
    static let current = AppNamespace(
        bundleIdentifier: Bundle.main.bundleIdentifier ?? "com.thirdtech.openaso"
    )

    let bundleIdentifier: String

    var appGroupIdentifier: String {
        "group.\(bundleIdentifier)"
    }

    var userDefaultsSuiteName: String {
        bundleIdentifier
    }

    var keychainServicePrefix: String {
        bundleIdentifier
    }

    func keychainService(_ suffix: String) -> String {
        "\(keychainServicePrefix).\(suffix)"
    }

    func applicationSupportDirectoryURL(fileManager: FileManager = .default) throws -> URL {
        try directoryURL(named: "Application Support", fileManager: fileManager)
    }

    func cachesDirectoryURL(fileManager: FileManager = .default) throws -> URL {
        try directoryURL(named: "Caches", fileManager: fileManager)
    }

    private func directoryURL(named directoryName: String, fileManager: FileManager) throws -> URL {
        let url = containerBaseURL(fileManager: fileManager)
            .appendingPathComponent(directoryName, isDirectory: true)
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func containerBaseURL(fileManager: FileManager) -> URL {
        let supportURL = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return (supportURL ?? fileManager.temporaryDirectory)
            .appendingPathComponent("OpenASO", isDirectory: true)
            .appendingPathComponent(bundleIdentifier, isDirectory: true)
    }
}

extension UserDefaults {
    static var openASOShared: UserDefaults {
        .standard
    }
}
