import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }

    var text: String

    init(text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            text = ""
            return
        }

        text = String(decoding: data, as: UTF8.self)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

enum CSVTable {
    static func encode(headers: [String], rows: [[String]]) -> String {
        ([headers] + rows)
            .map { row in row.map(escape).joined(separator: ",") }
            .joined(separator: "\n") + "\n"
    }

    static func parse(_ csv: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var isInsideQuotedField = false
        var index = csv.startIndex

        func finishRow() {
            row.append(field)
            rows.append(row)
            row = []
            field = ""
        }

        while index < csv.endIndex {
            let character = csv[index]
            let nextIndex = csv.index(after: index)

            if isInsideQuotedField {
                if character == "\"" {
                    if nextIndex < csv.endIndex, csv[nextIndex] == "\"" {
                        field.append("\"")
                        index = csv.index(after: nextIndex)
                        continue
                    }
                    isInsideQuotedField = false
                } else {
                    field.append(character)
                }
            } else {
                switch character {
                case "\"" where field.isEmpty:
                    isInsideQuotedField = true
                case "\"":
                    field.append(character)
                case ",":
                    row.append(field)
                    field = ""
                case "\r\n":
                    finishRow()
                case "\n":
                    finishRow()
                case "\r":
                    finishRow()
                    if nextIndex < csv.endIndex, csv[nextIndex] == "\n" {
                        index = nextIndex
                    }
                default:
                    field.append(character)
                }
            }

            index = nextIndex
        }

        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }

        return rows
    }

    static func requiredColumnLookup(headers: [String], in row: [String]) throws -> [String: [Int]] {
        let lookup = columnLookup(in: row)

        for header in headers {
            guard lookup[normalizedHeader(header)]?.isEmpty == false else {
                throw CSVError.missingColumn(header)
            }
        }

        return lookup
    }

    static func columnLookup(in row: [String]) -> [String: [Int]] {
        var lookup: [String: [Int]] = [:]
        for (index, column) in row.enumerated() {
            let normalizedColumn = normalizedHeader(column)
            guard !normalizedColumn.isEmpty else {
                continue
            }
            lookup[normalizedColumn, default: []].append(index)
        }
        return lookup
    }

    static func containsAnyHeader(_ headers: [String], in lookup: [String: [Int]]) -> Bool {
        headers.contains { lookup[normalizedHeader($0)]?.isEmpty == false }
    }

    static func value(_ headers: [String], in row: [String], lookup: [String: [Int]]) -> String {
        for header in headers {
            let value = value(header, in: row, lookup: lookup)
            if !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return value
            }
        }

        guard let firstHeader = headers.first else {
            return ""
        }
        return value(firstHeader, in: row, lookup: lookup)
    }

    static func value(_ header: String, in row: [String], lookup: [String: [Int]]) -> String {
        guard let indexes = lookup[normalizedHeader(header)] else {
            return ""
        }

        for index in indexes where row.indices.contains(index) {
            let value = row[index]
            if !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return value
            }
        }

        guard let firstIndex = indexes.first, row.indices.contains(firstIndex) else {
            return ""
        }
        return row[firstIndex]
    }

    static func string(from date: Date?) -> String {
        guard let date else { return "" }
        return dateFormatter.string(from: date)
    }

    static func string(from date: Date) -> String {
        dateFormatter.string(from: date)
    }

    static func date(from string: String) -> Date? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return dateFormatter.date(from: trimmed) ?? ISO8601DateFormatter().date(from: trimmed)
    }

    private static func escape(_ field: String) -> String {
        guard field.contains(",") || field.contains("\"") || field.contains("\n") || field.contains("\r") else {
            return field
        }

        return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private static func normalizedHeader(_ header: String) -> String {
        header.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        return formatter
    }()
}

enum CSVError: LocalizedError, Equatable {
    case missingColumn(String)
    case noKeywordRows(parsedRowCount: Int, headers: [String])

    var errorDescription: String? {
        switch self {
        case .missingColumn(let column):
            return "The CSV is missing the required column: \(column)."
        case .noKeywordRows(let parsedRowCount, let headers):
            let headerList = headers
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .prefix(8)
                .joined(separator: ", ")
            let headerMessage = headerList.isEmpty ? "No headers were found." : "Detected headers: \(headerList)."
            return "No keyword rows were found in the CSV. Parsed \(parsedRowCount) data row\(parsedRowCount == 1 ? "" : "s"). \(headerMessage)"
        }
    }
}

struct TrackedKeywordCSVRow: Equatable {
    var appName: String
    var appID: String
    var platform: String
    var keyword: String
    var storeDomain: String
    var store: String
    var note: String
    var lastUpdate: String
    var ranking: String
    var change: String
    var popularity: String
    var difficulty: String
    var appsInRanking: String
    var tags: String
}

enum TrackedKeywordCSVFormat {
    private static let headers = [
        "App Name",
        "App Id",
        "Platform",
        "Keyword",
        "Store Domain",
        "Store",
        "Note",
        "Last Update",
        "Ranking",
        "Change",
        "Popularity",
        "Difficulty",
        "Apps in Ranking",
        "Tags"
    ]
    private static let requiredHeaders = [
        "Keyword"
    ]
    private static let appIDHeaders = ["App Id", "AppID"]
    private static let storeDomainHeaders = ["Store Domain", "Country"]

    static func encode(rows: [TrackedKeywordCSVRow]) -> String {
        CSVTable.encode(headers: headers, rows: rows.map(fields))
    }

    static func decode(_ csv: String) throws -> [TrackedKeywordCSVRow] {
        let table = CSVTable.parse(csv)
        guard let header = table.first else {
            return []
        }

        let lookup = try CSVTable.requiredColumnLookup(headers: requiredHeaders, in: header)
        guard CSVTable.containsAnyHeader(storeDomainHeaders, in: lookup) else {
            throw CSVError.missingColumn("Store Domain")
        }

        let rows = table.dropFirst().compactMap { row in
            let csvRow = TrackedKeywordCSVRow(
                appName: CSVTable.value("App Name", in: row, lookup: lookup),
                appID: CSVTable.value(appIDHeaders, in: row, lookup: lookup),
                platform: CSVTable.value("Platform", in: row, lookup: lookup),
                keyword: CSVTable.value("Keyword", in: row, lookup: lookup),
                storeDomain: CSVTable.value(storeDomainHeaders, in: row, lookup: lookup),
                store: CSVTable.value("Store", in: row, lookup: lookup),
                note: CSVTable.value("Note", in: row, lookup: lookup),
                lastUpdate: CSVTable.value("Last Update", in: row, lookup: lookup),
                ranking: CSVTable.value("Ranking", in: row, lookup: lookup),
                change: CSVTable.value("Change", in: row, lookup: lookup),
                popularity: CSVTable.value("Popularity", in: row, lookup: lookup),
                difficulty: CSVTable.value("Difficulty", in: row, lookup: lookup),
                appsInRanking: CSVTable.value("Apps in Ranking", in: row, lookup: lookup),
                tags: CSVTable.value("Tags", in: row, lookup: lookup)
            )

            return csvRow.keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : csvRow
        }

        if rows.isEmpty, table.dropFirst().contains(where: { row in
            row.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }) {
            throw CSVError.noKeywordRows(parsedRowCount: table.dropFirst().count, headers: header)
        }

        return rows
    }

    static func debugImportSummary(
        csv: String,
        fileName: String,
        filePath: String,
        byteCount: Int,
        didAccessSecurityScopedResource: Bool
    ) -> String {
        let table = CSVTable.parse(csv)
        let headers = table.first ?? []
        let dataRows = table.dropFirst()
        let firstDataRow = dataRows.first ?? []
        let decodedRowDescription: String
        do {
            decodedRowDescription = "\(try decode(csv).count)"
        } catch {
            decodedRowDescription = "error=\(error.localizedDescription)"
        }

        return [
            "[CSVImportDebug] file=\(fileName) path=\(filePath) bytes=\(byteCount) characters=\(csv.count) securityScoped=\(didAccessSecurityScopedResource)",
            "[CSVImportDebug] parsedRows=\(table.count) dataRows=\(dataRows.count) headerCount=\(headers.count) headers=\(debugJoinedFields(headers))",
            "[CSVImportDebug] firstDataRowCount=\(firstDataRow.count) firstDataRow=\(debugJoinedFields(firstDataRow))",
            "[CSVImportDebug] decodedKeywordRows=\(decodedRowDescription)"
        ].joined(separator: "\n")
    }

    static func string(from date: Date?) -> String {
        CSVTable.string(from: date)
    }

    static func date(from string: String) -> Date? {
        CSVTable.date(from: string)
    }

    private static func fields(for row: TrackedKeywordCSVRow) -> [String] {
        [
            row.appName,
            row.appID,
            row.platform,
            row.keyword,
            row.storeDomain,
            row.store,
            row.note,
            row.lastUpdate,
            row.ranking,
            row.change,
            row.popularity,
            row.difficulty,
            row.appsInRanking,
            row.tags
        ]
    }

    private static func debugJoinedFields(_ fields: [String]) -> String {
        guard !fields.isEmpty else {
            return "<none>"
        }

        return fields
            .prefix(16)
            .map(debugField)
            .joined(separator: " | ")
    }

    private static func debugField(_ field: String) -> String {
        let escaped = field
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\n", with: "\\n")
        if escaped.count <= 80 {
            return escaped
        }
        return "\(escaped.prefix(80))..."
    }
}

struct RatingsCSVRow {
    var appName: String
    var appID: String
    var storefront: String
    var store: String
    var ratingCount: String
    var ratingCountChange: String
    var averageRating: String
    var averageRatingChange: String
    var oneStarRatingCount: String = ""
    var oneStarRatingCountChange: String = ""
    var twoStarRatingCount: String = ""
    var twoStarRatingCountChange: String = ""
    var threeStarRatingCount: String = ""
    var threeStarRatingCountChange: String = ""
    var fourStarRatingCount: String = ""
    var fourStarRatingCountChange: String = ""
    var fiveStarRatingCount: String = ""
    var fiveStarRatingCountChange: String = ""
    var ratingDate: String
    var observedAt: String
    var source: String
}

enum RatingsCSVFormat {
    private static let headers = [
        "App Name",
        "App Id",
        "Storefront",
        "Store",
        "Rating Count",
        "Rating Count Change",
        "Average Rating",
        "Average Rating Change",
        "1 Star Rating Count",
        "1 Star Rating Count Change",
        "2 Star Rating Count",
        "2 Star Rating Count Change",
        "3 Star Rating Count",
        "3 Star Rating Count Change",
        "4 Star Rating Count",
        "4 Star Rating Count Change",
        "5 Star Rating Count",
        "5 Star Rating Count Change",
        "Rating Date",
        "Observed At",
        "Source"
    ]

    static func encode(rows: [RatingsCSVRow]) -> String {
        CSVTable.encode(headers: headers, rows: rows.map(fields))
    }

    static func string(from date: Date) -> String {
        CSVTable.string(from: date)
    }

    private static func fields(for row: RatingsCSVRow) -> [String] {
        [
            row.appName,
            row.appID,
            row.storefront,
            row.store,
            row.ratingCount,
            row.ratingCountChange,
            row.averageRating,
            row.averageRatingChange,
            row.oneStarRatingCount,
            row.oneStarRatingCountChange,
            row.twoStarRatingCount,
            row.twoStarRatingCountChange,
            row.threeStarRatingCount,
            row.threeStarRatingCountChange,
            row.fourStarRatingCount,
            row.fourStarRatingCountChange,
            row.fiveStarRatingCount,
            row.fiveStarRatingCountChange,
            row.ratingDate,
            row.observedAt,
            row.source
        ]
    }
}

struct KeywordRankingHistoryCSVRow {
    var appName: String
    var appID: String
    var platform: String
    var keyword: String
    var storeDomain: String
    var store: String
    var observedAt: String
    var ranking: String
    var change: String
    var periodChange: String
    var popularity: String
    var difficulty: String
    var appsInRanking: String
    var source: String
    var error: String
}

enum KeywordRankingHistoryCSVFormat {
    private static let headers = [
        "App Name",
        "App Id",
        "Platform",
        "Keyword",
        "Store Domain",
        "Store",
        "Observed At",
        "Ranking",
        "Change",
        "Period Change",
        "Popularity",
        "Difficulty",
        "Apps in Ranking",
        "Source",
        "Error"
    ]

    static func encode(rows: [KeywordRankingHistoryCSVRow]) -> String {
        CSVTable.encode(headers: headers, rows: rows.map(fields))
    }

    static func string(from date: Date) -> String {
        CSVTable.string(from: date)
    }

    private static func fields(for row: KeywordRankingHistoryCSVRow) -> [String] {
        [
            row.appName,
            row.appID,
            row.platform,
            row.keyword,
            row.storeDomain,
            row.store,
            row.observedAt,
            row.ranking,
            row.change,
            row.periodChange,
            row.popularity,
            row.difficulty,
            row.appsInRanking,
            row.source,
            row.error
        ]
    }
}
