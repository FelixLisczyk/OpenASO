import SwiftUI

struct TertiaryActionButton: View {
    let title: String
    let systemImage: String?
    let helpText: String?
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    init(
        _ title: String,
        systemImage: String? = nil,
        helpText: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.helpText = helpText
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Label {
                Text(title)
            } icon: {
                if let systemImage {
                    Image(systemName: systemImage)
                }
            }
            .font(.callout)
            .foregroundStyle(foregroundStyle)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(helpText ?? title)
        .accessibilityLabel(title)
    }

    private var foregroundStyle: AnyShapeStyle {
        guard isEnabled else {
            return AnyShapeStyle(Color.secondary.opacity(0.45))
        }

        if isHovered {
            return AnyShapeStyle(Color.accentColor)
        }

        return AnyShapeStyle(Color.secondary)
    }
}

#Preview("Tertiary Action Button") {
    HStack(spacing: 16) {
        TertiaryActionButton("Show Screenshots", systemImage: "photo.stack") {}
        TertiaryActionButton("Download Screenshots for Top 10 Apps", systemImage: "arrow.down.square") {}
            .disabled(true)
    }
    .padding()
}
