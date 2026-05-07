import Foundation
import Security

protocol KeychainService {
    func data(service: String, account: String) -> Data?
    func save(_ data: Data, service: String, account: String) throws
    func delete(service: String, account: String)
}

struct SystemKeychainService: KeychainService {
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
            return nil
        }

        return data
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

    func data(service: String, account: String) -> Data? {
        storage[Key(service: service, account: account)]
    }

    func save(_ data: Data, service: String, account: String) throws {
        storage[Key(service: service, account: account)] = data
    }

    func delete(service: String, account: String) {
        storage.removeValue(forKey: Key(service: service, account: account))
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
