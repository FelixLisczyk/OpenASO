import SwiftData
import SwiftUI

struct RatingsReviewsView: View {
    @Environment(\.modelContext) private var modelContext

    let appStoreID: Int64
    let selectedStorefrontFilter: StorefrontFilter
    let searchText: String
    let refreshToken: Int
    let backgroundModelStore: BackgroundModelStore?
    let backgroundModelStoreRevision: Int
    let appStoreConnectStatus: RatingsAppStoreConnectStatus
    let storefrontDefinitions: [StorefrontDefinition]
    let replyService: AppStoreConnectReviewService
    let translationService: ReviewTranslationService
    let analyticsService: AnalyticsService
    let openAppStoreConnectSettings: () -> Void

    @State private var timeFrame = ReviewTimeFrame.all
    @State private var ratingFilter = ReviewRatingFilter.all
    @State private var loadedReviewCount = 0
    @State private var totalReviewCount = 0
    @State private var localRevision = 0
    @State private var translatingReviewKeys: Set<String> = []
    @State private var translationErrors: [String: String] = [:]
    @State private var replyDraft: ReviewReplyDraft?
    @State private var replyErrorMessage: String?
    @State private var isSendingReply = false
    @State private var canTranslateReviews = false

    private var resetID: String {
        [
            String(appStoreID),
            selectedStorefrontFilter.id,
            normalizedSearchText,
            timeFrame.resetKey,
            ratingFilter.resetKey,
            String(refreshToken),
            String(backgroundModelStoreRevision),
            String(appStoreConnectStatus.usesAppStoreConnectReviews),
            String(localRevision)
        ].joined(separator: "::")
    }

    private var normalizedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var emptyState: ReviewEmptyState {
        timeFrame == .all && ratingFilter == .all ? .noReviews : .noMatchingReviews
    }

    private var loader: ReviewsPageLoader {
        ReviewsPageLoader(
            appStoreID: appStoreID,
            storefrontCode: selectedStorefrontFilter.storefrontCode,
            cutoffDate: timeFrame.cutoffDate(relativeTo: .now),
            rating: ratingFilter.rating,
            source: appStoreConnectStatus.usesAppStoreConnectReviews ? .appStoreConnect : nil,
            backgroundModelStore: backgroundModelStore
        )
    }

    private var storefrontLookup: [String: StorefrontDefinition] {
        Dictionary(uniqueKeysWithValues: storefrontDefinitions.map { ($0.code.lowercased(), $0) })
    }

    var body: some View {
        let loader = loader
        let storefrontLookup = storefrontLookup

        VStack(alignment: .leading, spacing: 12) {
            appStoreConnectIndicator
                .padding(.horizontal, 18)

            HStack(spacing: 10) {
                Text("Time Period")
                    .font(.callout.weight(.semibold))

                Picker("Time Period", selection: $timeFrame) {
                    ForEach(ReviewTimeFrame.allCases) { option in
                        Text(option.title)
                            .tag(option)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 150)

                Text("Rating")
                    .font(.callout.weight(.semibold))

                Picker("Rating", selection: $ratingFilter) {
                    ForEach(ReviewRatingFilter.allCases) { option in
                        Text(option.title)
                            .tag(option)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 130)

                Spacer()

                Text("\(loadedReviewCount.formatted())/\(totalReviewCount.formatted()) Reviews")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 14)
            .padding(.horizontal, 18)

            PaginatedList(
                resetID: resetID,
                pageSize: 25,
                contentInsets: EdgeInsets(top: 0, leading: 18, bottom: 18, trailing: 18),
                loadPage: { request in
                    try await loader.load(request: request)
                },
                row: { review in
                    ReviewCard(
                        review: review,
                        storefrontDefinition: storefrontLookup[review.storefront],
                        canReply: appStoreConnectStatus.usesAppStoreConnectReviews && review.ascReviewID != nil,
                        canTranslate: canTranslateReviews,
                        isTranslating: translatingReviewKeys.contains(review.reviewKey),
                        translationError: translationErrors[review.reviewKey],
                        translateAction: {
                            translate(review)
                        },
                        replyAction: {
                            replyErrorMessage = nil
                            replyDraft = ReviewReplyDraft(review: review)
                        }
                    )
                },
                emptyContent: {
                    ReviewEmptyContent(state: emptyState)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                },
                onItemsChange: { reviews in
                    loadedReviewCount = reviews.count
                }
            )
        }
        .sheet(item: $replyDraft) { draft in
            ReviewReplySheet(
                review: draft.review,
                errorMessage: replyErrorMessage,
                isSending: isSendingReply,
                send: { body in
                    sendReply(body, for: draft.review)
                }
            )
            .frame(width: 520)
            .frame(minHeight: 360)
        }
        .task(id: resetID) {
            await loadTotalReviewCount(loader)
        }
        .task {
            canTranslateReviews = translationService.canTranslateReviews
        }
    }

    @ViewBuilder
    private var appStoreConnectIndicator: some View {
        switch appStoreConnectStatus {
        case .notConnected:
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "bubble.left.and.bubble.right")
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Connect App Store Connect to reply")
                        .font(.callout.weight(.semibold))
                    Text("Owned apps can show developer responses and send replies from this reviews view.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Connect", action: openAppStoreConnectSettings)
            }
            .padding(12)
            .background(Color.accentColor.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .padding(.top, 14)
        case .owned:
            Label("App Store Connect reviews enabled", systemImage: "checkmark.circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.green)
                .padding(.top, 14)
        case .publicOnly(let message):
            Label("Public reviews only. \(message)", systemImage: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 14)
        case .error(let message):
            HStack(spacing: 8) {
                Label("App Store Connect issue: \(message)", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                Spacer()
                Button("Settings", action: openAppStoreConnectSettings)
            }
            .padding(.top, 14)
        }
    }

    private func sendReply(_ body: String, for review: AppStoreReviewValue) {
        guard !isSendingReply else { return }

        Task { @MainActor in
            do {
                isSendingReply = true
                replyErrorMessage = nil
                _ = try await replyService.reply(to: review, body: body, in: modelContext)
                localRevision += 1
                replyDraft = nil
                analyticsService.capture(.reviewReplySent(result: "success"))
            } catch {
                analyticsService.capture(.reviewReplySent(result: "failure"))
                replyErrorMessage = OpenASOError.map(error).localizedDescription
            }
            isSendingReply = false
        }
    }

    private func translate(_ review: AppStoreReviewValue) {
        guard !translatingReviewKeys.contains(review.reviewKey) else { return }

        translatingReviewKeys.insert(review.reviewKey)
        translationErrors[review.reviewKey] = nil

        Task { @MainActor in
            do {
                _ = try await translationService.translate(review: review, to: "English", in: modelContext)
                localRevision += 1
                analyticsService.capture(.reviewTranslated(
                    sourceLanguageKnown: review.assumedLanguageCode?.isEmpty == false,
                    result: "success"
                ))
            } catch {
                analyticsService.capture(.reviewTranslated(
                    sourceLanguageKnown: review.assumedLanguageCode?.isEmpty == false,
                    result: "failure"
                ))
                translationErrors[review.reviewKey] = OpenASOError.map(error).localizedDescription
            }
            translatingReviewKeys.remove(review.reviewKey)
        }
    }

    @MainActor
    private func loadTotalReviewCount(_ loader: ReviewsPageLoader) async {
        totalReviewCount = 0
        do {
            totalReviewCount = try await loader.count()
        } catch {
            totalReviewCount = 0
        }
    }
}

#if DEBUG
#Preview("Ratings Reviews") {
    RatingsReviewsPreview()
}

@MainActor
private struct RatingsReviewsPreview: View {
    private let previewContainer: OpenASOPreviewContainer<Void>
    @State private var services: AppServices

    init() {
        let previewContainer = OpenASOPreviewContainer(seed: Self.seed)
        self.previewContainer = previewContainer
        _services = State(initialValue: AppServices.mocked(
            httpClient: PreviewHTTPClient(),
            modelContainer: previewContainer.modelContainer
        ))
    }

    var body: some View {
        RatingsReviewsView(
            appStoreID: 6448311069,
            selectedStorefrontFilter: .all,
            searchText: "",
            refreshToken: 0,
            backgroundModelStore: services.backgroundModelStore,
            backgroundModelStoreRevision: services.backgroundModelStoreRevision,
            appStoreConnectStatus: .owned,
            storefrontDefinitions: Self.storefrontDefinitions,
            replyService: services.appStoreConnectReviewService,
            translationService: services.reviewTranslationService,
            analyticsService: services.analyticsService,
            openAppStoreConnectSettings: {}
        )
        .modelContainer(previewContainer.modelContainer)
        .environment(services)
        .frame(width: 760, height: 640)
    }

    private static let storefrontDefinitions: [StorefrontDefinition] = [
        StorefrontDefinition(code: "us", name: "United States", flagEmoji: "🇺🇸", title: "🇺🇸 United States"),
        StorefrontDefinition(code: "gb", name: "United Kingdom", flagEmoji: "🇬🇧", title: "🇬🇧 United Kingdom"),
        StorefrontDefinition(code: "ca", name: "Canada", flagEmoji: "🇨🇦", title: "🇨🇦 Canada"),
        StorefrontDefinition(code: "de", name: "Germany", flagEmoji: "🇩🇪", title: "🇩🇪 Germany")
    ]

    private static func seed(in modelContext: ModelContext) {
        let storeApp = StoreApp(
            appStoreID: 6448311069,
            bundleID: "com.openai.chat",
            name: "ChatGPT",
            sellerName: "OpenAI",
            iconURLString: nil,
            defaultPlatform: .iphone
        )
        modelContext.insert(storeApp)

        let reviews: [(storefront: String, reviewID: String, reviewer: String, title: String, content: String, rating: Int, daysAgo: Int, response: String?)] = [
            ("us", "asc-11001", "Maya", "Reliable every day", "The app opens quickly and the answers are useful for drafting, research, and checking tone before I send notes.", 5, 1, nil),
            ("us", "asc-11002", "Jordan", "Good but expensive", "The product is excellent, but I would like clearer limits before I hit them during focused work.", 4, 5, "Thanks for the thoughtful feedback. We are working on making plan limits easier to understand."),
            ("gb", "asc-11003", "Priya", "Sync issues", "My chats sometimes lag between devices. The answer quality is good when everything catches up.", 3, 12, nil),
            ("ca", "asc-11004", "Noah", "Best assistant app", "It has become the main place I outline docs, summarize long emails, and check code snippets.", 5, 35, nil),
            ("de", "asc-11005", "Klara", "Hilfreich im Alltag", "Die Antworten sind sehr gut, aber ich wunsche mir schnellere Ubersetzungen in langen Chats.", 4, 46, nil)
        ]

        for review in reviews {
            let appReview = AppStorefrontReview(
                appStoreID: storeApp.appStoreID,
                storefront: review.storefront,
                reviewID: review.reviewID,
                reviewerName: review.reviewer,
                title: review.title,
                content: review.content,
                rating: review.rating,
                reviewedAt: date(daysAgo: review.daysAgo),
                version: "1.2026.120",
                source: .appStoreConnect,
                storeApp: storeApp
            )
            appReview.ascReviewID = review.reviewID
            appReview.assumedLanguageCode = review.storefront == "de" ? "de" : "en"
            if let response = review.response {
                appReview.developerResponseID = "\(review.reviewID)-response"
                appReview.developerResponseBody = response
                appReview.developerResponseState = "PUBLISHED"
                appReview.developerResponseModifiedAt = date(daysAgo: max(0, review.daysAgo - 1))
            }
            modelContext.insert(appReview)
        }

        try? modelContext.save()
    }

    private static func date(daysAgo: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now
    }
}
#endif
