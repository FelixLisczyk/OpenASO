import SwiftUI

struct CustomSegmentedPicker<Selection: Hashable>: View {
    struct Segment: Identifiable {
        let id: Selection
        let title: String

        init(_ title: String, value: Selection) {
            self.id = value
            self.title = title
        }
    }

    let segments: [Segment]

    @Binding var selection: Selection

    @Namespace private var selectionAnimation
    @State private var hoveredSelection: Selection?

    var body: some View {
        if #available(macOS 26.0, *) {
            glassPickerBody
        } else {
            materialPickerBody
        }
    }

    @available(macOS 26.0, *)
    private var glassPickerBody: some View {
        HStack(spacing: 6) {
            ForEach(segments) { segment in
                Button {
                    select(segment.id)
                } label: {
                    glassSegmentLabel(segment)
                }
                .buttonStyle(.plain)
                .contentShape(.rect)
                .onHover { isHovering in
                    hoveredSelection = isHovering ? segment.id : nil
                }
                .accessibilityAddTraits(selection == segment.id ? .isSelected : [])
            }
        }
        .padding(4)
        .glassEffect(.regular.interactive())
    }

    private var materialPickerBody: some View {
        HStack(spacing: 6) {
            ForEach(segments) { segment in
                Button {
                    select(segment.id)
                } label: {
                    segmentLabel(segment)
                }
                .buttonStyle(.plain)
                .contentShape(.rect)
                .onHover { isHovering in
                    hoveredSelection = isHovering ? segment.id : nil
                }
                .accessibilityAddTraits(selection == segment.id ? .isSelected : [])
            }
        }
        .padding(4)
        .background {
            Capsule(style: .continuous)
                .fill(.thinMaterial)
        }
        .overlay {
            Capsule(style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        }
    }

    @available(macOS 26.0, *)
    private func glassSegmentLabel(_ segment: Segment) -> some View {
        Text(segment.title)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(selection == segment.id ? .primary : .secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .frame(minWidth: 72, minHeight: 26)
            .padding(.horizontal, 12)
            .background {
                glassSegmentBackground(for: segment)
            }
            .contentShape(Capsule(style: .continuous))
            .fixedSize(horizontal: false, vertical: true)
    }

    private func segmentLabel(_ segment: Segment) -> some View {
        Text(segment.title)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(selection == segment.id ? .primary : .secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .frame(minWidth: 72, minHeight: 26)
            .padding(.horizontal, 12)
            .background {
                segmentBackground(for: segment)
            }
            .contentShape(Capsule(style: .continuous))
            .fixedSize(horizontal: false, vertical: true)
    }

    @available(macOS 26.0, *)
    @ViewBuilder
    private func glassSegmentBackground(for segment: Segment) -> some View {
        if selection == segment.id {
            Color.clear
                .glassEffect(.regular.interactive())
                .matchedGeometryEffect(id: "selectedSegment", in: selectionAnimation)
                .glassEffectID("selectedSegment", in: selectionAnimation)
        } else if hoveredSelection == segment.id {
            Capsule(style: .continuous)
                .fill(.primary.opacity(0.10))
        }
    }

    @ViewBuilder
    private func segmentBackground(for segment: Segment) -> some View {
        if selection == segment.id {
            Capsule(style: .continuous)
                .fill(.regularMaterial)
                .matchedGeometryEffect(id: "selectedSegment", in: selectionAnimation)
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(.white.opacity(0.24), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.14), radius: 4, y: 2)
        } else if hoveredSelection == segment.id {
            Capsule(style: .continuous)
                .fill(.primary.opacity(0.06))
        }
    }

    private func select(_ segment: Selection) {
        guard selection != segment else {
            return
        }

        withAnimation(.easeInOut(duration: 0.22)) {
            selection = segment
        }
    }
}

#Preview {
    @Previewable @State var selection = "All"

    CustomSegmentedPicker(
        segments: [
            .init("All", value: "All"),
            .init("Favorites", value: "Favorites"),
            .init("Recent", value: "Recent")
        ],
        selection: $selection
    )
    .padding()
    .frame(width: 360)
}
