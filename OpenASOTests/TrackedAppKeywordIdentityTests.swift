import Foundation
import Testing
@testable import OpenASO

struct TrackedAppKeywordIdentityTests {
    @Test
    func identityKeyVariesByStorefrontAndApp() {
        let first = TrackedAppKeyword.makeIdentityKey(appStoreID: 1, term: "notes", storefront: "us", platform: .iphone)
        let second = TrackedAppKeyword.makeIdentityKey(appStoreID: 1, term: "notes", storefront: "gb", platform: .iphone)
        let third = TrackedAppKeyword.makeIdentityKey(appStoreID: 2, term: "notes", storefront: "us", platform: .iphone)

        #expect(first != second)
        #expect(first != third)
    }

    @Test
    func bundledStorefrontCatalogMatchesAstroCoverage() throws {
        let url = try #require(Bundle.main.url(forResource: "storefronts", withExtension: "json"))
        let data = try Data(contentsOf: url)
        let storefronts = try JSONDecoder().decode([StorefrontSeed].self, from: data)
        let codes = Set(storefronts.map(\.code))

        #expect(storefronts.count == 174)
        #expect(codes.count == storefronts.count)
        #expect(codes.contains("us"))
        #expect(codes.contains("gb"))
        #expect(codes.contains("zm"))
    }
}

private struct StorefrontSeed: Decodable {
    let code: String
}
