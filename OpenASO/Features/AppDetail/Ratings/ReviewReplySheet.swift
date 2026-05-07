import SwiftUI

struct ReviewReplyDraft: Identifiable {
    let review: AppStoreReviewValue

    var id: String {
        review.reviewKey
    }
}

struct ReviewReplySheet: View {
    let review: AppStoreReviewValue
    let errorMessage: String?
    let isSending: Bool
    let send: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var bodyText: String

    init(
        review: AppStoreReviewValue,
        errorMessage: String?,
        isSending: Bool,
        send: @escaping (String) -> Void
    ) {
        self.review = review
        self.errorMessage = errorMessage
        self.isSending = isSending
        self.send = send
        _bodyText = State(initialValue: review.developerResponseBody ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(review.developerResponseBody == nil ? "Reply to Review" : "Edit Review Reply")
                .font(.title3.weight(.semibold))

            Text(review.title)
                .font(.headline)

            TextEditor(text: $bodyText)
                .font(.body)
                .frame(minHeight: 160)
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(.quaternary)
                }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .disabled(isSending)

                Button("Send Reply") {
                    send(bodyText)
                }
                .disabled(isSending || bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
    }
}
