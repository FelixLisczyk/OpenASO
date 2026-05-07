import CryptoKit
import Foundation
import Observation

struct AppStoreConnectCredentials: Equatable, Sendable {
    var issuerID: String
    var keyID: String
    var privateKey: String

    var trimmed: AppStoreConnectCredentials {
        AppStoreConnectCredentials(
            issuerID: issuerID.trimmingCharacters(in: .whitespacesAndNewlines),
            keyID: keyID.trimmingCharacters(in: .whitespacesAndNewlines),
            privateKey: privateKey.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    var isComplete: Bool {
        let credentials = trimmed
        return !credentials.issuerID.isEmpty
            && !credentials.keyID.isEmpty
            && !credentials.privateKey.isEmpty
    }
}

@MainActor
@Observable
final class AppStoreConnectCredentialStore {
    private enum DefaultsKey {
        static let issuerID = "appStoreConnect.issuerID"
        static let keyID = "appStoreConnect.keyID"
    }

    private let defaults: UserDefaults
    private let keychain: any KeychainService
    private let keychainItemPresence: KeychainItemPresenceStore
    private let keychainService: String
    private let privateKeyAccount = "private-key"

    private(set) var credentials: AppStoreConnectCredentials

    init(
        defaults: UserDefaults = .openASOShared,
        keychain: any KeychainService = SystemKeychainService(),
        namespace: AppNamespace = .current
    ) {
        self.defaults = defaults
        self.keychain = keychain
        self.keychainService = namespace.keychainService("app-store-connect")
        let keychainItemPresence = KeychainItemPresenceStore(defaults: defaults)
        self.keychainItemPresence = keychainItemPresence
        self.credentials = AppStoreConnectCredentials(
            issuerID: defaults.string(forKey: DefaultsKey.issuerID) ?? "",
            keyID: defaults.string(forKey: DefaultsKey.keyID) ?? "",
            privateKey: keychainItemPresence.contains(service: keychainService, account: privateKeyAccount)
                ? Self.readSecret(service: keychainService, account: privateKeyAccount, keychain: keychain) ?? ""
                : ""
        )
    }

    var hasCompleteCredentials: Bool {
        credentials.isComplete
    }

    func save(_ credentials: AppStoreConnectCredentials) throws {
        let trimmedCredentials = credentials.trimmed
        defaults.set(trimmedCredentials.issuerID, forKey: DefaultsKey.issuerID)
        defaults.set(trimmedCredentials.keyID, forKey: DefaultsKey.keyID)
        try Self.saveSecret(
            trimmedCredentials.privateKey,
            service: keychainService,
            account: privateKeyAccount,
            keychain: keychain
        )
        keychainItemPresence.markPresent(service: keychainService, account: privateKeyAccount)
        self.credentials = trimmedCredentials
    }

    func clear() {
        defaults.removeObject(forKey: DefaultsKey.issuerID)
        defaults.removeObject(forKey: DefaultsKey.keyID)
        keychain.delete(service: keychainService, account: privateKeyAccount)
        keychainItemPresence.markAbsent(service: keychainService, account: privateKeyAccount)
        credentials = AppStoreConnectCredentials(issuerID: "", keyID: "", privateKey: "")
    }

    private static func saveSecret(
        _ secret: String,
        service: String,
        account: String,
        keychain: any KeychainService
    ) throws {
        do {
            try keychain.save(Data(secret.utf8), service: service, account: account)
        } catch {
            throw OpenASOError.providerUnavailable("Could not save App Store Connect private key to Keychain.")
        }
    }

    private static func readSecret(service: String, account: String, keychain: any KeychainService) -> String? {
        guard let data = keychain.data(service: service, account: account) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

struct AppStoreConnectJWT {
    private struct Header: Encodable {
        let alg = "ES256"
        let kid: String
        let typ = "JWT"
    }

    private struct Payload: Encodable {
        let iss: String
        let aud = "appstoreconnect-v1"
        let iat: Int
        let exp: Int
    }

    let issuerID: String
    let keyID: String
    let privateKey: String
    var issuedAt: Date = .now
    var lifetime: TimeInterval = 20 * 60

    func signed() throws -> String {
        let issuedAtTimestamp = Int(issuedAt.timeIntervalSince1970)
        let lifetimeSeconds = min(max(Int(lifetime), 1), 20 * 60)
        let header = Header(kid: keyID)
        let payload = Payload(
            iss: issuerID,
            iat: issuedAtTimestamp,
            exp: issuedAtTimestamp + lifetimeSeconds
        )
        let encoder = JSONEncoder()
        let signingInput = try [
            encoder.encode(header).base64URLEncodedString(),
            encoder.encode(payload).base64URLEncodedString()
        ].joined(separator: ".")

        guard let signingData = signingInput.data(using: .utf8) else {
            throw OpenASOError.unexpectedResponse
        }

        let key = try signingKey(from: privateKey)
        let signature = try key.signature(for: signingData)
        return "\(signingInput).\(signature.rawRepresentation.base64URLEncodedString())"
    }

    private func signingKey(from privateKey: String) throws -> P256.Signing.PrivateKey {
        let normalizedKey = privateKey.replacingOccurrences(of: "\\n", with: "\n")

        if normalizedKey.contains("BEGIN") {
            return try P256.Signing.PrivateKey(pemRepresentation: normalizedKey)
        }

        guard let keyData = Data(base64Encoded: normalizedKey) else {
            throw OpenASOError.providerUnavailable("App Store Connect private key must be PEM text or base64 DER.")
        }

        return try P256.Signing.PrivateKey(derRepresentation: keyData)
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "=", with: "")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
    }
}
