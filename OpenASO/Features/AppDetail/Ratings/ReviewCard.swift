import SwiftUI

struct ReviewEmptyContent: View {
    let state: ReviewEmptyState

    var body: some View {
        switch state {
        case .noReviews:
            ContentUnavailableView(
                "No Reviews",
                systemImage: "text.bubble",
                description: Text("Reviews will appear here when they are available.")
            )
        case .noMatchingReviews:
            ContentUnavailableView(
                "No Matching Reviews",
                systemImage: "line.3.horizontal.decrease.circle",
                description: Text("Adjust the time period or rating filter.")
            )
        }
    }
}

enum ReviewEmptyState {
    case noReviews
    case noMatchingReviews
}

struct ReviewCard: View {
    let review: AppStoreReviewValue
    let storefrontDefinition: StorefrontDefinition?
    let canReply: Bool
    let canTranslate: Bool
    let isTranslating: Bool
    let translationError: String?
    let translateAction: () -> Void
    let replyAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(review.title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    ReviewRatingStars(rating: review.rating)
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(review.reviewedAt.formatted(.dateTime.month(.twoDigits).day(.twoDigits).year()))
                        .font(.callout)
                        .monospacedDigit()

                    Text("\(storefrontFlag) \(review.reviewerName)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            Text(review.content)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)

            if let translatedContent = review.translatedContent, !translatedContent.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("English Translation", systemImage: "translate")
                            .font(.caption.weight(.semibold))
                        Spacer()
                        if let translatedAt = review.translatedAt {
                            Text(translatedAt.formatted(.dateTime.month(.twoDigits).day(.twoDigits).hour().minute()))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let translatedTitle = review.translatedTitle, !translatedTitle.isEmpty, translatedTitle != review.title {
                        Text(translatedTitle)
                            .font(.callout.weight(.semibold))
                    }

                    Text(translatedContent)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
                .padding(12)
                .background(Color.accentColor.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            if let responseBody = review.developerResponseBody, !responseBody.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Developer Response", systemImage: "arrowshape.turn.up.left.fill")
                            .font(.caption.weight(.semibold))
                        Spacer()
                        if let state = review.developerResponseState {
                            Text(state.capitalized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text(responseBody)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
                .padding(12)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            if let translationError {
                Label(translationError, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()

                if canTranslate {
                    IconButton(
                        accessibilityLabel: review.translatedContent == nil ? "Translate Review" : "Retranslate Review",
                        helpText: review.translatedContent == nil ? "Translate" : "Retranslate",
                        isLoading: isTranslating,
                        action: translateAction
                    ) {
                        Image(systemName: "translate")
                    }
                    .disabled(isTranslating || review.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if canReply {
                    Button(review.developerResponseBody == nil ? "Reply" : "Edit Reply", action: replyAction)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.035), radius: 4, x: 0, y: 1)
    }

    private var storefrontFlag: String {
        storefrontDefinition?.flagEmoji ?? StorefrontFilter.storefront(
            code: review.storefront,
            title: review.storefront.uppercased()
        ).icon
    }
}

private struct ReviewRatingStars: View {
    let rating: Int

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { index in
                Image(systemName: index <= rating ? "star.fill" : "star")
                    .foregroundStyle(.orange)
            }
        }
        .font(.callout.weight(.semibold))
    }
}
