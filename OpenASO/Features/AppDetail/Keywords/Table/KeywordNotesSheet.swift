import SwiftData
import SwiftUI

struct KeywordNotesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var track: TrackedAppKeyword

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(track.term)
                    .font(.title3.weight(.semibold))
                Text(track.storefront.uppercased())
                    .font(.subheadline.monospaced())
                    .foregroundStyle(.secondary)
            }

            TextEditor(text: $track.notes)
                .font(.body)
                .frame(minWidth: 460, minHeight: 220)
                .scrollContentBackground(.hidden)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))

            HStack {
                Spacer()
                Button("Done") {
                    try? modelContext.save()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 540)
    }
}

#Preview("Notes Sheet") {
    KeywordTableNotesPreview()
}
