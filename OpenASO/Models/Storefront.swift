import Foundation
import SwiftData

extension OpenASOSchemaV1 {
@Model
final class Storefront {
    @Attribute(.unique) var code: String
    var name: String
    var flagEmoji: String
    var languageCode: String

    init(code: String, name: String, flagEmoji: String, languageCode: String) {
        self.code = code.lowercased()
        self.name = name
        self.flagEmoji = flagEmoji
        self.languageCode = languageCode
    }

    var title: String {
        "\(flagEmoji) \(name)"
    }
}
}

typealias Storefront = OpenASOSchemaV1.Storefront
