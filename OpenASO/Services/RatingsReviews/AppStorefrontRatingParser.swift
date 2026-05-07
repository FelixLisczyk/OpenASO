import Foundation

struct AppStorefrontRatingParser {
    func storefrontCode(html: String, responseURL: URL?) -> String? {
        let patterns = [
            #"<link[^>]+rel=["']canonical["'][^>]+href=["']https://apps\.apple\.com/([a-z]{2})/app"#,
            #"<meta[^>]+property=["']og:url["'][^>]+content=["']https://apps\.apple\.com/([a-z]{2})/app"#,
            #""canonicalURL"\s*:\s*"https://apps\.apple\.com/([a-z]{2})/app"#,
            #""storeFront"\s*:\s*"([a-z]{2})""#,
            #""storefront"\s*:\s*"([a-z]{2})""#
        ]

        for pattern in patterns {
            guard
                let match = firstMatch(pattern: pattern, in: html),
                match.count > 1
            else {
                continue
            }

            return match[1].lowercased()
        }

        return storefrontCode(from: responseURL)
    }

    func parse(html: String) -> ParsedAppStorefrontRating? {
        if let structuredRating = parseStructuredRating(from: html) {
            return structuredRating
        }

        let text = normalizedVisibleText(from: html)

        let patterns = [
            #"([0-5](?:[\.,]\d)?)\s*out of 5\s*([0-9][0-9,\.\s]*(?:[KMB])?)\s+Ratings"#,
            #"([0-9][0-9,\.\s]*(?:[KMB])?)\s+Ratings\s+([0-5](?:[\.,]\d)?)"#
        ]

        for (index, pattern) in patterns.enumerated() {
            guard let match = firstMatch(pattern: pattern, in: text) else {
                continue
            }

            if index == 0 {
                return ParsedAppStorefrontRating(
                    ratingCount: parseRatingCount(match[2]),
                    averageRating: parseAverageRating(match[1]),
                    ratingCounts: nil
                )
            } else {
                return ParsedAppStorefrontRating(
                    ratingCount: parseRatingCount(match[1]),
                    averageRating: parseAverageRating(match[2]),
                    ratingCounts: nil
                )
            }
        }

        return nil
    }

    private func parseStructuredRating(from html: String) -> ParsedAppStorefrontRating? {
        guard
            let ratingValue = firstJSONNumber(named: "ratingValue", in: html),
            let reviewCount = firstJSONNumber(named: "reviewCount", in: html)
        else {
            return nil
        }

        let ratingCounts = firstJSONIntArray(named: "ratingCounts", in: html)
            .flatMap(AppStoreRatingCounts.init(appStoreDescendingCounts:))

        return ParsedAppStorefrontRating(
            ratingCount: Int(reviewCount.rounded()),
            averageRating: ratingValue,
            ratingCounts: ratingCounts
        )
    }

    private func normalizedVisibleText(from html: String) -> String {
        let withoutScripts = html
            .replacingOccurrences(
                of: #"<script[\s\S]*?</script>"#,
                with: " ",
                options: [.regularExpression, .caseInsensitive]
            )
            .replacingOccurrences(
                of: #"<style[\s\S]*?</style>"#,
                with: " ",
                options: [.regularExpression, .caseInsensitive]
            )
            .replacingOccurrences(of: #"&nbsp;"#, with: " ", options: .caseInsensitive)
            .replacingOccurrences(of: #"&#x27;"#, with: "'", options: .caseInsensitive)
            .replacingOccurrences(of: #"&amp;"#, with: "&", options: .caseInsensitive)
            .replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)

        return withoutScripts
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func firstMatch(pattern: String, in text: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }

        let range = NSRange(text.startIndex ..< text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range) else {
            return nil
        }

        return (0 ..< match.numberOfRanges).compactMap { index in
            guard let range = Range(match.range(at: index), in: text) else {
                return nil
            }
            return String(text[range])
        }
    }

    private func parseAverageRating(_ value: String) -> Double? {
        Double(value.replacingOccurrences(of: ",", with: "."))
    }

    private func storefrontCode(from url: URL?) -> String? {
        guard
            let url,
            url.host?.lowercased() == "apps.apple.com"
        else {
            return nil
        }

        let components = url.pathComponents
        guard components.count > 1 else {
            return nil
        }

        let code = components[1].lowercased()
        guard code.count == 2, code.allSatisfy(\.isLetter) else {
            return nil
        }

        return code
    }

    private func firstJSONNumber(named key: String, in text: String) -> Double? {
        let escapedKey = NSRegularExpression.escapedPattern(for: key)
        let pattern = #""\#(escapedKey)"\s*:\s*"?([0-9]+(?:[\.,][0-9]+)?)"?"#
        guard
            let match = firstMatch(pattern: pattern, in: text),
            match.count > 1
        else {
            return nil
        }

        return Double(match[1].replacingOccurrences(of: ",", with: "."))
    }

    private func firstJSONIntArray(named key: String, in text: String) -> [Int]? {
        let escapedKey = NSRegularExpression.escapedPattern(for: key)
        let pattern = #""\#(escapedKey)"\s*:\s*\[([0-9,\s]+)\]"#
        guard
            let match = firstMatch(pattern: pattern, in: text),
            match.count > 1
        else {
            return nil
        }

        let values = match[1]
            .split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        return values.isEmpty ? nil : values
    }

    private func parseRatingCount(_ value: String) -> Int? {
        let compact = value
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        let multiplier: Double
        let numberPart: String
        if compact.hasSuffix("K") {
            multiplier = 1_000
            numberPart = String(compact.dropLast())
        } else if compact.hasSuffix("M") {
            multiplier = 1_000_000
            numberPart = String(compact.dropLast())
        } else if compact.hasSuffix("B") {
            multiplier = 1_000_000_000
            numberPart = String(compact.dropLast())
        } else {
            multiplier = 1
            numberPart = compact
        }

        guard let number = Double(numberPart) else {
            return nil
        }

        return Int((number * multiplier).rounded())
    }
}
