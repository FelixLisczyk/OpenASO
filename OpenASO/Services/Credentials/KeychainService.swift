import Foundation
import OSLog
import Security

protocol KeychainService {
    func data(service: String, account: String) -> Data?
    func save(_ data: Data, service: String, account: String) throws
    func delete(service: String, account: String)
}

struct SystemKeychainService: KeychainService {
    // Hardcoded rather than Bundle.main.bundleIdentifier so logs are filterable consistently
    // from both the GUI app and the --mcp-stdio CLI process, where Bundle.main.bundleIdentifier may be nil.
    private static let logger = Logger(subsystem: "com.thirdtech.openaso", category: "keychain")

    func data(service: String, account: String) -> Data? {
        var query = keychainQuery(service: service, account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard
            status == errSecSuccess,
            let data = item as? Data
        else {
            logReadFailure(status: status, service: service, account: account)
            return nil
        }

        return data
    }

    private func logReadFailure(status: OSStatus, service: String, account: String) {
        let description = SecCopyErrorMessageString(status, nil).map { String($0) } ?? "unknown error"
        if status == errSecItemNotFound {
            Self.logger.info("Keychain item not found for \(service, privacy: .public)/\(account, privacy: .public): \(status) (\(description, privacy: .public))")
        } else {
            Self.logger.error("Keychain read failed for \(service, privacy: .public)/\(account, privacy: .public): \(status) (\(description, privacy: .public))")
        }
    }

    func save(_ data: Data, service: String, account: String) throws {
        let query = keychainQuery(service: service, account: account)
        let attributes: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if status == errSecSuccess {
            return
        }

        guard status == errSecItemNotFound else {
            throw OpenASOError.providerUnavailable("Could not save item to Keychain.")
        }

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw OpenASOError.providerUnavailable("Could not save item to Keychain.")
        }
    }

    func delete(service: String, account: String) {
        SecItemDelete(keychainQuery(service: service, account: account) as CFDictionary)
    }

    private func keychainQuery(service: String, account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

final class InMemoryKeychainService: KeychainService {
    private var storage: [Key: Data] = [:]
    private var remainingReadFailures = 0
    private(set) var dataCallCount = 0

    func data(service: String, account: String) -> Data? {
        dataCallCount += 1
        guard remainingReadFailures == 0 else {
            remainingReadFailures -= 1
            return nil
        }
        return storage[Key(service: service, account: account)]
    }

    func save(_ data: Data, service: String, account: String) throws {
        storage[Key(service: service, account: account)] = data
    }

    func delete(service: String, account: String) {
        storage.removeValue(forKey: Key(service: service, account: account))
    }

    /// Makes the next `count` calls to `data(service:account:)` return `nil`, simulating a
    /// transient Keychain read failure, regardless of what was saved.
    func failNextReads(_ count: Int) {
        remainingReadFailures = count
    }

    private struct Key: Hashable {
        var service: String
        var account: String
    }
}

struct KeychainItemPresenceStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    func contains(service: String, account: String) -> Bool {
        defaults.bool(forKey: defaultsKey(service: service, account: account))
    }

    func markPresent(service: String, account: String) {
        defaults.set(true, forKey: defaultsKey(service: service, account: account))
    }

    func markAbsent(service: String, account: String) {
        defaults.removeObject(forKey: defaultsKey(service: service, account: account))
    }

    private func defaultsKey(service: String, account: String) -> String {
        "keychain.containsItem.\(service).\(account)"
    }
}
