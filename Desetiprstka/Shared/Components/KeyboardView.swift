import SwiftUI

/// Vizuální klávesnice Macu.
///
/// - Známé klávesy jsou podbarvené barvou prstu.
/// - Zvýrazněné klávesy (další znak) svítí plnou barvou prstu.
/// - Pokud je předán `onToggle`, dají se klávesy z osnovy proklikávat.
struct KeyboardView: View {
    let layout: KeyboardLayout
    var knownKeys: Set<String> = []
    var highlightedKeyIDs: Set<String> = []
    var showsFingerColorsForAll = false
    var onToggle: ((String) -> Void)?
    /// Heatmapa: přesnost 0–1 podle klávesy z osnovy. Klávesy bez dat jsou šedé.
    var heatmap: [String: Double]?
    var selectedKey: String?
    /// Klik na klávesu v režimu heatmapy.
    var onSelect: ((String) -> Void)?

    var body: some View {
        GeometryReader { proxy in
            let unit = proxy.size.width / KeyboardLayout.rowUnits
            VStack(spacing: 0) {
                ForEach(layout.rows.indices, id: \.self) { rowIndex in
                    HStack(spacing: 0) {
                        ForEach(layout.rows[rowIndex]) { key in
                            keyView(key, unit: unit)
                        }
                    }
                }
            }
        }
        .aspectRatio(KeyboardLayout.rowUnits / CGFloat(layout.rows.count), contentMode: .fit)
        .animation(.easeOut(duration: 0.12), value: highlightedKeyIDs)
    }

    @ViewBuilder
    private func keyView(_ key: KeyboardKey, unit: CGFloat) -> some View {
        let cap = KeyCapView(key: key, appearance: appearance(for: key), unit: unit)
            .frame(width: unit * key.width, height: unit)

        if let onToggle, let learnable = key.learnableKey {
            cap
                .contentShape(Rectangle())
                .onTapGesture { onToggle(learnable) }
                .help(knownKeys.contains(learnable) ? String(localized: "Odebrat ze známých") : String(localized: "Přidat mezi známé"))
        } else if let onSelect, let learnable = key.learnableKey {
            cap
                .contentShape(Rectangle())
                .onTapGesture { onSelect(learnable) }
                .help("Zobrazit statistiku klávesy \(Curriculum.displayName(for: learnable))")
        } else {
            cap
        }
    }

    private func appearance(for key: KeyboardKey) -> KeyCapView.Appearance {
        if highlightedKeyIDs.contains(key.id) { return .target }
        if let heatmap {
            guard let learnable = key.learnableKey else {
                return key.kind == .space ? .unknown : .decoration
            }
            let isSelected = selectedKey == learnable
            if let accuracy = heatmap[learnable] {
                return .heat(HeatmapScale.color(for: accuracy), selected: isSelected)
            }
            return isSelected ? .heat(Color.primary.opacity(0.12), selected: true) : .unknown
        }
        switch key.kind {
        case .decoration:
            return .decoration
        case .space:
            return .known
        case .character, .leftShift, .rightShift:
            guard let learnable = key.learnableKey else { return .decoration }
            if knownKeys.contains(learnable) || showsFingerColorsForAll { return .known }
            return .unknown
        }
    }
}

/// Jedna klávesa.
struct KeyCapView: View {
    enum Appearance: Equatable {
        case target
        case known
        case unknown
        case decoration
        case heat(Color, selected: Bool)
    }

    private var isSelected: Bool {
        if case .heat(_, let selected) = appearance { return selected }
        return false
    }

    let key: KeyboardKey
    let appearance: Appearance
    let unit: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: unit * 0.16, style: .continuous)

        ZStack {
            shape.fill(fill)
            shape.strokeBorder(
                isSelected ? Color.primary.opacity(0.75) : Color.primary.opacity(appearance == .target ? 0 : 0.08),
                lineWidth: isSelected ? 2 : 1
            )
            labels
        }
        .padding(unit * 0.04)
        .shadow(color: appearance == .target ? key.finger.color.opacity(0.55) : .clear,
                radius: appearance == .target ? unit * 0.2 : 0)
        .scaleEffect(appearance == .target ? 1.04 : 1)
        .zIndex(appearance == .target ? 1 : 0)
    }

    private var fill: Color {
        switch appearance {
        case .target: key.finger.color
        case .known: key.finger.color.opacity(key.kind == .space ? 0.12 : 0.2)
        case .unknown: Color.primary.opacity(0.05)
        case .decoration: Color.primary.opacity(0.03)
        case .heat(let color, _): color
        }
    }

    private var foreground: Color {
        switch appearance {
        case .target: .white
        case .known, .heat: .primary
        case .unknown, .decoration: .secondary
        }
    }

    private var labels: some View {
        ZStack {
            if let secondary = key.secondary {
                Text(secondary)
                    .font(.system(size: unit * 0.19, weight: .medium, design: .rounded))
                    .foregroundStyle(foreground.opacity(0.6))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.leading, unit * 0.12)
                    .padding(.top, unit * 0.08)
            }

            Text(key.label)
                .font(.system(size: key.kind == .character ? unit * 0.34 : unit * 0.26,
                              weight: .medium, design: .rounded))
                .foregroundStyle(appearance == .decoration ? foreground.opacity(0.6) : foreground)

            if key.isHomingKey {
                Capsule()
                    .fill(foreground.opacity(0.55))
                    .frame(width: unit * 0.2, height: max(1.5, unit * 0.035))
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, unit * 0.13)
            }
        }
    }
}

/// Legenda barev prstů.
struct FingerLegend: View {
    var body: some View {
        HStack(spacing: 16) {
            ForEach(Finger.legend) { finger in
                HStack(spacing: 6) {
                    Circle()
                        .fill(finger.color)
                        .frame(width: 9, height: 9)
                    Text(finger.kindName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// Barevná škála heatmapy podle přesnosti – střídmé, systémové barvy.
enum HeatmapScale {
    static let steps: [(threshold: Double, color: Color, label: String)] = [
        (0.97, .green, "97 %+"),
        (0.93, .mint, "93–97 %"),
        (0.88, .yellow, "88–93 %"),
        (0.80, .orange, "80–88 %"),
        (0, .red, String(localized: "pod 80 %")),
    ]

    static func baseColor(for accuracy: Double) -> Color {
        let step = steps.first { accuracy >= $0.threshold } ?? steps[steps.count - 1]
        return step.color
    }

    static func color(for accuracy: Double) -> Color {
        baseColor(for: accuracy).opacity(0.5)
    }
}

/// Legenda heatmapy.
struct HeatmapLegend: View {
    var body: some View {
        HStack(spacing: 14) {
            ForEach(HeatmapScale.steps, id: \.label) { step in
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(step.color.opacity(0.5))
                        .frame(width: 12, height: 12)
                    Text(step.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
