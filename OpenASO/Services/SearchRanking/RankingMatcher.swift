import Foundation

enum RankingMatcher {
    static func rank(for trackedApp: TrackedApp, in items: [SearchRankingItem]) -> Int? {
        if let idMatch = items.first(where: { $0.appStoreID == trackedApp.appStoreID }) {
            return idMatch.position
        }

        guard let bundleID = trackedApp.bundleID?.trimmingCharacters(in: .whitespacesAndNewlines), !bundleID.isEmpty else {
            return nil
        }

        return items.first {
            $0.bundleID?.caseInsensitiveCompare(bundleID) == .orderedSame
        }?.position
    }
}
