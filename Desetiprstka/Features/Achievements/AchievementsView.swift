import SwiftUI
import SwiftData

/// Přehled odznaků – odemčené i zamčené s postupem.
struct AchievementsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var unlockedRecords: [AchievementRecord]
    @Query private var records: [PersonalRecord]
    @Query(sort: \PlayerProgress.createdAt) private var progresses: [PlayerProgress]
    @Query(sort: \UserProfile.createdAt) private var profiles: [UserProfile]

    private let columns = [GridItem(.adaptive(minimum: 260, maximum: 400), spacing: 16)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(AchievementCatalog.all) { achievement in
                        AchievementCard(
                            achievement: achievement,
                            unlockedAt: unlockDates[achievement.id],
                            context: context
                        )
                    }
                }
            }
            .padding(28)
            .frame(maxWidth: 1000)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Odznaky")
        .task { ProgressStore(context: modelContext).refreshAchievements() }
    }

    private var header: some View {
        let unlocked = unlockDates.count
        let total = AchievementCatalog.all.count
        return VStack(alignment: .leading, spacing: 8) {
            Text("Odznaky")
                .font(.title2.weight(.semibold))
            HStack(spacing: 12) {
                ProgressView(value: Double(unlocked), total: Double(total))
                    .frame(maxWidth: 260)
                Text("\(unlocked) z \(total) odemčeno")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }

    private var unlockDates: [String: Date] {
        Dictionary(unlockedRecords.map { ($0.achievementID, $0.unlockedAt) }, uniquingKeysWith: { first, _ in first })
    }

    private var context: AchievementContext {
        var values: [RecordKind: Double] = [:]
        for record in records {
            if let kind = record.kind { values[kind] = record.value }
        }
        let progress = progresses.first
        return AchievementContext(
            totalSessions: Double(progress?.totalSessions ?? 0),
            totalCharacters: Double(progress?.totalCharacters ?? 0),
            bestWPM: values[.bestWPM] ?? 0,
            perfectSessions: Double(progress?.perfectSessions ?? 0),
            longestStreak: Double(progress?.longestStreak ?? 0),
            bestCombo: values[.longestCombo] ?? 0,
            learnedKeys: Double(profiles.first?.knownKeySet.intersection(Curriculum.allKeySet).count ?? 0),
            dailyChallengesCompleted: Double(progress?.dailyChallengesCompleted ?? 0),
            bestSurvival: values[.survival] ?? 0
        )
    }
}

private struct AchievementCard: View {
    @Environment(\.theme) private var theme
    let achievement: Achievement
    let unlockedAt: Date?
    let context: AchievementContext

    private var isUnlocked: Bool { unlockedAt != nil }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: achievement.symbol)
                .font(.title2)
                .foregroundStyle(isUnlocked ? theme.accent : Color.secondary)
                .frame(width: 48, height: 48)
                .background(
                    Circle().fill(isUnlocked ? theme.accent.opacity(0.14) : Color.primary.opacity(0.06))
                )
                .overlay(alignment: .bottomTrailing) {
                    if !isUnlocked {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(3)
                            .background(Circle().fill(.background))
                    }
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(achievement.title)
                    .font(.headline)
                    .foregroundStyle(isUnlocked ? Color.primary : Color.secondary)
                Text(achievement.detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let unlockedAt {
                    Text("Odemčeno \(unlockedAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                } else {
                    ProgressView(value: achievement.progress(in: context))
                        .padding(.top, 4)
                    Text(achievement.formattedProgress(in: context))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.primary.opacity(isUnlocked ? 0.05 : 0.025))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
        )
        .opacity(isUnlocked ? 1 : 0.85)
    }
}
