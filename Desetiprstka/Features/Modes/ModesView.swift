import SwiftUI
import SwiftData

/// Přehled herních režimů: doporučení, výzva dne a karty s rekordy a cíli.
struct ModesView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PracticeSession.date, order: .reverse) private var sessions: [PracticeSession]
    @Query private var records: [PersonalRecord]
    @Query(sort: \UserProfile.createdAt) private var profiles: [UserProfile]
    @Query(sort: \PlayerProgress.createdAt) private var progresses: [PlayerProgress]
    @Query(sort: \DailyChallengeRecord.dayKey, order: .reverse) private var challenges: [DailyChallengeRecord]
    @AppStorage(SettingsKey.lastTimeAttackDuration) private var timeAttackSeconds = TimeAttackDuration.seconds60.rawValue
    @AppStorage(SettingsKey.lastExamDuration) private var examMinutes = ExamDuration.minutes10.rawValue
    @AppStorage(SettingsKey.lastSpeedTestDuration) private var speedTestSeconds = TimeAttackDuration.seconds30.rawValue
    @AppStorage(SettingsKey.customText) private var customText = ""
    @AppStorage(SettingsKey.speedUnit) private var speedUnit: SpeedUnit = .wpm
    @State private var showsCustomTextEditor = false

    var body: some View {
        let input = insightsInput
        let insights = ModeInsightsBuilder.insights(for: input)
        let recommendation = ModeInsightsBuilder.recommendation(for: input, insights: insights)

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                RecommendationHero(recommendation: recommendation) {
                    appState.startPractice(recommendation.configuration)
                }

                if let record = todaysChallenge, let challenge = record.challenge {
                    DailyChallengeStrip(
                        challenge: challenge,
                        progress: record.progress,
                        isCompleted: record.isCompleted,
                        onStart: { startChallenge(challenge) }
                    )
                }

                // Grid (ne LazyVGrid) – karty v jednom řádku mají stejnou výšku.
                Grid(horizontalSpacing: 14, verticalSpacing: 14) {
                    ForEach(rows(of: insights), id: \.first?.mode) { row in
                        GridRow {
                            ForEach(row) { insight in
                                ModeCard(
                                    insight: insight,
                                    isRecommended: insight.mode == recommendation.mode,
                                    timeAttackSeconds: $timeAttackSeconds,
                                    examMinutes: $examMinutes,
                                    speedTestSeconds: $speedTestSeconds,
                                    onStart: { start(insight.mode) },
                                    onCustomize: { customize(insight.mode) }
                                )
                                .frame(maxHeight: .infinity, alignment: .top)
                            }
                        }
                    }
                }
            }
            .padding(28)
            .frame(maxWidth: 1000)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Režimy")
        .sheet(isPresented: $showsCustomTextEditor) {
            CustomTextEditor { text in
                appState.startPractice(.quick(.customText, customText: text))
            }
        }
        .task {
            ProgressStore(context: modelContext).todaysChallengeRecord()
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Režimy")
                    .font(.title2.weight(.semibold))
                Text("Všechny režimy používají jen písmena, která umíš. Obtížnost textu mění jen Practice.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                appState.openPracticeSetup()
            } label: {
                Label("Vlastní nastavení…", systemImage: "slider.horizontal.3")
            }
        }
    }

    // MARK: - Data

    /// Karty po dvou do řádku.
    private func rows(of insights: [ModeInsight]) -> [[ModeInsight]] {
        stride(from: 0, to: insights.count, by: 2).map { Array(insights[$0..<min($0 + 2, insights.count)]) }
    }

    private var duration: TimeAttackDuration {
        TimeAttackDuration(rawValue: timeAttackSeconds) ?? .seconds60
    }

    private var speedTestDuration: TimeAttackDuration {
        TimeAttackDuration(rawValue: speedTestSeconds) ?? .seconds30
    }

    private var examDuration: ExamDuration {
        ExamDuration(rawValue: examMinutes) ?? .minutes10
    }

    private var todaysChallenge: DailyChallengeRecord? {
        let key = DayKey.string(for: .now)
        return challenges.first { $0.dayKey == key }
    }

    private var insightsInput: ModeInsightsInput {
        let summaries = sessions.map { session in
            ModeSessionSummary(
                mode: session.mode,
                date: session.date,
                wpm: session.wpm,
                accuracy: session.accuracy,
                characters: session.characterCount,
                duration: session.duration,
                score: session.score,
                timeLimit: session.timeLimit,
                completed: session.completed ?? true
            )
        }
        var recordMap: [RecordKind: RecordEntry] = [:]
        for record in records {
            if let kind = record.kind {
                recordMap[kind] = RecordEntry(value: record.value, date: record.date)
            }
        }
        let profile = profiles.first
        let challenge = todaysChallenge
        return ModeInsightsInput(
            sessions: summaries,
            records: recordMap,
            timeAttack: duration,
            exam: examDuration,
            speedTest: speedTestDuration,
            difficulty: profile?.difficulty ?? Difficulty(level: 1),
            goodStreak: profile?.goodStreak ?? 0,
            speed: progresses.first?.speedSetting ?? .default,
            dailyChallenge: challenge?.challenge,
            dailyChallengeCompleted: challenge?.isCompleted ?? false
        )
    }

    // MARK: - Akce

    private func start(_ mode: GameMode) {
        if mode == .customText {
            let text = CustomTextNormalizer.normalize(customText)
            guard text.count >= CustomTextNormalizer.minLength else {
                showsCustomTextEditor = true
                return
            }
            appState.startPractice(.quick(.customText, customText: text))
            return
        }
        appState.startPractice(.quick(mode, duration: duration, examDuration: examDuration,
                                      speedTestDuration: speedTestDuration))
    }

    private func startChallenge(_ challenge: DailyChallenge) {
        start(ModeInsightsBuilder.mode(for: challenge.kind))
    }

    private func customize(_ mode: GameMode) {
        if mode == .customText {
            showsCustomTextEditor = true
            return
        }
        var preset = PracticeConfiguration.quick(mode, duration: duration, examDuration: examDuration,
                                                 speedTestDuration: speedTestDuration)
        preset.isAdaptive = false
        appState.openPracticeSetup(preset)
    }
}

// MARK: - Doporučení

private struct RecommendationHero: View {
    let recommendation: ModeRecommendation
    let onStart: () -> Void

    private var tint: Color { recommendation.mode.tint }

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            ModeIcon(mode: recommendation.mode, size: 54)

            VStack(alignment: .leading, spacing: 4) {
                Label("Doporučeno pro tebe", systemImage: "sparkles")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(recommendation.title)
                    .font(.title2.weight(.bold))
                Text(recommendation.goal)
                    .font(.callout.weight(.medium))
                Text(recommendation.reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 10) {
                InfoChip(text: "až +\(recommendation.reward) XP", symbol: "star.fill", tint: .orange)
                Button(action: onStart) {
                    Label("Spustit", systemImage: "play.fill")
                        .padding(.horizontal, 8)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.14), tint.opacity(0.03)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(tint.opacity(0.25), lineWidth: 1)
        )
        .animation(.smooth(duration: 0.3), value: recommendation.mode)
    }
}

// MARK: - Výzva dne

private struct DailyChallengeStrip: View {
    @Environment(\.theme) private var theme
    let challenge: DailyChallenge
    let progress: Double
    let isCompleted: Bool
    let onStart: () -> Void

    @State private var celebrate = 0

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: isCompleted ? "checkmark.seal.fill" : challenge.kind.symbol)
                .font(.title2)
                .foregroundStyle(isCompleted ? Color.green : theme.accent)
                .symbolEffect(.bounce, value: celebrate)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("Výzva dne")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(challenge.title)
                        .font(.headline)
                        .lineLimit(1)
                }
                HStack(spacing: 10) {
                    ProgressView(value: challenge.fraction(progress))
                        .progressTint(isCompleted ? .green : nil)
                    Text(challenge.formattedProgress(progress))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .fixedSize()
                }
            }

            Spacer(minLength: 8)

            if isCompleted {
                InfoChip(text: "Splněno", symbol: "checkmark", tint: .green)
            } else {
                InfoChip(text: "+\(challenge.reward) XP", symbol: "star.fill", tint: .orange)
                Button("Splnit", action: onStart)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isCompleted ? Color.green.opacity(0.07) : theme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(isCompleted ? Color.green.opacity(0.3) : theme.cardBorder, lineWidth: 1)
        )
        .task(id: isCompleted) {
            // Mikroanimace po splnění výzvy.
            guard isCompleted else { return }
            try? await Task.sleep(nanoseconds: 300_000_000)
            celebrate += 1
        }
    }
}

// MARK: - Karta režimu

private struct ModeCard: View {
    @Environment(\.theme) private var theme
    let insight: ModeInsight
    let isRecommended: Bool
    @Binding var timeAttackSeconds: Int
    @Binding var examMinutes: Int
    @Binding var speedTestSeconds: Int
    let onStart: () -> Void
    let onCustomize: () -> Void

    @State private var isHovered = false

    private var mode: GameMode { insight.mode }
    private var tint: Color { mode.tint }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            stats
            progress

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                if mode == .timeAttack {
                    // Délka Time Attack přímo v kartě.
                    Picker("Délka", selection: $timeAttackSeconds) {
                        ForEach(TimeAttackDuration.allCases) { duration in
                            Text(duration.title).tag(duration.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .controlSize(.small)
                    .fixedSize()
                } else if mode == .speedTest {
                    Picker("Délka", selection: $speedTestSeconds) {
                        ForEach(TimeAttackDuration.allCases) { duration in
                            Text(duration.title).tag(duration.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .controlSize(.small)
                    .fixedSize()
                } else if mode == .exam {
                    Picker("Délka", selection: $examMinutes) {
                        ForEach(ExamDuration.allCases) { duration in
                            Text(duration.title).tag(duration.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .controlSize(.small)
                    .fixedSize()
                } else if let detail = insight.detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Button(mode == .customText ? "Změnit text…" : "Upravit…", action: onCustomize)
                    .buttonStyle(.borderless)
                    .font(.caption)
                Button(action: onStart) {
                    Label("Spustit", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(background)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(isHovered ? tint.opacity(0.4) : theme.cardBorder, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) { isHovered = hovering }
        }
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(theme.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.primary.opacity(isHovered ? 0.03 : 0))
            )
            .overlay(
                // Jemný nádech barvy režimu v rohu karty.
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.09), .clear],
                            startPoint: .topLeading,
                            endPoint: .center
                        )
                    )
            )
    }

    // MARK: Části

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            ModeIcon(mode: mode, size: 36)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(mode.title)
                        .font(.headline)
                    if isRecommended {
                        Image(systemName: "sparkles")
                            .font(.caption)
                            .foregroundStyle(tint)
                            .help("Doporučeno pro tebe")
                    }
                }
                Text(mode.cardSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 4)
            contextChip
        }
    }

    @ViewBuilder
    private var contextChip: some View {
        switch mode {
        case .practice:
            InfoChip(text: "Adaptivní", symbol: "dial.medium")
        case .timeAttack:
            InfoChip(text: TimeAttackDuration(rawValue: timeAttackSeconds)?.title ?? "60 s", symbol: "timer", tint: tint)
        case .sprint:
            InfoChip(text: "\(ModeRules.sprintLength) znaků", symbol: "flag.checkered")
        case .accuracyChallenge:
            InfoChip(text: "Max \(ModeRules.accuracyMaxErrors) chyby", symbol: "xmark.circle", tint: tint)
        case .survival:
            HStack(spacing: 2) {
                ForEach(0..<ModeRules.survivalLives, id: \.self) { _ in
                    Image(systemName: "heart.fill")
                }
            }
            .font(.caption)
            .foregroundStyle(.red)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.red.opacity(0.1)))
            .accessibilityLabel("\(ModeRules.survivalLives) životy")
        case .endless:
            InfoChip(text: "Bez limitu", symbol: "infinity")
        case .exam:
            InfoChip(text: ExamDuration(rawValue: examMinutes)?.title ?? "10 min", symbol: "timer", tint: tint)
        case .customText:
            InfoChip(text: "Tvůj text", symbol: "text.quote")
        case .speedTest:
            InfoChip(text: "WPM · CPM · KPM", symbol: "globe", tint: tint)
        }
    }

    private var stats: some View {
        HStack(alignment: .bottom, spacing: 20) {
            VStack(alignment: .leading, spacing: 1) {
                Text(insight.personalBestLabel)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(insight.personalBest ?? "—")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(insight.personalBest == nil ? Color.secondary : Color.primary)
            }
            VStack(alignment: .leading, spacing: 1) {
                Label("Cíl", systemImage: "scope")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .labelStyle(GoalLabelStyle(tint: tint))
                Text(insight.goal.target)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
            Spacer(minLength: 4)
            if let badge = insight.badge {
                ModeBadgeView(badge: badge, tint: tint)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    private var progress: some View {
        VStack(alignment: .leading, spacing: 4) {
            ProgressView(value: insight.goal.progress ?? 0)
                .progressTint(tint == .gray ? nil : tint)
                .animation(.smooth(duration: 0.4), value: insight.goal.progress)
            HStack {
                Text(insight.goal.progressLabel)
                Spacer()
                if let value = insight.goal.progress {
                    Text(Format.percent(value))
                        .monospacedDigit()
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

/// Popisek „Cíl“ s malou ikonou v barvě režimu.
private struct GoalLabelStyle: LabelStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) {
            configuration.icon
                .foregroundStyle(tint == .gray ? Color.secondary : tint)
            configuration.title
        }
    }
}
