import Foundation

enum ReviewTimeFrame: CaseIterable, Identifiable, Sendable {
    case all
    case lastYear
    case last6Months
    case last3Months
    case lastMonth
    case last14Days
    case last7Days

    var id: Self { self }

    var resetKey: String {
        switch self {
        case .all:
            return "all"
        case .lastYear:
            return "lastYear"
        case .last6Months:
            return "last6Months"
        case .last3Months:
            return "last3Months"
        case .lastMonth:
            return "lastMonth"
        case .last14Days:
            return "last14Days"
        case .last7Days:
            return "last7Days"
        }
    }

    var title: String {
        switch self {
        case .all:
            return "All Time"
        case .lastYear:
            return "Last Year"
        case .last6Months:
            return "Last 6 Months"
        case .last3Months:
            return "Last 3 Months"
        case .lastMonth:
            return "Last Month"
        case .last14Days:
            return "Last 14 Days"
        case .last7Days:
            return "Last 7 Days"
        }
    }

    func cutoffDate(relativeTo date: Date) -> Date? {
        let calendar = Calendar.current
        switch self {
        case .all:
            return nil
        case .lastYear:
            return calendar.date(byAdding: .year, value: -1, to: date)
        case .last6Months:
            return calendar.date(byAdding: .month, value: -6, to: date)
        case .last3Months:
            return calendar.date(byAdding: .month, value: -3, to: date)
        case .lastMonth:
            return calendar.date(byAdding: .month, value: -1, to: date)
        case .last14Days:
            return calendar.date(byAdding: .day, value: -14, to: date)
        case .last7Days:
            return calendar.date(byAdding: .day, value: -7, to: date)
        }
    }
}

enum ReviewRatingFilter: CaseIterable, Identifiable, Sendable {
    case all
    case five
    case four
    case three
    case two
    case one

    var id: Self { self }

    var resetKey: String {
        switch self {
        case .all:
            return "all"
        case .five:
            return "five"
        case .four:
            return "four"
        case .three:
            return "three"
        case .two:
            return "two"
        case .one:
            return "one"
        }
    }

    var title: String {
        switch self {
        case .all:
            return "All Stars"
        case .five:
            return "5 Stars"
        case .four:
            return "4 Stars"
        case .three:
            return "3 Stars"
        case .two:
            return "2 Stars"
        case .one:
            return "1 Star"
        }
    }

    var rating: Int? {
        switch self {
        case .all:
            return nil
        case .five:
            return 5
        case .four:
            return 4
        case .three:
            return 3
        case .two:
            return 2
        case .one:
            return 1
        }
    }
}

extension StorefrontFilter {
    var storefrontCode: String? {
        switch self {
        case .all:
            return nil
        case .storefront(let code, _):
            return code
        }
    }
}
