import CryptoKit
import Foundation

struct AppleSearchAdsJWT {
    private struct Header: Encodable {
        let alg = "ES256"
        let kid: String
    }

    private struct Payload: Encodable {
        let aud: String
        let sub: String
        let iss: String
        let iat: Int
        let exp: Int
    }

    let clientID: String
    let teamID: String
    let keyID: String
    let privateKey: String

    func signed() throws -> String {
        let issuedAt = Int(Date().timeIntervalSince1970)
        let expiresAt = issuedAt + 86_400
        let header = Header(kid: keyID)
        let payload = Payload(
            aud: "https://appleid.apple.com",
            sub: clientID,
            iss: teamID,
            iat: issuedAt,
            exp: expiresAt
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
            throw OpenASOError.providerUnavailable("Apple Ads private key must be PEM text or base64 DER.")
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
