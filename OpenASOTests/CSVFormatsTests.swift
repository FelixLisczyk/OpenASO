import Testing
@testable import OpenASO

struct CSVFormatsTests {
    @Test
    func keywordRowsRoundTripQuotedFieldsCommasAndNewlines() throws {
        let row = TrackedKeywordCSVRow(
            appName: "Writer, Pro",
            appID: "123",
            platform: "iOS",
            keyword: "notes \"daily\"\nplanner",
            storeDomain: "US",
            store: "United States",
            note: "line one\nline two, with comma",
            lastUpdate: "2026-05-04 10:00:00 +0000",
            ranking: "1",
            change: "-2",
            popularity: "90",
            difficulty: "33",
            appsInRanking: "50",
            tags: "productivity,\"focus\""
        )

        let csv = TrackedKeywordCSVFormat.encode(rows: [row])
        let decoded = try TrackedKeywordCSVFormat.decode(csv)

        #expect(decoded == [row])
    }

    @Test
    func keywordDecodeReportsMissingRequiredColumns() throws {
        let csv = """
        App Name,App Id,Platform,Store Domain,Store,Note,Last Update,Ranking,Change,Popularity,Difficulty,Apps in Ranking,Tags
        Test,123,iOS,US,United States,,,,,,,,
        """

        #expect(throws: CSVError.missingColumn("Keyword")) {
            _ = try TrackedKeywordCSVFormat.decode(csv)
        }
    }

    @Test
    func keywordDecodeAllowsRowsWithMissingTrailingValues() throws {
        let csv = """
        App Name,App Id,Platform,Keyword,Store Domain,Store,Note,Last Update,Ranking,Change,Popularity,Difficulty,Apps in Ranking,Tags
        Test,123,iOS,focus,US,United States
        """

        let decoded = try TrackedKeywordCSVFormat.decode(csv)

        #expect(decoded.count == 1)
        #expect(decoded[0].keyword == "focus")
        #expect(decoded[0].note == "")
        #expect(decoded[0].tags == "")
    }

    @Test
    func keywordDecodeAllowsMissingTagsColumn() throws {
        let csv = """
        App Name,App Id,Platform,Keyword,Store Domain,Store,Note,Last Update,Ranking,Change,Popularity,Difficulty,Apps in Ranking
        Test,123,iOS,focus,US,United States,,,,,,,
        """

        let decoded = try TrackedKeywordCSVFormat.decode(csv)

        #expect(decoded.count == 1)
        #expect(decoded[0].keyword == "focus")
        #expect(decoded[0].tags == "")
    }

    @Test
    func keywordDecodeAllowsMinimalKeywordAndStoreColumns() throws {
        let csv = """
        Keyword,Store Domain
        focus,US
        """

        let decoded = try TrackedKeywordCSVFormat.decode(csv)

        #expect(decoded.count == 1)
        #expect(decoded[0].keyword == "focus")
        #expect(decoded[0].storeDomain == "US")
        #expect(decoded[0].appID == "")
    }

    @Test
    func keywordDecodeAllowsKeywordAndCountryColumns() throws {
        let csv = """
        keyword,country
        focus,US
        """

        let decoded = try TrackedKeywordCSVFormat.decode(csv)

        #expect(decoded.count == 1)
        #expect(decoded[0].keyword == "focus")
        #expect(decoded[0].storeDomain == "US")
        #expect(decoded[0].appID == "")
    }

    @Test
    func keywordDecodeAllowsAppIDKeywordAndStoreColumns() throws {
        let csv = """
        App Id,Keyword,Store Domain
        123,focus,US
        """

        let decoded = try TrackedKeywordCSVFormat.decode(csv)

        #expect(decoded.count == 1)
        #expect(decoded[0].appID == "123")
        #expect(decoded[0].keyword == "focus")
        #expect(decoded[0].storeDomain == "US")
    }

    @Test
    func keywordDecodeAllowsAppIDKeywordAndCountryColumns() throws {
        let csv = """
        appid,keyword,country
        123,focus,US
        """

        let decoded = try TrackedKeywordCSVFormat.decode(csv)

        #expect(decoded.count == 1)
        #expect(decoded[0].appID == "123")
        #expect(decoded[0].keyword == "focus")
        #expect(decoded[0].storeDomain == "US")
    }

    @Test
    func keywordDecodeAllowsCarriageReturnLineEndings() throws {
        let csv = "App Name,App Id,Platform,Keyword,Store Domain,Store,Note,Last Update,Ranking,Change,Popularity,Difficulty,Apps in Ranking,Tags\rCal AI - Calorie Tracker,6480417616,iphone,ai calorie counter,us,United States,,2026-05-05 19:54:09 +0100,1,0,,,197,rank-verified\r"

        let decoded = try TrackedKeywordCSVFormat.decode(csv)

        #expect(decoded.count == 1)
        #expect(decoded[0].appID == "6480417616")
        #expect(decoded[0].keyword == "ai calorie counter")
        #expect(decoded[0].storeDomain == "us")
    }

    @Test
    func keywordDecodeKeepsUnescapedQuotesInsideUnquotedFieldsLiteral() throws {
        let csv = "App Name,App Id,Platform,Keyword,Store Domain,Store,Note,Last Update,Ranking,Change,Popularity,Difficulty,Apps in Ranking,Tags\r\nCal AI - Calorie Tracker,6480417616,iphone,ai \"calorie\" counter,us,United States,,2026-05-05 19:54:09 +0100,1,0,,,197,\r\nOtter AI,1276437113,iphone,meeting notes,us,United States,,2026-05-05 19:54:09 +0100,2,0,,,200,\r\n"

        let decoded = try TrackedKeywordCSVFormat.decode(csv)

        #expect(decoded.count == 2)
        #expect(decoded[0].keyword == "ai \"calorie\" counter")
        #expect(decoded[1].appName == "Otter AI")
        #expect(decoded[1].keyword == "meeting notes")
    }

    @Test
    func keywordDecodeAllowsDuplicateHeadersWithoutCrashing() throws {
        let csv = """
        App Name,App Id,Platform,Keyword,Keyword,Store Domain,Store,Note,Last Update,Ranking,Change,Popularity,Difficulty,Apps in Ranking,Tags
        Test,123,iOS,focus,ignored duplicate,US,United States,,,,,,,,
        """

        let decoded = try TrackedKeywordCSVFormat.decode(csv)

        #expect(decoded.count == 1)
        #expect(decoded[0].keyword == "focus")
    }

    @Test
    func keywordDecodeUsesLaterDuplicateHeaderWhenFirstValueIsBlank() throws {
        let csv = """
        App Name,App Id,Platform,Keyword,Keyword,Store Domain,Store,Note,Last Update,Ranking,Change,Popularity,Difficulty,Apps in Ranking,Tags
        Test,123,iOS,,focus,US,United States,,,,,,,,
        """

        let decoded = try TrackedKeywordCSVFormat.decode(csv)

        #expect(decoded.count == 1)
        #expect(decoded[0].keyword == "focus")
    }

    @Test
    func keywordDecodePreservesDuplicateRowsForImporterDecision() throws {
        let row = TrackedKeywordCSVRow(
            appName: "Test",
            appID: "123",
            platform: "iOS",
            keyword: "focus",
            storeDomain: "US",
            store: "United States",
            note: "",
            lastUpdate: "",
            ranking: "",
            change: "",
            popularity: "",
            difficulty: "",
            appsInRanking: "",
            tags: ""
        )

        let csv = TrackedKeywordCSVFormat.encode(rows: [row, row])
        let decoded = try TrackedKeywordCSVFormat.decode(csv)

        #expect(decoded == [row, row])
    }

    @Test
    func sharedEncoderEscapesRankingAndRatingsExportsConsistently() {
        let rankingCSV = KeywordRankingHistoryCSVFormat.encode(rows: [
            KeywordRankingHistoryCSVRow(
                appName: "Writer, Pro",
                appID: "123",
                platform: "iOS",
                keyword: "notes \"daily\"",
                storeDomain: "US",
                store: "United States",
                observedAt: "2026-05-04 10:00:00 +0000",
                ranking: "1",
                change: "",
                periodChange: "",
                popularity: "",
                difficulty: "",
                appsInRanking: "",
                source: "iTunes",
                error: "line one\nline two"
            )
        ])
        let ratingsCSV = RatingsCSVFormat.encode(rows: [
            RatingsCSVRow(
                appName: "Writer, Pro",
                appID: "123",
                storefront: "us",
                store: "United States",
                ratingCount: "1,234",
                ratingCountChange: "",
                averageRating: "4.9",
                averageRatingChange: "",
                ratingDate: "2026-05-04",
                observedAt: "2026-05-04 10:00:00 +0000",
                source: "lookup \"fallback\""
            )
        ])

        #expect(rankingCSV.contains(#""Writer, Pro""#))
        #expect(rankingCSV.contains(#""notes ""daily""""#))
        #expect(ratingsCSV.contains(#""Writer, Pro""#))
        #expect(ratingsCSV.contains(#""1,234""#))
        #expect(ratingsCSV.contains(#""lookup ""fallback""""#))
    }
}
