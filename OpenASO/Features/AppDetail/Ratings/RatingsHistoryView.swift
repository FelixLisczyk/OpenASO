import Charts
import SwiftUI

struct RatingsHistoryChart: View {
    let historyPoints: [RatingHistoryPoint]
    let metric: RatingsMetric
    let timeFrame: RatingsTimeFrame
    let dateDomain: ClosedRange<Date>

    private var configuration: RatingsChartConfiguration {
        RatingsChartConfiguration(
            historyPoints: historyPoints,
            metric: metric,
            timeFrame: timeFrame,
            dateDomain: dateDomain
        )
    }

    var body: some View {
        let configuration = configuration

        Chart(historyPoints) { point in
            LineMark(
                x: .value("Date", point.date),
                y: .value(metric.title, point.value)
            )
            .interpolationMethod(.linear)
            .foregroundStyle(.blue)

            PointMark(
                x: .value("Date", point.date),
                y: .value(metric.title, point.value)
            )
            .symbolSize(24)
            .foregroundStyle(.blue)
        }
        .chartXScale(domain: dateDomain)
        .chartYScale(domain: configuration.yDomain)
        .chartXAxis {
            AxisMarks(values: configuration.xAxisValues) { value in
                AxisGridLine()
                AxisTick()

                if let date = value.as(Date.self) {
                    AxisValueLabel {
                        Text(configuration.xAxisLabel(for: date))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: configuration.yAxisValues) { value in
                AxisGridLine()
                AxisTick()

                if let yValue = value.as(Double.self) {
                    AxisValueLabel {
                        Text(configuration.yAxisLabel(for: yValue))
                    }
                }
            }
        }
        .frame(minHeight: 300)
    }
}

private struct RatingsChartConfiguration {
    let historyPoints: [RatingHistoryPoint]
    let metric: RatingsMetric
    let timeFrame: RatingsTimeFrame
    let dateDomain: ClosedRange<Date>

    var yDomain: ClosedRange<Double> {
        switch metric {
        case .averageRating:
            return averageRatingDomain
        case .ratingCount:
            return 0...ratingCountUpperBound
        }
    }

    var yAxisValues: [Double] {
        switch metric {
        case .averageRating:
            return Self.axisValues(in: averageRatingDomain)
        case .ratingCount:
            let upperBound = ratingCountUpperBound
            return stride(from: 0.0, through: upperBound, by: upperBound / 4).map { $0 }
        }
    }

    var xAxisValues: [Date] {
        var values: [Date] = []
        var current = calendar.startOfDay(for: dateDomain.lowerBound)
        let endDate = dateDomain.upperBound

        while current <= endDate {
            values.append(current)
            guard let nextDate = calendar.date(byAdding: xAxisComponent, value: xAxisStep, to: current) else {
                break
            }
            current = nextDate
        }

        if values.last.map({ !calendar.isDate($0, inSameDayAs: endDate) }) ?? true {
            values.append(endDate)
        }

        return values
    }

    func yAxisLabel(for value: Double) -> String {
        switch metric {
        case .averageRating:
            return value.formatted(.number.precision(.fractionLength(0...1)))
        case .ratingCount:
            return value.formatted(.number.notation(.compactName).precision(.fractionLength(0...1)))
        }
    }

    func xAxisLabel(for date: Date) -> String {
        switch timeFrame {
        case .lastYear, .last6Months:
            return date.formatted(.dateTime.month(.abbreviated).year(.twoDigits))
        case .last3Months, .lastMonth:
            return date.formatted(.dateTime.month(.abbreviated).day())
        case .last14Days, .last7Days:
            return date.formatted(.dateTime.weekday(.abbreviated).day())
        }
    }

    private var ratingCountUpperBound: Double {
        let maximumValue = historyPoints.map(\.value).max() ?? 0
        guard maximumValue > 0 else { return 100 }
        return Self.niceUpperBound(for: maximumValue)
    }

    private var averageRatingDomain: ClosedRange<Double> {
        guard
            let minimumValue = historyPoints.map(\.value).min(),
            let maximumValue = historyPoints.map(\.value).max()
        else {
            return 0...5
        }

        let clampedMinimumValue = min(5, max(0, minimumValue))
        let clampedMaximumValue = min(5, max(0, maximumValue))
        let lowerBound = max(0, clampedMinimumValue - 1)
        let upperBound = min(5, clampedMaximumValue + 1)

        guard lowerBound < upperBound else { return 0...5 }
        return lowerBound...upperBound
    }

    private var xAxisComponent: Calendar.Component {
        switch timeFrame {
        case .lastYear, .last6Months, .last3Months:
            return .month
        case .lastMonth, .last14Days, .last7Days:
            return .day
        }
    }

    private var xAxisStep: Int {
        switch timeFrame {
        case .lastYear:
            return 2
        case .last6Months, .last3Months:
            return 1
        case .lastMonth:
            return 7
        case .last14Days:
            return 2
        case .last7Days:
            return 1
        }
    }

    private var calendar: Calendar {
        Calendar.current
    }

    private static func niceUpperBound(for value: Double) -> Double {
        let exponent = floor(log10(value))
        let magnitude = pow(10, exponent)
        let normalizedValue = value / magnitude
        let roundedValue: Double

        switch normalizedValue {
        case ...1:
            roundedValue = 1
        case ...2:
            roundedValue = 2
        case ...5:
            roundedValue = 5
        default:
            roundedValue = 10
        }

        return roundedValue * magnitude
    }

    private static func axisValues(in domain: ClosedRange<Double>) -> [Double] {
        let step = (domain.upperBound - domain.lowerBound) / 4
        guard step > 0 else { return [domain.lowerBound] }

        return (0...4).map { index in
            domain.lowerBound + (Double(index) * step)
        }
    }
}
