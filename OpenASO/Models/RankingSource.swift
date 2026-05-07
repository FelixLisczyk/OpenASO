import Foundation

enum RankingSource: String, Codable, CaseIterable, Identifiable, Sendable {
    case appStoreWeb
    case iTunesFallback

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .appStoreWeb:
            return "App Store Web"
        case .iTunesFallback:
            return "iTunes Search API"
        }
    }
}
