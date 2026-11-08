import SwiftUI

/// Výsledky po dokončení cvičení.
struct ResultsView: View {
    @Environment(\.theme) private var theme
    let summary: PracticeSummary
    let onNext: () -> Void
    let onRetry: () -> Void
    let onAddKey: (String) -> Void
    let onApplySpeed: (SpeedSetting) -> Void
    let onClose: () -> Void

    @AppStorage(SettingsKey.keyboardLayout) private var layoutKind: KeyboardLayoutKind = .czechQWERTZ
    @State private var speedApplied = false
    @State private var showsXPDetails = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Mikroanimace po zobrazení výsledků.
    @State private var appeared = false
    @State private var celebrate = 0
    @State private var levelProgress: Double?
    @AppStorage(SettingsKey.speedUnit) private var speedUnit: SpeedUnit = .wpm

    private var result: SessionResult { summary.result }
    private var outcome: SessionOutcome { summary.outcome }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header

                if !outcome.newRecords.isEmpty {
                    personalBestCard
                }

                if result.mode.showsExamEvaluation {
                    examCard
                }

                if result.mode == .speedTest {
                    speedTestCard
                }

                Card {
                    HStack(spacing: 16) {
                        ForEach(tiles, id: \.title) { tile in
                            StatTile(title: tile.title, value: tile.value, systemImage: tile.symbol,
                                     tint: tile.tint, size: 28)
                        }
                    }
                }

                if let rhythm = result.rhythm {
                    rhythmCard(rhythm)
                }

                rewardsCard

                if let evaluation = summary.evaluation {
                    levelCard(evaluation)
                }

                if let recommendation = outcome.speedRecommendation {
                    speedCard(recommendation)
                }

                if !result.problemKeys.isEmpty {
                    problemKeysCard
                }

                if let key = summary.recommendedKey {
                    recommendationCard(key)
                }

                HStack(spacing: 12) {
                    Button("Hotovo", action: onClose)
                        .keyboardShortcut(.cancelAction)
                    Button(result.mode.usesContinuousText ? String(localized: "Znovu") : String(localized: "Zopakovat stejný text"), action: onRetry)
                    Spacer()
                    Button(action: onNext) {
                        Text("Další cvičení")
                            .frame(minWidth: 160)
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                }
                .controlSize(.large)
            }
            .padding(40)
            .frame(maxWidth: 780)
            .frame(maxWidth: .infinity)
        }
        .task { await animateIn() }
    }

    /// Krátký nástup výsledků; s Reduce Motion vše hned bez pohybu.
    private func animateIn() async {
        let target = outcome.levelAfter.progress
        guard !reduceMotion else {
            appeared = true
            levelProgress = target
            return
        }
        levelProgress = outcome.leveledUp ? 0 : outcome.levelBefore.progress
        withAnimation(.smooth(duration: 0.35)) { appeared = true }
        try? await Task.sleep(nanoseconds: 200_000_000)
        celebrate += 1
        withAnimation(.easeOut(duration: 0.8)) { levelProgress = target }
    }

    // MARK: - Hlavička

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: headerSymbol)
                .font(.system(size: 44))
                .foregroundStyle(headerColor)
                .symbolRenderingMode(.hierarchical)
                .symbolEffect(.bounce, value: celebrate)
            Text(headerTitle)
                .font(.largeTitle.weight(.bold))
            Text(headerSubtitle)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 12)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 8)
    }

    private var headerSubtitle: String {
        switch result.mode {
        case .practice:
            return result.difficulty.stage.title + " · " + result.difficulty.title
        case .timeAttack:
            let kind = RecordKind.timeAttack(result.timeLimit ?? 0)
            return String(localized: "Time Attack \(result.timeLimit ?? 0) s · \(result.displayScore) správných znaků") + recordSuffix(kind)
        case .survival:
            return String(localized: "Survival · vlna \(result.wave ?? 1) · \(result.displayScore) bodů") + recordSuffix(.survival)
        case .endless:
            return String(localized: "Endless · \(result.characters) znaků")
        case .sprint, .accuracyChallenge:
            return result.mode.title
        case .exam:
            return String(localized: "Zkouška \((result.timeLimit ?? 600) / 60) min · \(Format.number(result.grossStrokes)) hrubých úhozů")
        case .customText:
            return String(localized: "Vlastní text · \(Format.number(result.characters)) znaků")
        case .speedTest:
            return String(localized: "Test rychlosti \(result.timeLimit ?? 30) s · \(Format.number(result.characters)) správných znaků")
        }
    }

    /// „ · rekord 350 bodů“ – u režimů se skóre.
    private func recordSuffix(_ kind: RecordKind?) -> String {
        guard let kind, let value = outcome.recordValues[kind] else { return "" }
        return String(localized: " · rekord \(kind.format(value))")
    }

    private var headerTitle: String {
        if result.mode == .accuracyChallenge {
            return result.completed ? String(localized: "Výzva splněna") : String(localized: "Výzva nesplněna")
        }
        if result.mode == .survival { return String(localized: "Konec hry") }
        if result.mode == .exam { return result.exam.grade.title }
        switch result.accuracy {
        case 0.97...: return String(localized: "Výborně!")
        case 0.9..<0.97: return String(localized: "Dobrá práce")
        default: return String(localized: "Zkus trochu zpomalit")
        }
    }

    private var headerSymbol: String {
        if result.mode == .accuracyChallenge {
            return result.completed ? "checkmark.seal.fill" : "xmark.seal"
        }
        if result.mode == .exam { return "\(result.exam.grade.rawValue).circle.fill" }
        switch result.accuracy {
        case 0.97...: return "star.circle.fill"
        case 0.9..<0.97: return "checkmark.circle.fill"
        default: return "tortoise.circle.fill"
        }
    }

    private var headerColor: Color {
        if result.mode == .accuracyChallenge, !result.completed { return .orange }
        if result.mode == .exam { return gradeColor(result.exam.grade) }
        return accuracyColor
    }

    // MARK: - Metriky

    private struct Tile {
        let title: String
        let value: String
        let symbol: String
        var tint: Color = .primary
    }

    private var tiles: [Tile] {
        var tiles: [Tile] = []
        switch result.mode {
        case .timeAttack, .survival:
            tiles.append(Tile(title: result.mode == .survival ? String(localized: "Skóre") : String(localized: "Znaky"), value: "\(result.displayScore)", symbol: "number"))
        case .sprint:
            tiles.append(Tile(title: String(localized: "Čas"), value: Format.duration(result.duration), symbol: "stopwatch"))
        default:
            break
        }
        tiles.append(Tile(title: String(localized: "Rychlost"), value: speedUnit.label(result.wpm, strokesPerMinute: result.strokesPerMinute), symbol: "speedometer"))
        tiles.append(Tile(title: String(localized: "Přesnost"), value: Format.percent(result.accuracy), symbol: "target", tint: accuracyColor))
        tiles.append(Tile(title: String(localized: "Chyby"), value: "\(result.errors)", symbol: "xmark.circle",
                          tint: result.errors > 0 ? .red : .primary))
        if result.mode != .exam {
            tiles.append(Tile(title: String(localized: "Max combo"), value: "\(result.maxCombo)", symbol: "bolt"))
        }
        if result.mode != .sprint, !result.mode.isTimed {
            tiles.append(Tile(title: String(localized: "Čas"), value: Format.duration(result.duration), symbol: "timer"))
        }
        return tiles
    }

    // MARK: - Zkouška a rytmus

    private func gradeColor(_ grade: ExamEvaluation.Grade) -> Color {
        switch grade {
        case .excellent, .veryGood: .green
        case .good: theme.accent
        case .sufficient: .orange
        case .insufficient: .red
        }
    }

    /// Výsledek ve všech světových jednotkách – dá se porovnat s Monkeytype, 10FastFingers i ZAV.
    private var speedTestCard: some View {
        Card(title: String(localized: "Tvoje rychlost ve všech jednotkách"), systemImage: "globe") {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 16) {
                    unitTile(.wpm, value: result.wpm, highlighted: speedUnit == .wpm)
                    unitTile(.cpm, value: result.cpm, highlighted: speedUnit == .cpm)
                    unitTile(.strokes, value: result.strokesPerMinute, highlighted: speedUnit == .strokes)
                    StatTile(title: String(localized: "Raw WPM"), value: Format.wpm(result.rawWPM), systemImage: "waveform.path", size: 28)
                }
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                    ForEach(SpeedUnit.allCases) { unit in
                        GridRow {
                            Text(unit.symbol)
                                .fontWeight(.semibold)
                            Text(unit.region)
                                .foregroundStyle(.secondary)
                        }
                    }
                    GridRow {
                        Text("Raw")
                            .fontWeight(.semibold)
                        Text("WPM včetně chybných stisků – rozdíl proti WPM ukazuje, kolik tě stojí chyby")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.caption)
            }
        }
    }

    private func unitTile(_ unit: SpeedUnit, value: Double, highlighted: Bool) -> some View {
        StatTile(title: unit.symbol, value: Format.wpm(value), systemImage: highlighted ? "star.fill" : nil,
                 tint: highlighted ? theme.accent : .primary, size: 28)
    }

    private var examCard: some View {
        let exam = result.exam
        return Card(title: String(localized: "Hodnocení opisu"), systemImage: "graduationcap") {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 16) {
                    StatTile(title: String(localized: "Čisté úhozy/min"), value: Format.number(exam.netPerMinute.rounded()),
                             systemImage: "checkmark.circle", tint: gradeColor(exam.grade), size: 28)
                    StatTile(title: String(localized: "Hrubé úhozy/min"), value: Format.number(exam.grossPerMinute.rounded()),
                             systemImage: "keyboard", size: 28)
                    StatTile(title: String(localized: "Chybovost"), value: "\(Format.decimal(exam.errorPercent)) %",
                             systemImage: "percent", tint: exam.errorPercent > 0.5 ? .orange : .primary, size: 28)
                    StatTile(title: String(localized: "Známka"), value: "\(exam.grade.rawValue)",
                             systemImage: "rosette", tint: gradeColor(exam.grade), size: 28)
                }
                Text("\(Format.number(exam.grossStrokes)) hrubých úhozů − \(exam.errors) × \(ExamEvaluation.penaltyPerError) za chyby = \(Format.number(exam.netStrokes)) čistých úhozů")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                if let step = exam.grade.nextStep(netPerMinute: exam.netPerMinute, errorPercent: exam.errorPercent) {
                    Label(step, systemImage: "arrow.up.right")
                        .font(.callout)
                }
                Text("Známka je orientační (1: 250+ čistých úh./min a do 0,3 % chyb, 2: 200+ a 0,5 %, 3: 150+ a 1 %, 4: 100+ a 2 %). Školy mají vlastní tabulky podle ročníku.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func rhythmCard(_ rhythm: Double) -> some View {
        let label: String
        let tint: Color
        switch rhythm {
        case 0.75...: label = String(localized: "Pravidelné tempo – přesně tak se píše všemi deseti."); tint = .green
        case 0.6..<0.75: label = String(localized: "Tempo občas kolísá. Zkus zapnout metronom (⇧⌘M) a psát do rytmu."); tint = theme.accent
        default: label = String(localized: "Tempo hodně kolísá – zpomal a drž stejné rozestupy mezi úhozy. Pomůže metronom (⇧⌘M)."); tint = .orange
        }
        return Card {
            HStack(spacing: 16) {
                StatTile(title: String(localized: "Rytmus"), value: Format.percent(rhythm), systemImage: "metronome", tint: tint, size: 28)
                    .frame(width: 130, alignment: .leading)
                Text(label)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Rekordy a odměny

    private var personalBestCard: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 28))
                .foregroundStyle(.orange)
                .symbolEffect(.bounce, value: celebrate)
            VStack(alignment: .leading, spacing: 4) {
                Text("🏆 New Personal Best")
                    .font(.headline)
                ForEach(outcome.newRecords) { kind in
                    HStack {
                        Text(kind.title)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(kind.format(outcome.recordValues[kind] ?? 0))
                            .monospacedDigit()
                            .fontWeight(.semibold)
                    }
                    .font(.callout)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.yellow.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.yellow.opacity(0.35), lineWidth: 1)
        )
        .transition(.scale(scale: 0.96).combined(with: .opacity))
    }

    /// Nová hodnost a odemčený vzhled po level upu.
    @ViewBuilder
    private var levelRewards: some View {
        let before = outcome.levelBefore.level
        let after = outcome.levelAfter.level
        let rankBefore = PlayerRank.rank(for: before)
        let rankAfter = PlayerRank.rank(for: after)
        if rankAfter != rankBefore {
            Label {
                Text("Nová hodnost: \(rankAfter.title)")
                    .fontWeight(.semibold)
            } icon: {
                Image(systemName: rankAfter.symbol)
                    .symbolEffect(.bounce, value: celebrate)
            }
            .foregroundStyle(theme.accent)
            .font(.callout)
        }
        ForEach(UnlockCatalog.unlocked(from: before, to: after)) { item in
            Label {
                Text("Odemčeno: \(item.title)")
            } icon: {
                Image(systemName: "lock.open.fill")
                    .symbolEffect(.bounce, value: celebrate)
            }
            .foregroundStyle(theme.accent)
            .font(.callout)
        }
        if after == before, let next = UnlockCatalog.next(after: after) {
            Text("Další odměna na levelu \(next.level): \(next.title)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var rewardsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("+\(outcome.xp.total) XP")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.accent)
                    if outcome.leveledUp {
                        Label("Nový level \(outcome.levelAfter.level)", systemImage: "arrow.up.circle.fill")
                            .font(.headline)
                            .foregroundStyle(theme.accent)
                            .symbolEffect(.bounce, value: celebrate)
                    } else {
                        Text("Level \(outcome.levelAfter.level)")
                            .font(.headline)
                    }
                    Text(PlayerRank.rank(for: outcome.levelAfter.level).title)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if outcome.streak > 0 {
                        Label("\(outcome.streak) day streak", systemImage: "flame.fill")
                            .foregroundStyle(.orange)
                            .font(.callout.weight(.semibold))
                    }
                }

                ProgressView(value: levelProgress ?? outcome.levelAfter.progress)
                Text(outcome.levelAfter.isMax
                     ? String(localized: "Maximální level")
                     : String(localized: "\(Format.number(outcome.levelAfter.xpIntoLevel)) / \(Format.number(outcome.levelAfter.xpForNextLevel)) XP"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                levelRewards

                if let challenge = outcome.completedChallenge {
                    Label {
                        Text("Denní výzva splněna: \(challenge.title)")
                    } icon: {
                        Image(systemName: "star.circle.fill")
                            .symbolEffect(.bounce, value: celebrate)
                    }
                    .foregroundStyle(.green)
                    .font(.callout)
                }

                ForEach(outcome.unlockedAchievements) { achievement in
                    Label {
                        Text("Nový odznak: \(achievement.title)")
                    } icon: {
                        Image(systemName: achievement.symbol)
                            .foregroundStyle(theme.accent)
                            .symbolEffect(.bounce, value: celebrate)
                    }
                    .font(.callout)
                }

                DisclosureGroup("Rozpis XP", isExpanded: $showsXPDetails) {
                    VStack(spacing: 4) {
                        ForEach(outcome.xp.items) { item in
                            HStack {
                                Text(item.title)
                                Spacer()
                                Text("+\(item.xp)")
                                    .monospacedDigit()
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 4)
                }
                .font(.caption)
            }
        }
    }

    // MARK: - Výuka

    private func levelCard(_ evaluation: AdaptiveEngine.Evaluation) -> some View {
        let symbol: String
        let tint: Color
        switch evaluation.change {
        case .levelUp:
            symbol = "arrow.up.circle.fill"
            tint = .green
        case .levelDown:
            symbol = "arrow.down.circle.fill"
            tint = .orange
        case .stay:
            symbol = "equal.circle.fill"
            tint = .secondary
        }

        return Card {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.title)
                    .foregroundStyle(tint)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Text: " + evaluation.next.title + " · " + evaluation.next.stage.title)
                        .font(.headline)
                    Text(evaluation.message)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
        }
    }

    private func speedCard(_ recommendation: SpeedRecommendation) -> some View {
        Card {
            HStack(spacing: 14) {
                Image(systemName: recommendation.direction == .up ? "arrow.up.forward.circle.fill" : "arrow.down.forward.circle.fill")
                    .font(.title)
                    .foregroundStyle(theme.accent)
                VStack(alignment: .leading, spacing: 4) {
                    Text(recommendation.direction == .up ? String(localized: "Zvýšit rychlostní obtížnost?") : String(localized: "Snížit rychlostní obtížnost?"))
                        .font(.headline)
                    Text(recommendation.reason)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                if speedApplied {
                    Label("Nastaveno", systemImage: "checkmark")
                        .foregroundStyle(.green)
                } else {
                    Button(recommendation.actionTitle) {
                        onApplySpeed(recommendation.suggested)
                        withAnimation { speedApplied = true }
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private var problemKeysCard: some View {
        Card(title: String(localized: "Kde chybuješ"), systemImage: "exclamationmark.triangle") {
            VStack(alignment: .leading, spacing: 12) {
                FlowLayout(spacing: 10) {
                    ForEach(result.problemKeys.prefix(8)) { item in
                        HStack(spacing: 6) {
                            KeyChip(key: item.key, finger: layoutKind.layout.stroke(forLearnable: item.key)?.primary.finger)
                            Text("\(item.errors)×")
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(.red)
                                .monospacedDigit()
                        }
                    }
                }
                Text("Tato písmena budou v dalších cvičeních častěji.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func recommendationCard(_ key: String) -> some View {
        let finger = layoutKind.layout.stroke(forLearnable: key)?.primary.finger
        return Card {
            HStack(spacing: 16) {
                KeyChip(key: key, finger: finger, size: 46)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Jsi připraven na novou klávesu")
                        .font(.headline)
                    Text("Současná písmena ti jdou dobře. Přidej \(Curriculum.displayName(for: key)) a pokračuj v osnově.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Button("Přidat \(Curriculum.displayName(for: key))") {
                    onAddKey(key)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - Pomocné

    private var accuracyColor: Color {
        switch result.accuracy {
        case 0.97...: .green
        case 0.9..<0.97: .blue
        default: .orange
        }
    }
}
