import SwiftUI

/// Lineární průběh v barvách tématu.
/// Systémový `ProgressView` na macOS barvu `.tint` ignoruje a kreslí vždy systémový accent.
struct ThemedProgressStyle: ProgressViewStyle {
    func makeBody(configuration: Configuration) -> some View {
        if let fraction = configuration.fractionCompleted {
            ThemedProgressBar(fraction: fraction)
        } else {
            // Neurčitý průběh (načítání) zůstává systémový.
            ProgressView(configuration)
                .progressViewStyle(.circular)
        }
    }
}

private struct ThemedProgressBar: View {
    @Environment(\.theme) private var theme
    @Environment(\.progressTint) private var tint
    @Environment(\.controlActiveState) private var activeState
    let fraction: Double

    var body: some View {
        let clamped = min(max(fraction, 0), 1)
        let fill = tint ?? theme.accent
        Capsule()
            .fill(theme.progressTrack)
            .frame(height: 6)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(fill.opacity(activeState == .inactive ? 0.75 : 1))
                        .frame(width: clamped > 0 ? max(proxy.size.width * clamped, 6) : 0)
                }
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement()
            .accessibilityValue(Text("\(Int((clamped * 100).rounded())) %"))
    }
}

private struct ProgressTintKey: EnvironmentKey {
    static let defaultValue: Color? = nil
}

extension EnvironmentValues {
    /// Barva výplně průběhu (nil = accent tématu).
    var progressTint: Color? {
        get { self[ProgressTintKey.self] }
        set { self[ProgressTintKey.self] = newValue }
    }
}

extension View {
    func progressTint(_ color: Color?) -> some View {
        environment(\.progressTint, color)
    }
}
