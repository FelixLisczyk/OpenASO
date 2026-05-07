import Foundation

protocol AppResolver: Sendable {
    func resolve(appStoreID: Int64, storefrontCode: String) async throws -> ResolvedApp
    func searchApps(named query: String, storefrontCode: String, limit: Int) async throws -> [ResolvedApp]
}
