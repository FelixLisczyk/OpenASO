import SwiftUI

struct IconButton<Icon: View>: View {
    let accessibilityLabel: String
    let helpText: String?
    let size: CGFloat
    let isLoading: Bool
    let action: () -> Void
    @ViewBuilder let icon: () -> Icon

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    init(
        accessibilityLabel: String,
        helpText: String? = nil,
        size: CGFloat = 30,
        isLoading: Bool = false,
        action: @escaping () -> Void,
        @ViewBuilder icon: @escaping () -> Icon
    ) {
        self.accessibilityLabel = accessibilityLabel
        self.helpText = helpText
        self.size = size
        self.isLoading = isLoading
        self.action = action
        self.icon = icon
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(backgroundColor)

                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    icon()
                        .frame(width: iconSize, height: iconSize)
                        .foregroundStyle(iconColor)
                }
            }
            .frame(width: size, height: size)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .onHover { isHovered = $0 }
        .accessibilityLabel(accessibilityLabel)
        .help(helpText ?? accessibilityLabel)
    }

    private var iconSize: CGFloat {
        max(14, size * 0.56)
    }

    private var cornerRadius: CGFloat {
        max(6, size * 0.24)
    }

    private var backgroundColor: Color {
        guard isHovered, isEnabled else { return .clear }
        return Color.accentColor.opacity(0.12)
    }

    private var iconColor: Color {
        isEnabled ? .secondary : .secondary.opacity(0.45)
    }
}

#Preview("Icon Button") {
    HStack(spacing: 12) {
        IconButton(accessibilityLabel: "Translate", action: {}) {
            Image(systemName: "translate")
        }

        IconButton(accessibilityLabel: "Translate", isLoading: true, action: {}) {
            Image(systemName: "translate")
        }
    }
    .padding()
}
