import Foundation
import SwiftData
import Testing
@testable import OpenASO

@MainActor
struct KeywordMetricsServiceTests {
    @Test
    func failedRefreshPreservesExistingPopularityScoreAndUpdatedAt() async throws {
        let container = try ModelContainerFactory.makeModelContainer(isStoredInMemoryOnly: true)
        let modelContext = ModelContext(container)
        let services = AppServices.mocked(
            httpClient: MockHTTPClient { request in
                let payload = """
                <html><body>Sign in</body></html>
                """
                return (
                    Data(payload.utf8),
                    makeHTTPURLResponse(url: try #require(request.url), statusCode: 200)
                )
            },
            modelContainer: container
        )
        services.settingsStore.savePopularityContextAppStoreID(123_456_789)
        try services.appleAdsWebSessionStore.save(
            AppleAdsWebSession(cookieHeader: "cookie=value; XSRF-TOKEN-CM=token", xsrfToken: "token", updatedAt: .now)
        )

        let trackedApp = TrackedApp(appStoreID: 1, bundleID: nil, name: "App", sellerName: nil, defaultPlatform: .iphone)
        let query = try KeywordQuery.fetchOrInsert(term: "focus app", storefront: "us", platform: .iphone, in: modelContext)
        let track = TrackedAppKeyword(term: "focus app", storefront: "us", platform: .iphone, trackedApp: trackedApp, query: query)
        let previousUpdatedAt = try #require(Calendar.current.date(byAdding: .day, value: -8, to: .now))
        let metrics = KeywordDailyMetric(
            queryKey: track.queryKey,
            keyword: track.term,
            storefront: track.storefront,
            platform: track.platform,
            popularityScore: 72,
            difficultyScore: nil,
            source: .appleAdsPopularity,
            updatedAt: previousUpdatedAt
        )

        trackedApp.keywordTracks.append(track)
        modelContext.insert(trackedApp)
        modelContext.insert(track)
        modelContext.insert(metrics)
        try modelContext.save()

        _ = await services.keywordMetricsService.refreshMetrics(for: trackedApp, tracks: [track], in: modelContext)

        #expect(metrics.popularityScore == 72)
        #expect(metrics.updatedAt == previousUpdatedAt)
        #expect(track.statusMessage == "Popularity failed to fetch. Apple Ads web session expired. Refresh it in Settings.")
    }

    @Test
    func failedFirstRefreshLeavesPopularityNilAndStoresStatus() async throws {
        let container = try ModelContainerFactory.makeModelContainer(isStoredInMemoryOnly: true)
        let modelContext = ModelContext(container)
        let services = AppServices.mocked(
            httpClient: MockHTTPClient { request in
                Issue.record("Unexpected request to \(request.url?.absoluteString ?? "unknown URL")")
                throw OpenASOError.providerUnavailable("Unexpected request")
            },
            modelContainer: container
        )

        let trackedApp = TrackedApp(appStoreID: 1, bundleID: nil, name: "App", sellerName: nil, defaultPlatform: .iphone)
        let query = try KeywordQuery.fetchOrInsert(term: "focus app", storefront: "us", platform: .iphone, in: modelContext)
        let track = TrackedAppKeyword(term: "focus app", storefront: "us", platform: .iphone, trackedApp: trackedApp, query: query)
        trackedApp.keywordTracks.append(track)
        modelContext.insert(trackedApp)
        modelContext.insert(track)
        try modelContext.save()

        _ = await services.keywordMetricsService.refreshMetrics(for: trackedApp, tracks: [track], in: modelContext)
        let storedMetrics = try #require(try modelContext.fetch(FetchDescriptor<KeywordDailyMetric>()).first)

        #expect(storedMetrics.popularityScore == nil)
        #expect(track.statusMessage == "Popularity failed to fetch. Reconnect Apple Ads in Settings so OpenASO can detect a linked app.")
    }

    @Test
    func resolveDefaultAppleAdsAppReturnsFirstCampaignLinkedApp() async throws {
        let services = AppServices.mocked(
            httpClient: MockHTTPClient { request in
                let url = try #require(request.url)
                if url.host == "appleid.apple.com" {
                    return (
                        Data(#"{"access_token":"token"}"#.utf8),
                        makeHTTPURLResponse(url: url, statusCode: 200)
                    )
                }

                if url.path == "/api/v5/acls" {
                    return (
                        Data(#"{"data":[{"orgId":12345}]}"#.utf8),
                        makeHTTPURLResponse(url: url, statusCode: 200)
                    )
                }

                if url.path == "/api/v5/campaigns" {
                    #expect(request.value(forHTTPHeaderField: "X-AP-Context") == "orgId=12345")
                    let payload = """
                    {
                      "data": [
                        {
                          "adamId": 6448311069,
                          "appName": "Atten",
                          "countriesOrRegions": ["US"],
                          "deleted": false
                        }
                      ]
                    }
                    """
                    return (
                        Data(payload.utf8),
                        makeHTTPURLResponse(url: url, statusCode: 200)
                    )
                }

                Issue.record("Unexpected request to \(url.absoluteString)")
                throw OpenASOError.providerUnavailable("Unexpected request")
            }
        )

        let app = try await services.keywordMetricsService.resolveDefaultAppleAdsApp(
            using: AppleAdsCredentials(
                clientID: "client",
                teamID: "team",
                keyID: "key",
                privateKey: Self.privateKey,
                orgID: ""
            )
        )

        #expect(app.adamId == 6_448_311_069)
        #expect(app.appName == "Atten")
    }

    @Test
    func webSessionResolvesDefaultAppleAdsAppWithoutAPICredentials() async throws {
        let services = AppServices.mocked(
            httpClient: MockHTTPClient { request in
                let url = try #require(request.url)
                #expect(url.host == "app-ads.apple.com")
                #expect(url.path == "/reporting/graphql")
                #expect(request.httpMethod == "POST")
                #expect(request.value(forHTTPHeaderField: "Cookie") == "searchads.soid=session")
                #expect(request.value(forHTTPHeaderField: "X-XSRF-TOKEN-CM") == "xsrf")

                let payload = """
                {
                  "data": {
                    "reportingV5": {
                      "getReportsByCampaign": {
                        "row": [
                          {
                            "metadata": {
                              "countriesOrRegions": ["GB"],
                              "app": {
                                "adamId": "6608976383",
                                "appName": "Atten - App Blocker"
                              }
                            }
                          }
                        ]
                      }
                    }
                  }
                }
                """
                return (
                    Data(payload.utf8),
                    makeHTTPURLResponse(url: url, statusCode: 200)
                )
            }
        )
        try services.appleAdsWebSessionStore.save(
            AppleAdsWebSession(
                cookieHeader: "searchads.soid=session",
                xsrfToken: "xsrf",
                updatedAt: .now
            )
        )

        let app = try await services.appleAdsWebSessionManager.resolveDefaultLinkedApp()

        #expect(app.adamId == 6_608_976_383)
        #expect(app.appName == "Atten - App Blocker")
        #expect(app.countryOrRegionCodes == ["GB"])
    }

    @Test
    func webSessionFallsBackToSellerAppsWhenCampaignEndpointFails() async throws {
        let services = AppServices.mocked(
            httpClient: MockHTTPClient { request in
                let url = try #require(request.url)
                if url.host == "app-ads.apple.com" {
                    return (
                        Data("<html>Internal Server Error</html>".utf8),
                        makeHTTPURLResponse(url: url, statusCode: 500)
                    )
                }

                #expect(url.host == "itunes.apple.com")
                #expect(url.path == "/search")
                #expect(url.query?.contains("Third%20Tech%20Ltd") == true)
                let payload = """
                {
                  "resultCount": 2,
                  "results": [
                    {
                      "trackId": 6608976383,
                      "trackName": "Atten - App Blocker",
                      "sellerName": "Third Tech Ltd"
                    },
                    {
                      "trackId": 1485115388,
                      "trackName": "Rusty Blower 3D",
                      "sellerName": "Zplay (Beijing) Info. Tech. Co.,Ltd."
                    }
                  ]
                }
                """
                return (
                    Data(payload.utf8),
                    makeHTTPURLResponse(url: url, statusCode: 200)
                )
            }
        )
        try services.appleAdsWebSessionStore.save(
            AppleAdsWebSession(
                cookieHeader: "searchads.soid=session",
                xsrfToken: "xsrf",
                updatedAt: .now,
                accountName: "Third Tech Ltd"
            )
        )

        let app = try await services.appleAdsWebSessionManager.resolveDefaultLinkedApp()

        #expect(app.adamId == 6_608_976_383)
        #expect(app.appName == "Atten - App Blocker")
    }

    @Test
    func successfulRefreshStoresPopularityAndClearsPriorStatus() async throws {
        let container = try ModelContainerFactory.makeModelContainer(isStoredInMemoryOnly: true)
        let modelContext = ModelContext(container)
        let services = AppServices.mocked(
            httpClient: MockHTTPClient { request in
                let payload = """
                {
                  "status": "success",
                  "data": [
                    {"name": "focus app", "popularity": 88}
                  ]
                }
                """
                return (
                    Data(payload.utf8),
                    makeHTTPURLResponse(url: try #require(request.url), statusCode: 200)
                )
            },
            modelContainer: container
        )
        services.settingsStore.savePopularityContextAppStoreID(123_456_789)
        try services.appleAdsWebSessionStore.save(
            AppleAdsWebSession(cookieHeader: "cookie=value; XSRF-TOKEN-CM=token", xsrfToken: "token", updatedAt: .now)
        )

        let trackedApp = TrackedApp(appStoreID: 1, bundleID: nil, name: "App", sellerName: nil, defaultPlatform: .iphone)
        let query = try KeywordQuery.fetchOrInsert(term: "focus app", storefront: "us", platform: .iphone, in: modelContext)
        let track = TrackedAppKeyword(term: "focus app", storefront: "us", platform: .iphone, trackedApp: trackedApp, query: query)
        track.statusMessage = "Popularity failed to fetch. Connect an Apple Ads web session in Settings."
        trackedApp.keywordTracks.append(track)
        modelContext.insert(trackedApp)
        modelContext.insert(track)
        try modelContext.save()

        _ = await services.keywordMetricsService.refreshMetrics(for: trackedApp, tracks: [track], in: modelContext)
        let storedMetrics = try #require(try modelContext.fetch(FetchDescriptor<KeywordDailyMetric>()).first)

        #expect(storedMetrics.popularityScore == 88)
        #expect(track.statusMessage == nil)
    }

    @Test
    func unsupportedAppleAdsStorefrontDoesNotAskForSetup() async throws {
        let container = try ModelContainerFactory.makeModelContainer(isStoredInMemoryOnly: true)
        let modelContext = ModelContext(container)
        let services = AppServices.mocked(
            httpClient: MockHTTPClient { request in
                (
                    Data(#"{"error":{"errors":[{"message":"Bad request"}]}}"#.utf8),
                    makeHTTPURLResponse(url: try #require(request.url), statusCode: 400)
                )
            },
            modelContainer: container
        )
        services.settingsStore.savePopularityContextAppStoreID(123_456_789)
        try services.appleAdsWebSessionStore.save(
            AppleAdsWebSession(cookieHeader: "cookie=value; XSRF-TOKEN-CM=token", xsrfToken: "token", updatedAt: .now)
        )

        let trackedApp = TrackedApp(appStoreID: 1, bundleID: nil, name: "App", sellerName: nil, defaultPlatform: .iphone)
        let query = try KeywordQuery.fetchOrInsert(term: "focus app", storefront: "ao", platform: .iphone, in: modelContext)
        let track = TrackedAppKeyword(term: "focus app", storefront: "ao", platform: .iphone, trackedApp: trackedApp, query: query)
        trackedApp.keywordTracks.append(track)
        modelContext.insert(trackedApp)
        modelContext.insert(track)
        try modelContext.save()

        _ = await services.keywordMetricsService.refreshMetrics(for: trackedApp, tracks: [track], in: modelContext)

        #expect(track.statusMessage == "Popularity unavailable. Apple Ads does not support keyword popularity in Angola.")
        let storedMetrics = try #require(try modelContext.fetch(FetchDescriptor<KeywordDailyMetric>()).first)
        let row = KeywordWorkspaceRow(
            track: track,
            storefront: nil,
            metrics: storedMetrics,
            latestSnapshot: Optional<KeywordRankingCrawlSummary>.none,
            trendSnapshots: [KeywordRankingCrawlSummary](),
            rankingApps: [KeywordRankingAppSummary]()
        )
        #expect(row.popularityIndicatorState == .unavailable(message: "Popularity unavailable. Apple Ads does not support keyword popularity in Angola."))
    }

    @Test
    func connectionRefreshOnlyFetchesMissingAndStalePopularityMetrics() async throws {
        let container = try ModelContainerFactory.makeModelContainer(isStoredInMemoryOnly: true)
        let modelContext = ModelContext(container)
        var requestedTerms: [String] = []
        let services = AppServices.mocked(
            httpClient: MockHTTPClient { request in
                let body = try #require(request.httpBody)
                let payload = try JSONDecoder().decode(KeywordPopularityRequestBody.self, from: body)
                requestedTerms.append(contentsOf: payload.terms)

                let response = """
                {
                  "status": "success",
                  "data": [
                    {"name": "missing", "popularity": 81},
                    {"name": "stale", "popularity": 67}
                  ]
                }
                """
                return (
                    Data(response.utf8),
                    makeHTTPURLResponse(url: try #require(request.url), statusCode: 200)
                )
            },
            modelContainer: container
        )

        let trackedApp = TrackedApp(appStoreID: 1, bundleID: nil, name: "App", sellerName: nil, defaultPlatform: .iphone)
        modelContext.insert(trackedApp)
        let freshTrack = try makeTrack(term: "fresh", trackedApp: trackedApp, in: modelContext)
        let staleTrack = try makeTrack(term: "stale", trackedApp: trackedApp, in: modelContext)
        _ = try makeTrack(term: "missing", trackedApp: trackedApp, in: modelContext)
        let staleUpdatedAt = try #require(Calendar.current.date(byAdding: .day, value: -8, to: .now))
        let freshUpdatedAt = try #require(Calendar.current.date(byAdding: .day, value: -1, to: .now))
        modelContext.insert(
            KeywordDailyMetric(
                queryKey: freshTrack.queryKey,
                keyword: freshTrack.term,
                storefront: freshTrack.storefront,
                platform: freshTrack.platform,
                popularityScore: 91,
                difficultyScore: nil,
                source: .appleAdsPopularity,
                updatedAt: freshUpdatedAt
            )
        )
        modelContext.insert(
            KeywordDailyMetric(
                queryKey: staleTrack.queryKey,
                keyword: staleTrack.term,
                storefront: staleTrack.storefront,
                platform: staleTrack.platform,
                popularityScore: 12,
                difficultyScore: nil,
                source: .appleAdsPopularity,
                updatedAt: staleUpdatedAt
            )
        )
        try modelContext.save()

        let backgroundModelStore = try #require(services.backgroundModelStore)
        let outcomes = try await services.keywordMetricsService.refreshStalePopularityMetrics(
            popularityContextAppStoreID: 123_456_789,
            webSession: AppleAdsWebSession(cookieHeader: "cookie=value; XSRF-TOKEN-CM=token", xsrfToken: "token", updatedAt: .now),
            using: backgroundModelStore
        )
        let storedScores = try await backgroundModelStore.read { modelContext in
            let metrics = try modelContext.fetch(FetchDescriptor<KeywordDailyMetric>())
            return Dictionary(uniqueKeysWithValues: metrics.map { ($0.keyword, $0.popularityScore) })
        }

        #expect(outcomes.count == 2)
        #expect(Set(requestedTerms) == ["missing", "stale"])
        #expect(!requestedTerms.contains("fresh"))
        #expect(storedScores["fresh"] == 91)
        #expect(storedScores["stale"] == 67)
        #expect(storedScores["missing"] == 81)
    }

    @Test
    func popularityIndicatorStateIsExclusive() throws {
        let container = try ModelContainerFactory.makeModelContainer(isStoredInMemoryOnly: true)
        let modelContext = ModelContext(container)
        let now = try #require(Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: 3, hour: 12)))
        let trackedApp = TrackedApp(appStoreID: 1, bundleID: nil, name: "App", sellerName: nil, defaultPlatform: .iphone)
        modelContext.insert(trackedApp)

        let freshRow = makeRow(
            term: "fresh",
            trackedApp: trackedApp,
            modelContext: modelContext,
            popularityScore: 80,
            updatedAt: try #require(Calendar.current.date(byAdding: .day, value: -6, to: now)),
            statusMessage: nil
        )
        let staleUpdatedAt = try #require(Calendar.current.date(byAdding: .day, value: -7, to: now))
        let staleRow = makeRow(
            term: "stale",
            trackedApp: trackedApp,
            modelContext: modelContext,
            popularityScore: 70,
            updatedAt: staleUpdatedAt,
            statusMessage: "Popularity failed to fetch. Apple Ads web session expired. Refresh it in Settings."
        )
        let needsSetupRow = makeRow(
            term: "needs setup",
            trackedApp: trackedApp,
            modelContext: modelContext,
            popularityScore: nil,
            updatedAt: now,
            statusMessage: "Popularity failed to fetch. Connect an Apple Ads web session in Settings."
        )

        #expect(freshRow.popularityIndicatorState(now: now) == .none)
        #expect(staleRow.popularityIndicatorState(now: now) == .stale(lastUpdatedAt: staleUpdatedAt))
        #expect(needsSetupRow.popularityIndicatorState(now: now) == .needsSetup(message: "Popularity failed to fetch. Connect an Apple Ads web session in Settings."))
    }

    @Test
    func keywordMetricsRecoverAfterTransientKeychainReadFailure() async throws {
        let container = try ModelContainerFactory.makeModelContainer(isStoredInMemoryOnly: true)
        let modelContext = ModelContext(container)
        let defaults = UserDefaults(suiteName: "com.thirdtech.openaso.keychain-recovery.tests.\(UUID().uuidString)") ?? .standard
        let keychain = InMemoryKeychainService()

        let seedWebSessionStore = AppleAdsWebSessionStore(defaults: defaults, keychain: keychain)
        try seedWebSessionStore.save(
            AppleAdsWebSession(cookieHeader: "cookie=value; XSRF-TOKEN-CM=token", xsrfToken: "token", updatedAt: .now)
        )
        keychain.failNextReads(1)

        let services = AppServices(
            httpClient: MockHTTPClient { request in
                let payload = """
                {"status":"success","data":[{"name":"focus app","popularity":41}]}
                """
                return (Data(payload.utf8), makeHTTPURLResponse(url: try #require(request.url), statusCode: 200))
            },
            defaults: defaults,
            keychain: keychain,
            loadsEnvironmentCredentials: false,
            allowsIconNetworkFetches: false,
            backgroundModelStore: BackgroundModelStore(modelContainer: container)
        )
        services.settingsStore.savePopularityContextAppStoreID(123_456_789)

        let trackedApp = TrackedApp(appStoreID: 1, bundleID: nil, name: "App", sellerName: nil, defaultPlatform: .iphone)
        let query = try KeywordQuery.fetchOrInsert(term: "focus app", storefront: "us", platform: .iphone, in: modelContext)
        let track = TrackedAppKeyword(term: "focus app", storefront: "us", platform: .iphone, trackedApp: trackedApp, query: query)
        trackedApp.keywordTracks.append(track)
        modelContext.insert(trackedApp)
        modelContext.insert(track)
        try modelContext.save()

        let firstOutcomes = await services.keywordMetricsService.refreshMetrics(for: trackedApp, tracks: [track], in: modelContext)
        #expect(firstOutcomes.first?.errorMessage?.contains("Connect an Apple Ads web session") == true)

        let secondOutcomes = await services.keywordMetricsService.refreshMetrics(for: trackedApp, tracks: [track], in: modelContext)
        #expect(secondOutcomes.first?.errorMessage == nil)
        #expect(track.statusMessage == nil)

        let storedMetrics = try modelContext.fetch(FetchDescriptor<KeywordDailyMetric>())
        #expect(storedMetrics.first?.popularityScore == 41)
    }

    private func makeRow(
        term: String,
        trackedApp: TrackedApp,
        modelContext: ModelContext,
        popularityScore: Int?,
        updatedAt: Date,
        statusMessage: String?
    ) -> KeywordWorkspaceRow {
        let query = try! KeywordQuery.fetchOrInsert(term: term, storefront: "us", platform: .iphone, in: modelContext)
        let track = TrackedAppKeyword(term: term, storefront: "us", platform: .iphone, trackedApp: trackedApp, query: query)
        track.statusMessage = statusMessage
        let metrics = KeywordDailyMetric(
            queryKey: track.queryKey,
            keyword: track.term,
            storefront: track.storefront,
            platform: track.platform,
            popularityScore: popularityScore,
            difficultyScore: nil,
            source: .appleAdsPopularity,
            updatedAt: updatedAt
        )

        trackedApp.keywordTracks.append(track)
        modelContext.insert(track)
        modelContext.insert(metrics)

        return KeywordWorkspaceRow(
            track: track,
            storefront: nil,
            metrics: metrics,
            latestSnapshot: Optional<KeywordRankingCrawlSummary>.none,
            trendSnapshots: [KeywordRankingCrawlSummary](),
            rankingApps: [KeywordRankingAppSummary]()
        )
    }

    private func makeTrack(
        term: String,
        trackedApp: TrackedApp,
        in modelContext: ModelContext
    ) throws -> TrackedAppKeyword {
        let query = try KeywordQuery.fetchOrInsert(term: term, storefront: "us", platform: .iphone, in: modelContext)
        let track = TrackedAppKeyword(term: term, storefront: "us", platform: .iphone, trackedApp: trackedApp, query: query)
        trackedApp.keywordTracks.append(track)
        modelContext.insert(track)
        return track
    }

    private struct KeywordPopularityRequestBody: Decodable {
        let terms: [String]
    }

    private static let privateKey = """
    -----BEGIN EC PRIVATE KEY-----
    MHcCAQEEIM2/+v/sUp+rKfUFKSaY3cDxp3E9Azvop6KV9VmlWgJ+oAoGCCqGSM49
    AwEHoUQDQgAETxX0A2qcgToC8eMpiyHyaM6G3/pdF4LcTCOd6W++qk7nO0Yjhnf3
    +JXc/3El4VXTjD1ZNEqLxFWE1tLOktEQMg==
    -----END EC PRIVATE KEY-----
    """
}
