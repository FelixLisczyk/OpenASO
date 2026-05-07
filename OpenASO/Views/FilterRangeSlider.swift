import SwiftUI

struct FilterRangeSlider: View {
    @Binding var range: ClosedRange<Double>

    let configuration: MetricFilterRange

    private let thumbSize: CGFloat = 18

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(configuration.title)
                    .font(.subheadline)

                Spacer()

                Text(valueText(for: range))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            GeometryReader { proxy in
                let trackWidth = max(1, proxy.size.width - thumbSize)
                let lowerX = xPosition(for: range.lowerBound, trackWidth: trackWidth)
                let upperX = xPosition(for: range.upperBound, trackWidth: trackWidth)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.18))
                        .frame(width: trackWidth, height: 4)
                        .offset(x: thumbSize / 2)

                    Capsule()
                        .fill(Color.accentColor.opacity(0.7))
                        .frame(width: max(0, upperX - lowerX), height: 4)
                        .offset(x: lowerX)

                    FilterRangeSliderThumb(size: thumbSize)
                        .position(x: lowerX, y: thumbSize / 2)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    updateLowerBound(with: value.location.x, trackWidth: trackWidth)
                                }
                        )

                    FilterRangeSliderThumb(size: thumbSize)
                        .position(x: upperX, y: thumbSize / 2)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    updateUpperBound(with: value.location.x, trackWidth: trackWidth)
                                }
                        )
                }
                .frame(height: thumbSize)
            }
            .frame(height: thumbSize)

            HStack {
                Text(boundText(configuration.bounds.lowerBound))
                Spacer()
                Text(boundText(configuration.bounds.upperBound))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
    }

    private func xPosition(for value: Double, trackWidth: CGFloat) -> CGFloat {
        let bounds = configuration.bounds
        let fraction = (value - bounds.lowerBound) / (bounds.upperBound - bounds.lowerBound)
        return thumbSize / 2 + trackWidth * CGFloat(fraction)
    }

    private func value(for xPosition: CGFloat, trackWidth: CGFloat) -> Double {
        let bounds = configuration.bounds
        let fraction = min(1, max(0, Double((xPosition - thumbSize / 2) / trackWidth)))
        let rawValue = bounds.lowerBound + fraction * (bounds.upperBound - bounds.lowerBound)
        return (rawValue / configuration.step).rounded() * configuration.step
    }

    private func updateLowerBound(with xPosition: CGFloat, trackWidth: CGFloat) {
        let value = value(for: xPosition, trackWidth: trackWidth)
        let lowerBound = min(max(configuration.bounds.lowerBound, value), range.upperBound)
        range = lowerBound...range.upperBound
    }

    private func updateUpperBound(with xPosition: CGFloat, trackWidth: CGFloat) {
        let value = value(for: xPosition, trackWidth: trackWidth)
        let upperBound = max(min(configuration.bounds.upperBound, value), range.lowerBound)
        range = range.lowerBound...upperBound
    }

    private func valueText(for range: ClosedRange<Double>) -> String {
        "\(boundText(range.lowerBound)) - \(boundText(range.upperBound))"
    }

    private func boundText(_ value: Double) -> String {
        "\(Int(value.rounded()))"
    }
}

private struct FilterRangeSliderThumb: View {
    let size: CGFloat

    var body: some View {
        Circle()
            .fill(Color(NSColor.controlBackgroundColor))
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
            .overlay(
                Circle()
                    .stroke(Color.secondary.opacity(0.18))
            )
    }
}
