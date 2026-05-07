import Foundation
import SwiftData

@MainActor
final class KeywordInsightsService {
    func dataset(
        for trackedApp: TrackedApp,
        tracks: [TrackedAppKeyword],
        dateRange: TrendDateRange,
        in modelContext: ModelContext
    ) async -> KeywordInsightsDataset {
        localDataset(for: trackedApp, tracks: tracks, dateRange: dateRange, in: modelContext)
    }

    private func localDataset(
        for trackedApp: TrackedApp,
        tracks: [TrackedAppKeyword],
        dateRange: TrendDateRange,
        in modelContext: ModelContext
    ) -> KeywordInsightsDataset {
        let queryKeys = Array(Set(tracks.map(\.queryKey)))
        let metricsByQueryKey = ((try? modelContext.fetch(metricsDescriptor(queryKeys: queryKeys))) ?? [])
            .reduce(into: [String: KeywordDailyMetric]()) { partial, metrics in
                partial[metrics.queryKey] = metrics
            }
        let cutoffDate = dateRange.cutoffDate
        let crawls = (try? modelContext.fetch(crawlDescriptor(queryKeys: queryKeys, cutoffDate: cutoffDate))) ?? []
        let crawlsByQueryKey = Dictionary(grouping: crawls, by: \.queryKey)
        let rankingItemsByCrawlKey = ((try? modelContext.fetch(rankingItemDescriptor(
            queryKeys: queryKeys,
            appStoreID: trackedApp.appStoreID,
            cutoffDate: cutoffDate
        ))) ?? [])
            .reduce(into: [String: KeywordAppRanking]()) { partial, item in
                partial[item.crawlKey] = item
            }
        let series = tracks.map { track in
            let metrics = metricsByQueryKey[track.queryKey]
            let points = (crawlsByQueryKey[track.queryKey] ?? [])
                .map { crawl in
                    let rankingItem = rankingItemsByCrawlKey[crawl.observationKey]
                    return KeywordInsightPoint(
                        date: Calendar.current.startOfDay(for: crawl.observedAt),
                        observedAt: crawl.observedAt,
                        rank: rankingItem?.position,
                        resultCount: crawl.resultCount,
                        popularityScore: metrics?.popularityScore,
                        confidence: crawl.confidenceRaw
                    )
                }

            return KeywordInsightSeries(
                queryKey: track.queryKey,
                keyword: track.term,
                storefront: track.storefront,
                platform: track.platform,
                points: points
            )
        }

        return KeywordInsightsDataset(appStoreID: trackedApp.appStoreID, series: series, source: .local)
    }

    private func crawlDescriptor(
        queryKeys: [String],
        cutoffDate: Date?
    ) -> FetchDescriptor<KeywordRankingCrawl> {
        let sortBy = [SortDescriptor(\KeywordRankingCrawl.observedAt, order: .forward)]

        guard let cutoffDate else {
            return FetchDescriptor<KeywordRankingCrawl>(
                predicate: #Predicate { crawl in
                    queryKeys.contains(crawl.queryKey)
                },
                sortBy: sortBy
            )
        }

        return FetchDescriptor<KeywordRankingCrawl>(
            predicate: #Predicate { crawl in
                queryKeys.contains(crawl.queryKey) && crawl.observedAt >= cutoffDate
            },
            sortBy: sortBy
        )
    }

    private func rankingItemDescriptor(
        queryKeys: [String],
        appStoreID: Int64,
        cutoffDate: Date?
    ) -> FetchDescriptor<KeywordAppRanking> {
        guard let cutoffDate else {
            return FetchDescriptor<KeywordAppRanking>(
                predicate: #Predicate { ranking in
                    queryKeys.contains(ranking.queryKey) && ranking.appStoreID == appStoreID
                }
            )
        }

        return FetchDescriptor<KeywordAppRanking>(
            predicate: #Predicate { ranking in
                queryKeys.contains(ranking.queryKey)
                    && ranking.appStoreID == appStoreID
                    && ranking.observedAt >= cutoffDate
            }
        )
    }

    private func metricsDescriptor(queryKeys: [String]) -> FetchDescriptor<KeywordDailyMetric> {
        let targetQueryKeys = queryKeys
        return FetchDescriptor<KeywordDailyMetric>(
            predicate: #Predicate { metrics in
                targetQueryKeys.contains(metrics.queryKey)
            }
        )
    }
}
