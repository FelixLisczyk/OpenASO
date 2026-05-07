import Testing
@testable import OpenASO

struct RankingMatcherTests {
    @Test
    func matchesByAppStoreIDBeforeBundleID() {
        let trackedApp = TrackedApp(
            appStoreID: 99,
            bundleID: "com.example.target",
            name: "Target",
            sellerName: "Example",
            defaultPlatform: .iphone
        )

        let results = [
            SearchRankingItem(position: 1, appStoreID: 11, bundleID: "com.example.target", name: "Bundle Collision", sellerName: nil),
            SearchRankingItem(position: 2, appStoreID: 99, bundleID: "com.example.target", name: "Target", sellerName: nil)
        ]

        #expect(RankingMatcher.rank(for: trackedApp, in: results) == 2)
    }

    @Test
    func fallsBackToBundleIDWhenNeeded() {
        let trackedApp = TrackedApp(
            appStoreID: 99,
            bundleID: "com.example.target",
            name: "Target",
            sellerName: "Example",
            defaultPlatform: .iphone
        )

        let results = [
            SearchRankingItem(position: 1, appStoreID: 11, bundleID: "com.example.other", name: "Other", sellerName: nil),
            SearchRankingItem(position: 2, appStoreID: 12, bundleID: "com.example.target", name: "Target Bundle", sellerName: nil)
        ]

        #expect(RankingMatcher.rank(for: trackedApp, in: results) == 2)
    }

    @Test
    func returnsNilWhenAppIsMissingFromResults() {
        let trackedApp = TrackedApp(
            appStoreID: 99,
            bundleID: "com.example.target",
            name: "Target",
            sellerName: "Example",
            defaultPlatform: .iphone
        )

        let results = [
            SearchRankingItem(position: 1, appStoreID: 11, bundleID: "com.example.other", name: "Other", sellerName: nil)
        ]

        #expect(RankingMatcher.rank(for: trackedApp, in: results) == nil)
    }

    @Test
    func keywordHighlightRangesMatchPhraseAndWords() {
        let value = "Flight Tracker: live plane status"
        let matches = value.keywordHighlightRanges(of: "flight status").map { String(value[$0]) }

        #expect(matches == ["Flight", "status"])
    }

    @Test
    func keywordHighlightRangesMergePhraseAndWordOverlap() {
        let value = "Live Flight Tracker and flight alerts"
        let matches = value.keywordHighlightRanges(of: "flight tracker").map { String(value[$0]) }

        #expect(matches == ["Flight Tracker", "flight"])
    }

    @Test
    func keywordHighlightRangesDoNotMatchPartialWords() {
        let value = "Flighty has flight status"
        let matches = value.keywordHighlightRanges(of: "fly").map { String(value[$0]) }

        #expect(matches.isEmpty)
    }

    @Test
    func keywordHighlightRangesMatchSingularAndPluralWords() {
        let pluralValue = "Screen Limits and App Blocker"
        let pluralMatches = pluralValue.keywordHighlightRanges(of: "app limit").map { String(pluralValue[$0]) }

        #expect(pluralMatches == ["Limits", "App"])

        let singularValue = "Set a daily limit"
        let singularMatches = singularValue.keywordHighlightRanges(of: "app limits").map { String(singularValue[$0]) }

        #expect(singularMatches == ["limit"])
    }

    @Test
    func keywordHighlightRangesMatchCommonPluralForms() {
        let value = "Sleep stories and focus boxes"
        let matches = value.keywordHighlightRanges(of: "story box").map { String(value[$0]) }

        #expect(matches == ["stories", "boxes"])
    }
}
