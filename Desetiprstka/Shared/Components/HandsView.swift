import SwiftUI

/// Stylizované ruce – zvýrazní prst, kterým se má klávesa zmáčknout.
struct HandsView: View {
    var activeFingers: Set<Finger>
    var scale: CGFloat = 1

    var body: some View {
        HStack(spacing: 56 * scale) {
            HandView(hand: .left, activeFingers: activeFingers, scale: scale)
            HandView(hand: .right, activeFingers: activeFingers, scale: scale)
        }
        .animation(.easeOut(duration: 0.15), value: activeFingers)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(activeFingers.map(\.name).sorted().joined(separator: " a "))
    }
}

private struct HandView: View {
    let hand: Hand
    let activeFingers: Set<Finger>
    let scale: CGFloat

    private var fingers: [Finger] {
        switch hand {
        case .left: [.leftPinky, .leftRing, .leftMiddle, .leftIndex]
        case .right: [.rightIndex, .rightMiddle, .rightRing, .rightPinky]
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Dlaň
            RoundedRectangle(cornerRadius: 24 * scale, style: .continuous)
                .fill(Color.primary.opacity(0.07))
                .frame(width: 118 * scale, height: 54 * scale)

            HStack(alignment: .bottom, spacing: 6 * scale) {
                if hand == .right { thumb }
                ForEach(fingers) { finger in
                    Capsule()
                        .fill(color(for: finger))
                        .frame(width: 21 * scale, height: height(for: finger))
                        .overlay(alignment: .top) {
                            Circle()
                                .fill(Color.white.opacity(activeFingers.contains(finger) ? 0.45 : 0))
                                .frame(width: 8 * scale, height: 8 * scale)
                                .padding(.top, 6 * scale)
                        }
                }
                if hand == .left { thumb }
            }
            .padding(.bottom, 36 * scale)
        }
        .frame(height: 118 * scale, alignment: .bottom)
    }

    private var thumb: some View {
        Capsule()
            .fill(color(for: .thumbs))
            .frame(width: 21 * scale, height: 42 * scale)
            .rotationEffect(.degrees(hand == .left ? 38 : -38))
            .offset(x: (hand == .left ? 6 : -6) * scale, y: 30 * scale)
    }

    private func color(for finger: Finger) -> Color {
        activeFingers.contains(finger) ? finger.color : Color.primary.opacity(0.13)
    }

    private func height(for finger: Finger) -> CGFloat {
        let base: CGFloat
        switch finger {
        case .leftPinky, .rightPinky: base = 44
        case .leftRing, .rightRing: base = 60
        case .leftMiddle, .rightMiddle: base = 68
        case .leftIndex, .rightIndex: base = 58
        case .thumbs: base = 42
        }
        return base * scale
    }
}
