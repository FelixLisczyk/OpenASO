import Foundation
import SwiftData
import SwiftUI

struct PreviewHTTPClient: HTTPClient {
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        throw OpenASOError.providerUnavailable("Preview HTTP disabled")
    }
}

@MainActor
struct OpenASOPreviewContainer<SeedData> {
    let modelContainer: ModelContainer
    let seedData: SeedData

    init(seed: (ModelContext) throws -> SeedData) {
        do {
            let modelContainer = try ModelContainerFactory.makeModelContainer(isStoredInMemoryOnly: true)
            let seedData = try seed(modelContainer.mainContext)
            try modelContainer.mainContext.save()
            self.modelContainer = modelContainer
            self.seedData = seedData
        } catch {
            fatalError("Failed to create OpenASO preview container: \(error)")
        }
    }
}

private struct PreviewAppDependenciesModifier: ViewModifier {
    @State private var services: AppServices

    init(
        httpClient: HTTPClient = PreviewHTTPClient(),
        modelContainer: ModelContainer? = nil,
        allowsIconNetworkFetches: Bool = false
    ) {
        _services = State(initialValue: AppServices.mocked(
            httpClient: httpClient,
            modelContainer: modelContainer,
            allowsIconNetworkFetches: allowsIconNetworkFetches
        ))
    }

    func body(content: Content) -> some View {
        content.environment(services)
    }
}

extension View {
    func previewAppDependencies(
        httpClient: HTTPClient = PreviewHTTPClient(),
        modelContainer: ModelContainer? = nil,
        allowsIconNetworkFetches: Bool = false
    ) -> some View {
        modifier(PreviewAppDependenciesModifier(
            httpClient: httpClient,
            modelContainer: modelContainer,
            allowsIconNetworkFetches: allowsIconNetworkFetches
        ))
    }

    func openASOPreviewEnvironment<SeedData>(
        _ previewContainer: OpenASOPreviewContainer<SeedData>,
        httpClient: HTTPClient = PreviewHTTPClient(),
        allowsIconNetworkFetches: Bool = false
    ) -> some View {
        self
            .modelContainer(previewContainer.modelContainer)
            .previewAppDependencies(
                httpClient: httpClient,
                modelContainer: previewContainer.modelContainer,
                allowsIconNetworkFetches: allowsIconNetworkFetches
            )
    }
}
