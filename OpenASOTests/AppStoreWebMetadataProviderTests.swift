import Foundation
import Testing
@testable import OpenASO

@MainActor
struct AppStoreWebMetadataProviderTests {
    @Test
    func parsesSerializedServerDataMetadataAndScreenshots() throws {
        let html = """
        <!doctype html>
        <html>
        <body>
        <script type="application/json" id="serialized-server-data">
        {
          "data": [
            {
              "data": {
                "$kind": "ShelfBasedProductPage",
                "title": "Flighty - Live Flight Tracker",
                "lockup": {
                  "$kind": "Lockup",
                  "adamId": "1358823008",
                  "title": "Flighty - Live Flight Tracker",
                  "subtitle": "World's Fastest Delay Alerts",
                  "developerName": "Flighty LLC",
                  "rating": 4.8,
                  "ratingCount": 126834
                },
                "shelfMapping": {
                  "product_media_phone_": {
                    "items": [
                      {
                        "screenshot": {
                          "$kind": "Artwork",
                          "template": "https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/iphone/{w}x{h}{c}.{f}",
                          "width": 1242,
                          "height": 2688
                        }
                      }
                    ]
                  },
                  "product_media_pad_": {
                    "items": [
                      {
                        "screenshot": {
                          "$kind": "Artwork",
                          "template": "https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/ipad/{w}x{h}{c}.{f}",
                          "width": 2048,
                          "height": 2732
                        }
                      }
                    ]
                  },
                  "productRatings": {
                    "items": [
                      {
                        "$kind": "Ratings",
                        "ratingAverage": 4.8,
                        "totalNumberOfRatings": 126834,
                        "ratingCounts": [109000, 12000, 3000, 1000, 1834]
                      }
                    ]
                  }
                }
              }
            }
          ]
        }
        </script>
        </body>
        </html>
        """

        let metadata = try AppStoreWebMetadataProvider.parse(
            Data(html.utf8),
            appStoreID: 1_358_823_008,
            storefrontCode: "US"
        )

        #expect(metadata.appStoreID == 1_358_823_008)
        #expect(metadata.storefront == "us")
        #expect(metadata.name == "Flighty - Live Flight Tracker")
        #expect(metadata.subtitle == "World's Fastest Delay Alerts")
        #expect(metadata.sellerName == "Flighty LLC")
        #expect(metadata.averageRating == 4.8)
        #expect(metadata.ratingCount == 126834)
        #expect(metadata.ratingCounts?.fiveStar == 109000)
        #expect(metadata.ratingCounts?.fourStar == 12000)
        #expect(metadata.ratingCounts?.threeStar == 3000)
        #expect(metadata.ratingCounts?.twoStar == 1000)
        #expect(metadata.ratingCounts?.oneStar == 1834)
        #expect(metadata.screenshotGroups.map { $0.platformRaw } == ["ipad", "iphone"])
        #expect(metadata.screenshotGroups.first { $0.platformRaw == "iphone" }?.displayTypeRaw == "phone")
        #expect(metadata.screenshotGroups.first { $0.platformRaw == "iphone" }?.screenshots.first?.urlString == "https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/iphone/1242x2688bb.jpg")
        #expect(metadata.screenshotGroups.first { $0.platformRaw == "ipad" }?.screenshots.first?.width == 2048)
    }

    @Test
    func fetchesAppsApplePageForStorefront() async throws {
        let client = MockHTTPClient { request in
            #expect(request.url?.absoluteString == "https://apps.apple.com/de/app/id1497465230")
            #expect(request.value(forHTTPHeaderField: "User-Agent")?.isEmpty == false)

            let payload = """
            <script type="application/json" id="serialized-server-data">
            {
              "data": [
                {
                  "data": {
                    "title": "Opal",
                    "lockup": {
                      "$kind": "Lockup",
                      "adamId": "1497465230",
                      "subtitle": "Focus, App Blocker & Timer"
                    },
                    "shelfMapping": {}
                  }
                }
              ]
            }
            </script>
            """
            return (
                Data(payload.utf8),
                makeHTTPURLResponse(url: try #require(request.url), statusCode: 200)
            )
        }

        let provider = AppStoreWebMetadataProvider(httpClient: client)
        let metadata = try await provider.fetch(appStoreID: 1_497_465_230, storefrontCode: "DE")

        #expect(metadata.storefront == "de")
        #expect(metadata.name == "Opal")
        #expect(metadata.subtitle == "Focus, App Blocker & Timer")
    }
}
