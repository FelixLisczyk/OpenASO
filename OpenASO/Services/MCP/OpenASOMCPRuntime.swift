import Foundation
import MCP

enum OpenASOMCPRuntime {
    struct AppleAdsMCPDependencies: Sendable {
        let keywordMetricsService: KeywordMetricsService
        let popularityContextAppStoreIDProvider: @MainActor @Sendable () -> Int64?
        let appleAdsWebSessionProvider: @MainActor @Sendable () -> AppleAdsWebSession?
    }

    static func makeServer(
        configuration: OpenASOMCPServerConfiguration = OpenASOMCPServerConfiguration(),
        isStoredInMemoryOnly: Bool = false,
        backgroundModelStore providedBackgroundModelStore: BackgroundModelStore? = nil,
        appleAdsDependenciesFactory: @escaping @MainActor @Sendable () async -> AppleAdsMCPDependencies =
            OpenASOMCPRuntime.makeDefaultAppleAdsDependencies
    ) async throws -> Server {
        let backgroundModelStore: BackgroundModelStore
        if let providedBackgroundModelStore {
            backgroundModelStore = providedBackgroundModelStore
        } else {
            let modelContainer = try ModelContainerFactory.makeModelContainer(isStoredInMemoryOnly: isStoredInMemoryOnly)
            backgroundModelStore = BackgroundModelStore(modelContainer: modelContainer)
        }
        let httpClient = URLSessionHTTPClient()
        let appResolver = DefaultAppResolver(httpClient: httpClient)
        let appCatalogService = AppCatalogService(appResolver: appResolver)
        let rankingProvider = ITunesSearchFallbackProvider(httpClient: httpClient)
        let rankingRefreshCoordinator = await RankingRefreshCoordinator(
            rankingProvider: rankingProvider,
            appCatalogService: appCatalogService
        )
        let reviewService = AppStorefrontReviewService(httpClient: httpClient)
        let appleAdsDependencies = await appleAdsDependenciesFactory()
        let mcpService = OpenASOMCPService(
            backgroundModelStore: backgroundModelStore,
            appResolver: appResolver,
            appCatalogService: appCatalogService,
            httpClient: httpClient,
            screenshotDownloadService: ScreenshotDownloadService(),
            rankingProvider: rankingProvider,
            rankingRefreshCoordinator: rankingRefreshCoordinator,
            reviewService: reviewService,
            keywordMetricsService: appleAdsDependencies.keywordMetricsService,
            popularityContextAppStoreIDProvider: appleAdsDependencies.popularityContextAppStoreIDProvider,
            appleAdsWebSessionProvider: appleAdsDependencies.appleAdsWebSessionProvider
        )

        return await OpenASOMCPServerFactory(
            service: mcpService,
            configuration: configuration
        ).makeServer()
    }

    static func runStdio(
        configuration: OpenASOMCPServerConfiguration = OpenASOMCPServerConfiguration()
    ) async throws {
        let server = try await makeServer(configuration: configuration)
        let transport = StdioTransport()
        try await server.start(transport: transport)
        await server.waitUntilCompleted()
    }

    // Builds only the 4 dependencies `refresh_keyword_metrics` needs. Deliberately does not
    // replicate all of AppServices (AnalyticsService, AppleAdsWebSessionManager,
    // AppStoreConnectCredentialStore, etc. are GUI/analytics-only concerns with no bearing here).
    @MainActor
    static func makeDefaultAppleAdsDependencies() async -> AppleAdsMCPDependencies {
        let credentialStore = AppleAdsCredentialStore(keychain: SystemKeychainService(), namespace: .current)
        let settingsStore = AppSettingsStore(defaults: .openASOShared)
        let webSessionStore = AppleAdsWebSessionStore(keychain: SystemKeychainService(), namespace: .current)
        let keywordMetricsService = KeywordMetricsService(
            httpClient: URLSessionHTTPClient(),
            credentialStore: credentialStore,
            settingsStore: settingsStore,
            webSessionStore: webSessionStore
        )
        return AppleAdsMCPDependencies(
            keywordMetricsService: keywordMetricsService,
            popularityContextAppStoreIDProvider: { settingsStore.popularityContextAppStoreID },
            appleAdsWebSessionProvider: { webSessionStore.session }
        )
    }
}
