import Foundation

enum RatingsTimeFrame: CaseIterable, Identifiable {
    case lastYear
    case last6Months
    case last3Months
    case lastMonth
    case last14Days
    case last7Days

    var id: Self { self }

    var title: String {
        switch self {
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

    func cutoffDate(relativeTo latestDate: Date) -> Date {
        let calendar = Calendar.current

        switch self {
        case .lastYear:
            return calendar.date(byAdding: .year, value: -1, to: latestDate) ?? latestDate
        case .last6Months:
            return calendar.date(byAdding: .month, value: -6, to: latestDate) ?? latestDate
        case .last3Months:
            return calendar.date(byAdding: .month, value: -3, to: latestDate) ?? latestDate
        case .lastMonth:
            return calendar.date(byAdding: .month, value: -1, to: latestDate) ?? latestDate
        case .last14Days:
            return calendar.date(byAdding: .day, value: -14, to: latestDate) ?? latestDate
        case .last7Days:
            return calendar.date(byAdding: .day, value: -7, to: latestDate) ?? latestDate
        }
    }
}
