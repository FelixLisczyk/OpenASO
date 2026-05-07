import Foundation

enum AppPlatform: String, Codable, CaseIterable, Identifiable, Sendable {
    case iphone
    case ipad
    case mac

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .iphone:
            return "iPhone"
        case .ipad:
            return "iPad"
        case .mac:
            return "Mac"
        }
    }

    var searchPlatformValue: String {
        switch self {
        case .iphone:
            return "iphone"
        case .ipad:
            return "ipad"
        case .mac:
            return "desktop"
        }
    }
}
