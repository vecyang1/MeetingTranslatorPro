import SwiftUI

/// Animated audio level bars indicator — waveform style
struct AudioLevelIndicator: View {
    let level: Float
    let barCount: Int
    let color: Color

    init(level: Float, barCount: Int = 5, color: Color = .green) {
        self.level = level
        self.barCount = barCount
        self.color = color
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(barColor(for: index))
                    .frame(width: 3, height: barHeight(for: index))
                    .animation(.easeOut(duration: 0.08), value: level)
            }
        }
        .frame(height: 18)
    }

    private func barHeight(for index: Int) -> CGFloat {
        let threshold = Float(index) / Float(barCount)
        let active = level > threshold
        let minHeight: CGFloat = 3
        let maxHeight: CGFloat = 18
        if active {
            let progress = min(1.0, (level - threshold) * Float(barCount))
            return minHeight + CGFloat(progress) * (maxHeight - minHeight) * CGFloat(index + 1) / CGFloat(barCount)
        }
        return minHeight
    }

    private func barColor(for index: Int) -> Color {
        let threshold = Float(index) / Float(barCount)
        if level > threshold {
            return color.opacity(0.6 + Double(index) * 0.08)
        }
        return color.opacity(0.12)
    }
}

/// Circular pulsing recording indicator
struct RecordingPulse: View {
    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(Color.red)
            .frame(width: 8, height: 8)
            .scaleEffect(isPulsing ? 1.3 : 1.0)
            .opacity(isPulsing ? 0.7 : 1.0)
            .animation(
                .easeInOut(duration: 0.8)
                .repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear { isPulsing = true }
    }
}

/// Animated waveform dots for active listening state
struct ListeningWaveform: View {
    let color: Color
    @State private var animating = false

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<5, id: \.self) { i in
                Circle()
                    .fill(color)
                    .frame(width: 4, height: 4)
                    .scaleEffect(animating ? 1.0 : 0.4)
                    .animation(
                        .easeInOut(duration: 0.5)
                        .repeatForever(autoreverses: true)
                        .delay(Double(i) * 0.1),
                        value: animating
                    )
            }
        }
        .onAppear { animating = true }
    }
}
