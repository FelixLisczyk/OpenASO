import Foundation
import MCP
import SwiftData
import Testing
@testable import OpenASO

@MainActor
struct OpenASOMCPRuntimeTests {
    @Test
    func stdioWiringDeliversRealPopularityWhenAppleAdsSessionIsConfigured() async throws {
        let context = try RuntimeTestContext(appStoreID: 123, term: "calorie tracker")
        let webSessionStore = AppleAdsWebSessionStore(keychain: InMemoryKeychainService())
        try webSessionStore.save(
            AppleAdsWebSession(cookieHeader: "cookie=value; XSRF-TOKEN-CM=token", xsrfToken: "token", updatedAt: .now)
        )
        let settingsStore = AppSettingsStore(defaults: UserDefaults(suiteName: "com.thirdtech.openaso.runtime.tests.\(UUID().uuidString)") ?? .standard)
        settingsStore.savePopularityContextAppStoreID(999)
        let keywordMetricsService = KeywordMetricsService(
            httpClient: MockHTTPClient { request in
                let payload = """
                {"status":"success","data":[{"name":"calorie tracker","popularity":57}]}
                """
                return (Data(payload.utf8), makeHTTPURLResponse(url: try #require(request.url), statusCode: 200))
            },
            credentialStore: AppleAdsCredentialStore(keychain: InMemoryKeychainService()),
            settingsStore: settingsStore,
            webSessionStore: webSessionStore
        )

        let server = try await OpenASOMCPRuntime.makeServer(
            isStoredInMemoryOnly: true,
            backgroundModelStore: context.backgroundModelStore,
            appleAdsDependenciesFactory: {
                OpenASOMCPRuntime.AppleAdsMCPDependencies(
                    keywordMetricsService: keywordMetricsService,
                    popularityContextAppStoreIDProvider: { settingsStore.popularityContextAppStoreID },
                    appleAdsWebSessionProvider: { webSessionStore.session }
                )
            }
        )

        let refresh = try await context.callRefreshKeywordMetrics(on: server)
        #expect(refresh.outcomes.first?.error == nil)
        #expect(refresh.outcomes.first?.track.popularityScore == 57)
    }

    @Test
    func stdioWiringReturnsSensibleMessageWhenNoAppleAdsSessionIsConfigured() async throws {
        let context = try RuntimeTestContext(appStoreID: 123, term: "calorie tracker")

        let server = try await OpenASOMCPRuntime.makeServer(
            isStoredInMemoryOnly: true,
            backgroundModelStore: context.backgroundModelStore,
            appleAdsDependenciesFactory: {
                OpenASOMCPRuntime.AppleAdsMCPDependencies(
                    keywordMetricsService: KeywordMetricsService(
                        httpClient: MockHTTPClient { request in
                            Issue.record("Unexpected Apple Ads request to \(request.url?.absoluteString ?? "unknown URL")")
                            throw OpenASOError.providerUnavailable("Unexpected request")
                        },
                        credentialStore: AppleAdsCredentialStore(keychain: InMemoryKeychainService()),
                        settingsStore: AppSettingsStore(defaults: UserDefaults(suiteName: "com.thirdtech.openaso.runtime.tests.\(UUID().uuidString)") ?? .standard),
                        webSessionStore: AppleAdsWebSessionStore(keychain: InMemoryKeychainService())
                    ),
                    popularityContextAppStoreIDProvider: { nil },
                    appleAdsWebSessionProvider: { nil }
                )
            }
        )

        let refresh = try await context.callRefreshKeywordMetrics(on: server)
        #expect(refresh.outcomes.first?.error != nil)
        #expect(refresh.outcomes.first?.track.popularityScore == nil)
    }

    @Test
    func makeServerWithNoOverridesUsesRealDefaultsAndRespondsToListTools() async throws {
        let server = try await OpenASOMCPRuntime.makeServer(isStoredInMemoryOnly: true)
        let client = Client(name: "OpenASO MCP Runtime Smoke Test Client", version: "1.0")
        let transports = await InMemoryTransport.createConnectedPair()

        try await server.start(transport: transports.server)
        defer {
            Task {
                await client.disconnect()
                await server.stop()
            }
        }

        _ = try await client.connect(transport: transports.client)
        let tools = try await client.listTools().tools
        #expect(tools.map(\.name).contains("refresh_keyword_metrics"))
    }
}

@MainActor
private struct RuntimeTestContext {
    let backgroundModelStore: BackgroundModelStore

    init(appStoreID: Int64, term: String) throws {
        let container = try ModelContainerFactory.makeModelContainer(isStoredInMemoryOnly: true)
        let modelContext = ModelContext(container)
        let trackedApp = TrackedApp(
            appStoreID: appStoreID,
            bundleID: nil,
            name: "Test App",
            sellerName: nil,
            defaultPlatform: .iphone
        )
        let query = try KeywordQuery.fetchOrInsert(term: term, storefront: "us", platform: .iphone, in: modelContext)
        let track = TrackedAppKeyword(term: term, storefront: "us", platform: .iphone, trackedApp: trackedApp, query: query)
        trackedApp.keywordTracks.append(track)
        modelContext.insert(trackedApp)
        modelContext.insert(track)
        try modelContext.save()
        self.backgroundModelStore = BackgroundModelStore(modelContainer: container)
    }

    func callRefreshKeywordMetrics(on server: Server) async throws -> OpenASOMCPKeywordRefreshResult {
        let client = Client(name: "OpenASO MCP Runtime Test Client", version: "1.0")
        let transports = await InMemoryTransport.createConnectedPair()

        try await server.start(transport: transports.server)
        defer {
            Task {
                await client.disconnect()
                await server.stop()
            }
        }

        _ = try await client.connect(transport: transports.client)
        let result = try await client.callTool(name: "refresh_keyword_metrics", arguments: ["appStoreID": 123])
        #expect(result.isError == nil)
        let json = try #require(result.content.first?.runtimeTestTextValue)
        return try JSONDecoder.openASOMCPRuntimeTest.decode(OpenASOMCPKeywordRefreshResult.self, from: Data(json.utf8))
    }
}

private extension Tool.Content {
    var runtimeTestTextValue: String? {
        if case .text(let text, _, _) = self {
            return text
        }
        return nil
    }
}

private extension JSONDecoder {
    static var openASOMCPRuntimeTest: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
