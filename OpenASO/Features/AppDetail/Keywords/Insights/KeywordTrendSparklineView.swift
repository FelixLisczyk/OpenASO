import Charts
import SwiftUI

struct KeywordTrendSparklineView: View {
    let points: [Int]
    let color: Color

    var body: some View {
        let chartPoints = chartPoints
        let areaGradient = LinearGradient(
            gradient: Gradient(
                colors: [
                    color.opacity(isFlatTrend ? 0.08 : 0.28),
                    color.opacity(isFlatTrend ? 0.02 : 0.06),
                    color.opacity(0.0)
                ]
            ),
            startPoint: .top,
            endPoint: .bottom
        )

        Chart {
            ForEach(chartPoints) { point in
                AreaMark(
                    x: .value("Refresh", point.index),
                    yStart: .value("Baseline", rankScaleUpperBound),
                    yEnd: .value("Rank", point.rank)
                )
                .interpolationMethod(.cardinal)
                .foregroundStyle(areaGradient)
            }

            ForEach(chartPoints) { point in
                LineMark(
                    x: .value("Refresh", point.index),
                    y: .value("Rank", point.rank)
                )
                .interpolationMethod(.cardinal)
                .lineStyle(
                    StrokeStyle(
                        lineWidth: isFlatTrend ? 1.5 : 3,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                .foregroundStyle(color.opacity(isFlatTrend ? 0.44 : 1))
            }
        }
        .chartXScale(domain: 0 ... max(chartPoints.count - 1, 1))
        .chartYScale(domain: [rankScaleUpperBound, rankScaleLowerBound])
        .chartLegend(.hidden)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartPlotStyle { plotArea in
            plotArea
                .background(.clear)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rank trend")
    }

    private var isFlatTrend: Bool {
        guard let firstPoint = points.first else { return false }
        return points.allSatisfy { $0 == firstPoint }
    }

    private var chartPoints: [KeywordTrendChartPoint] {
        points.enumerated().map { index, rank in
            KeywordTrendChartPoint(index: index, rank: rank)
        }
    }

    private var rankScaleLowerBound: Int {
        guard let minRank = points.min() else {
            return 1
        }

        if isFlatTrend {
            return max(0, minRank - 1)
        }

        return minRank
    }

    private var rankScaleUpperBound: Int {
        guard let maxRank = points.max() else {
            return 2
        }

        return isFlatTrend ? maxRank + 1 : maxRank
    }
}

private struct KeywordTrendChartPoint: Identifiable {
    let index: Int
    let rank: Int

    var id: Int { index }
}

#Preview("Keyword Trend Sparkline") {
    VStack(alignment: .leading, spacing: 14) {
        previewRow(title: "Trending Up", points: [24, 23, 23, 22, 20, 16, 11], color: .green)
        previewRow(title: "Trending Down", points: [8, 9, 11, 12, 15, 18, 23], color: .red)
        previewRow(title: "Unchanged", points: [14, 14, 14, 14, 14, 14, 14], color: .secondary)
        previewRow(title: "Volatile Up", points: [35, 29, 31, 24, 26, 20, 12], color: .green)
        previewRow(title: "No Data", points: [], color: .secondary)
    }
    .padding(20)
    .frame(width: 260)
}

private func previewRow(title: String, points: [Int], color: Color) -> some View {
    HStack(spacing: 12) {
        Text(title)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(width: 86, alignment: .leading)

        KeywordTrendSparklineView(points: points, color: color)
            .frame(width: 120, height: 34)
    }
}
