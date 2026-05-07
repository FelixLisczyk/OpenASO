import Foundation
import Testing
@testable import OpenASO

@MainActor
struct DefaultAppResolverTests {
    @Test
    func resolvesAppStoreIDViaLookup() async throws {
        let client = MockHTTPClient { request in
            let payload = """
            {
              "results": [
                {
                  "trackId": 361309726,
                  "bundleId": "com.apple.Pages",
                  "trackName": "Pages: Create Documents",
                  "subtitle": "Documents that stand apart",
                  "sellerName": "Apple",
                  "artworkUrl100": "https://example.com/pages-100.png",
                  "languageCodesISO2A": ["EN", "DE"],
                  "screenshotUrls": ["https://example.com/pages-iphone-1.png"],
                  "ipadScreenshotUrls": ["https://example.com/pages-ipad-1.png"]
                }
              ]
            }
            """
            return (
                Data(payload.utf8),
                makeHTTPURLResponse(url: try #require(request.url), statusCode: 200)
            )
        }

        let resolver = DefaultAppResolver(httpClient: client)
        let resolved = try await resolver.resolve(appStoreID: 361309726, storefrontCode: "us")

        #expect(resolved.appStoreID == 361309726)
        #expect(resolved.bundleID == "com.apple.Pages")
        #expect(resolved.name == "Pages: Create Documents")
        #expect(resolved.subtitle == "Documents that stand apart")
        #expect(resolved.iconURLString == "https://example.com/pages-100.png")
        #expect(resolved.supportedLanguageCodes == ["EN", "DE"])
        #expect(resolved.screenshotURLs == ["https://example.com/pages-iphone-1.png"])
        #expect(resolved.ipadScreenshotURLs == ["https://example.com/pages-ipad-1.png"])
    }

    @Test
    func searchesAppsByName() async throws {
        let client = MockHTTPClient { request in
            let payload = """
            {
              "results": [
                {
                  "trackId": 361309726,
                  "bundleId": "com.apple.Pages",
                  "trackName": "Pages: Create Documents",
                  "subtitle": "Documents that stand apart",
                  "sellerName": "Apple",
                  "artworkUrl100": "https://example.com/pages-100.png"
                },
                {
                  "trackId": 842842640,
                  "bundleId": "com.google.Docs",
                  "trackName": "Google Docs",
                  "sellerName": "Google",
                  "artworkUrl100": "https://example.com/google-docs-100.png"
                }
              ]
            }
            """
            return (
                Data(payload.utf8),
                makeHTTPURLResponse(url: try #require(request.url), statusCode: 200)
            )
        }

        let resolver = DefaultAppResolver(httpClient: client)
        let results = try await resolver.searchApps(named: "pages", storefrontCode: "us", limit: 10)

        #expect(results.count == 2)
        #expect(results.first?.appStoreID == 361309726)
        #expect(results.first?.subtitle == "Documents that stand apart")
        #expect(results.first?.iconURLString == "https://example.com/pages-100.png")
    }
}
