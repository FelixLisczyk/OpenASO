import SwiftUI

struct PinIconButton: View {
    let isPinned: Bool
    let isVisible: Bool
    let size: CGFloat
    let action: () -> Void

    @State private var isHovered = false

    init(
        isPinned: Bool,
        isVisible: Bool = true,
        size: CGFloat = 24,
        action: @escaping () -> Void
    ) {
        self.isPinned = isPinned
        self.isVisible = isVisible
        self.size = size
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: isPinned ? "pin.fill" : "pin")
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(iconStyle)
                .frame(width: size, height: size)
                .background {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(backgroundStyle)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(borderStyle)
                }
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .opacity(isVisible ? 1 : 0)
        .disabled(!isVisible)
        .onHover { isHovered = $0 }
        .accessibilityLabel(isPinned ? "Unpin App" : "Pin App")
        .accessibilityHidden(!isVisible)
        .help(isPinned ? "Unpin App" : "Pin App")
    }

    private var iconSize: CGFloat {
        max(10, size * 0.52)
    }

    private var cornerRadius: CGFloat {
        max(6, size * 0.28)
    }

    private var iconStyle: AnyShapeStyle {
        if isPinned {
            return AnyShapeStyle(Color.accentColor)
        }

        return AnyShapeStyle(Color.secondary)
    }

    private var backgroundStyle: AnyShapeStyle {
        if isHovered {
            return AnyShapeStyle(Color.accentColor.opacity(0.14))
        }

        if isPinned {
            return AnyShapeStyle(Color.accentColor.opacity(0.10))
        }

        return AnyShapeStyle(Color.clear)
    }

    private var borderStyle: AnyShapeStyle {
        if isHovered || isPinned {
            return AnyShapeStyle(Color.accentColor.opacity(isHovered ? 0.30 : 0.20))
        }

        return AnyShapeStyle(Color.clear)
    }
}

#Preview("Pin Icon Button") {
    HStack(spacing: 12) {
        PinIconButton(isPinned: false, size: 24) {}
        PinIconButton(isPinned: true, size: 24) {}
        PinIconButton(isPinned: false, size: 32) {}
    }
    .padding()
}
