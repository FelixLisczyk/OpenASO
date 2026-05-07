import SwiftData
import SwiftUI

@main
struct OpenASOApp: App {
    @State private var services: AppServices
    @State private var updaterController = SparkleUpdaterController()
    @State private var launchAlert: AppLaunchAlertContext?

    private let modelContainer: ModelContainer

    init() {
        let modelContainer = Self.makeModelContainer()
        let services = AppServices.appLaunch(modelContainer: modelContainer)
        self.modelContainer = modelContainer
        _services = State(initialValue: services)
        _launchAlert = State(initialValue: nil)
    }

    private static func makeModelContainer() -> ModelContainer {
        do {
            return try ModelContainerFactory.makeModelContainer(isStoredInMemoryOnly: false)
        } catch {
            fatalError("Failed to create model container: \(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup("OpenASO") {
            RootView()
                .environment(services)
                .frame(minWidth: 1000, minHeight: 760)
                .task {
                    services.analyticsService.capture(.appLaunched())
                    await services.prepareBackgroundModelStore()
                    launchAlert = await Self.seedStorefrontCatalogIfNeeded(using: services)
                }
                .alert(item: $launchAlert) { alert in
                    Alert(
                        title: Text(alert.title),
                        message: Text(alert.message),
                        dismissButton: .default(Text("OK"))
                    )
                }
        }
        .modelContainer(modelContainer)

        Settings {
            SettingsView()
                .environment(services)
                .modelContainer(modelContainer)
        }

        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates...", action: updaterController.checkForUpdates)
                    .keyboardShortcut("u", modifiers: [.command, .option])
            }
        }
    }

    private static func seedStorefrontCatalogIfNeeded(using services: AppServices) async -> AppLaunchAlertContext? {
        do {
            guard let backgroundModelStore = services.backgroundModelStore else {
                throw OpenASOError.providerUnavailable("The background model store is unavailable.")
            }

            try await services.storefrontCatalog.seedIfNeeded(using: backgroundModelStore)
            return nil
        } catch {
            return AppLaunchAlertContext(
                title: "Country List Failed",
                message: OpenASOError.map(error).localizedDescription
            )
        }
    }
}

private struct AppLaunchAlertContext: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
