import SwiftUI

/// Ukazatel postupu přes 4 stupně × 3 podúrovně.
struct LevelTrackView: View {
    @Environment(\.theme) private var theme
    let difficulty: Difficulty

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ForEach(ExerciseStage.allCases) { stage in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 3) {
                        ForEach(0..<Difficulty.levelsPerStage, id: \.self) { sub in
                            let level = stage.rawValue * Difficulty.levelsPerStage + sub + 1
                            Capsule()
                                .fill(level <= difficulty.level ? theme.accent : Color.primary.opacity(0.1))
                                .frame(height: 6)
                        }
                    }
                    Label(stage.shortTitle, systemImage: stage.symbol)
                        .font(.caption)
                        .foregroundStyle(stage == difficulty.stage ? .primary : .secondary)
                        .fontWeight(stage == difficulty.stage ? .semibold : .regular)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
