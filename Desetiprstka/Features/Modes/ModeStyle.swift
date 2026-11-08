import SwiftUI

/// Jemná vizuální identita režimů – jen systémové barvy a SF Symbols.
extension GameMode {
    var tint: Color {
        switch self {
        case .practice: .gray
        case .timeAttack: .orange
        case .sprint: .pink
        case .accuracyChallenge: .teal
        case .survival: .red
        case .endless: .indigo
        case .exam: .brown
        case .customText: .mint
        case .speedTest: .cyan
        }
    }

    /// Kratší popis do karty.
    var cardSubtitle: String {
        switch self {
        case .practice: String(localized: "Klidné cvičení, které tě posouvá osnovou.")
        case .timeAttack: String(localized: "Co nejvíc správných znaků za daný čas.")
        case .sprint: String(localized: "Krátký text na jeden nádech. Na čas.")
        case .accuracyChallenge: String(localized: "Přesnost před rychlostí. Žádné zbytečné chyby.")
        case .survival: String(localized: "Každá chyba stojí život, vlny zrychlují.")
        case .endless: String(localized: "Piš, dokud chceš. Bez cílové čáry.")
        case .exam: String(localized: "Opis na čas se školním hodnocením: čisté úhozy, % chyb, známka.")
        case .customText: String(localized: "Vlož vlastní text a opiš ho – článek, poznámky, úkol.")
        case .speedTest: String(localized: "Klasický test na čas. Výsledek ve WPM, CPM i úhozech.")
        }
    }
}

/// Ikona režimu v zaobleném čtverci.
struct ModeIcon: View {
    let mode: GameMode
    var size: CGFloat = 36

    var body: some View {
        Image(systemName: mode.symbol)
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(mode.tint)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .fill(mode.tint.opacity(0.15))
            )
            .accessibilityHidden(true)
    }
}

/// Malý štítek (chip) s volitelnou ikonou.
struct InfoChip: View {
    let text: String
    var symbol: String?
    var tint: Color = .secondary

    var body: some View {
        HStack(spacing: 4) {
            if let symbol {
                Image(systemName: symbol)
            }
            Text(text)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(tint == .secondary ? Color.secondary : tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill((tint == .secondary ? Color.primary : tint).opacity(0.1)))
        .lineLimit(1)
        .fixedSize()
    }
}

/// Štítek stavu karty: Nový rekord / Dnes / Nevyzkoušeno.
struct ModeBadgeView: View {
    let badge: ModeBadge
    let tint: Color
    @State private var bounce = 0

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: badge.symbol)
                .symbolEffect(.bounce, value: bounce)
            Text(badge.title)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(foreground)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(background))
        .lineLimit(1)
        .fixedSize()
        .task(id: badge) {
            // Mikroanimace jen u nového rekordu.
            guard badge == .newRecord else { return }
            try? await Task.sleep(nanoseconds: 350_000_000)
            bounce += 1
        }
    }

    private var foreground: Color {
        switch badge {
        case .newRecord: .orange
        case .bestToday: tint
        case .notTried: .secondary
        }
    }

    private var background: Color {
        switch badge {
        case .newRecord: Color.yellow.opacity(0.18)
        case .bestToday: tint.opacity(0.12)
        case .notTried: Color.primary.opacity(0.06)
        }
    }
}
