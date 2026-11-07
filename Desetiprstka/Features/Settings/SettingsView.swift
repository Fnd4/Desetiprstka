import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

/// Okno Nastavení (⌘,) – Obecné, Vzhled, Zvuk.
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem { Label("Obecné", systemImage: "gearshape") }
            AppearanceSettingsTab()
                .tabItem { Label("Vzhled", systemImage: "paintpalette") }
            SoundSettingsTab()
                .tabItem { Label("Zvuk", systemImage: "speaker.wave.2") }
        }
        .frame(width: 560)
    }
}

// MARK: - Obecné

private struct GeneralSettingsTab: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PlayerProgress.createdAt) private var progresses: [PlayerProgress]
    @AppStorage(SettingsKey.keyboardLayout) private var layoutKind: KeyboardLayoutKind = .czechQWERTZ
    @AppStorage(SettingsKey.exerciseLength) private var exerciseLength: ExerciseLength = .medium
    @AppStorage(SettingsKey.showsKeyboard) private var showsKeyboard = true
    @AppStorage(SettingsKey.showsHands) private var showsHands = true
    @AppStorage(SettingsKey.speedUnit) private var speedUnit: SpeedUnit = .wpm
    @State private var confirmsReset = false
    @State private var backupDocument: BackupDocument?
    @State private var showsExporter = false
    @State private var showsImporter = false
    @State private var pendingBackup: ProgressBackup?
    @State private var confirmsRestore = false
    @State private var backupMessage: BackupMessage?

    private var store: ProgressStore { ProgressStore(context: modelContext) }
    private var speed: SpeedSetting { progresses.first?.speedSetting ?? .default }

    var body: some View {
        Form {
            Section {
                Picker("Jednotka rychlosti", selection: $speedUnit) {
                    ForEach(SpeedUnit.allCases) { unit in
                        Text(unit.title).tag(unit)
                    }
                }
                Picker("Rychlostní obtížnost", selection: speedModeBinding) {
                    ForEach(SpeedDifficulty.allCases) { mode in
                        Text(SpeedSetting(mode: mode, customWPM: speed.customWPM).label).tag(mode)
                    }
                }
                if speed.mode == .custom {
                    Stepper(value: customWPMBinding, in: SpeedDifficulty.customRange, step: 1) {
                        Text("Cílové WPM: \(Int(speed.customWPM))")
                            .monospacedDigit()
                    }
                }
            } header: {
                Text("Rychlost")
            } footer: {
                Text(speed.mode.subtitle + ". Obtížnost textu se řídí zvlášť podle tvých písmen a přesnosti. \(speedUnit.symbol): \(speedUnit.region).")
                    .foregroundStyle(.secondary)
            }

            Section {
                Picker("Rozložení", selection: $layoutKind) {
                    ForEach(KeyboardLayoutKind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                Toggle("Zobrazovat klávesnici při psaní", isOn: $showsKeyboard)
                Toggle("Zobrazovat ruce a prsty", isOn: $showsHands)
            } header: {
                Text("Klávesnice")
            } footer: {
                Text("Rozložení musí odpovídat zdroji vstupu v Nastavení systému → Klávesnice.")
                    .foregroundStyle(.secondary)
            }

            Section("Cvičení") {
                Picker("Délka cvičení", selection: $exerciseLength) {
                    ForEach(ExerciseLength.allCases) { length in
                        Text("\(length.title) (~\(length.characterCount) znaků)").tag(length)
                    }
                }
            }

            Section {
                LabeledContent("Záloha progresu") {
                    HStack {
                        Button("Zálohovat…") { exportBackup() }
                        Button("Obnovit…") { showsImporter = true }
                    }
                }
                Button("Smazat historii a statistiky…", role: .destructive) {
                    confirmsReset = true
                }
            } header: {
                Text("Data")
            } footer: {
                Text("Vše se ukládá pouze lokálně v tomto Macu. Záloha je jeden soubor s celou historií, XP, rekordy, odznaky i nastavením. Ulož si ji třeba na iCloud Drive a obnovíš ji i na jiném Macu.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(height: 520)
        .confirmationDialog("Opravdu smazat historii a statistiky?", isPresented: $confirmsReset) {
            Button("Smazat", role: .destructive) {
                store.resetAllProgress()
            }
        } message: {
            Text("Smaže se historie, statistiky kláves, XP, série, rekordy i odznaky a úroveň se vrátí na 1. Známá písmena a nastavení zůstanou. Akci nelze vrátit.")
        }
        .fileExporter(
            isPresented: $showsExporter,
            document: backupDocument,
            contentType: .json,
            defaultFilename: BackupService.suggestedFileName()
        ) { result in
            switch result {
            case .success(let url):
                backupMessage = BackupMessage(title: "Záloha uložena", text: "Soubor \(url.lastPathComponent) obsahuje celý tvůj progres.")
            case .failure(let error):
                backupMessage = BackupMessage(title: "Zálohu se nepodařilo uložit", text: error.localizedDescription)
            }
        }
        .fileImporter(isPresented: $showsImporter, allowedContentTypes: [.json]) { result in
            loadBackup(result)
        }
        .confirmationDialog("Obnovit progres ze zálohy?", isPresented: $confirmsRestore, presenting: pendingBackup) { backup in
            Button("Obnovit a restartovat", role: .destructive) { restore(backup) }
        } message: { backup in
            Text("\(backup.summary)\n\nAktuální progres se nahradí obsahem zálohy. Pro jistotu se nejdřív uloží do Application Support/Desetiprstka/Zálohy.")
        }
        .alert(item: $backupMessage) { message in
            Alert(title: Text(message.title), message: Text(message.text))
        }
        .task { store.playerProgress() }
    }

    private func exportBackup() {
        do {
            let backup = try BackupService.makeBackup(context: modelContext)
            backupDocument = BackupDocument(data: try BackupService.encode(backup))
            showsExporter = true
        } catch {
            backupMessage = BackupMessage(title: "Zálohu se nepodařilo vytvořit", text: error.localizedDescription)
        }
    }

    private func loadBackup(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            pendingBackup = try BackupService.decode(try Data(contentsOf: url))
            confirmsRestore = true
        } catch {
            backupMessage = BackupMessage(title: "Zálohu se nepodařilo načíst", text: error.localizedDescription)
        }
    }

    private func restore(_ backup: ProgressBackup) {
        do {
            try BackupService.restore(backup, context: modelContext)
            relaunch()
        } catch {
            backupMessage = BackupMessage(title: "Obnova se nepodařila", text: error.localizedDescription)
        }
    }

    /// Restart, aby se nové nastavení i progres načetly všude čistě.
    private func relaunch() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }

    private var speedModeBinding: Binding<SpeedDifficulty> {
        Binding(
            get: { speed.mode },
            set: { store.setSpeed(SpeedSetting(mode: $0, customWPM: speed.customWPM)) }
        )
    }

    private var customWPMBinding: Binding<Double> {
        Binding(
            get: { speed.customWPM },
            set: { store.setSpeed(SpeedSetting(mode: .custom, customWPM: $0)) }
        )
    }
}

// MARK: - Vzhled

private struct AppearanceSettingsTab: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.theme) private var theme
    @Query(sort: \PlayerProgress.createdAt) private var progresses: [PlayerProgress]

    private var level: Int { progresses.first?.playerLevel.level ?? 1 }

    /// Zamčeno levelem – už vybraná položka zůstává dostupná.
    private func lock(_ item: some LevelUnlockable, selected: Bool) -> Int? {
        item.isUnlocked(at: level) || selected ? nil : item.requiredLevel
    }

    private let columns = [GridItem(.adaptive(minimum: 150, maximum: 170), spacing: 12)]

    var body: some View {
        Form {
            Section {
                RankSummary(level: level)
            }

            Section {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(AppTheme.allCases) { option in
                        let locked = lock(option, selected: themeManager.theme == option)
                        ThemePreviewCard(
                            theme: option,
                            accent: themeManager.accent.color,
                            isSelected: themeManager.theme == option
                        ) {
                            themeManager.select(option)
                        }
                        .disabled(locked != nil)
                        .opacity(locked != nil ? 0.55 : 1)
                        .overlay(alignment: .topTrailing) {
                            if let locked { LockBadge(level: locked).padding(14) }
                        }
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Téma")
            } footer: {
                Text("Změna se projeví okamžitě. Midnight je vždy tmavé, ostatní se řídí systémem.")
                    .foregroundStyle(.secondary)
            }

            Section {
                HStack(spacing: 14) {
                    ForEach(AccentChoice.allCases) { choice in
                        let locked = lock(choice, selected: themeManager.accent == choice)
                        AccentSwatch(
                            choice: choice,
                            themeAccent: themeManager.theme.colors(accent: nil).accent,
                            isSelected: themeManager.accent == choice
                        ) {
                            themeManager.select(choice)
                        }
                        .disabled(locked != nil)
                        .opacity(locked != nil ? 0.45 : 1)
                        .overlay(alignment: .top) {
                            if locked != nil {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                                    .offset(y: 7)
                            }
                        }
                        .help(locked.map { "Odemkne se na levelu \($0)" } ?? choice.title)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            } header: {
                Text("Barva zvýraznění")
            } footer: {
                Text("Tlačítka, průběh, aktuální znak a důležité statistiky. Automatic = barva tématu.")
                    .foregroundStyle(.secondary)
            }

            Section {
                ForEach(TypingStyle.allCases) { style in
                    TypingStyleRow(
                        style: style,
                        isSelected: themeManager.typingStyle == style
                    ) {
                        themeManager.typingStyle = style
                    }
                }
            } header: {
                Text("Obrazovka psaní")
            } footer: {
                Text("Při psaní přepneš variantu přes ⇧⌘F (Focus) nebo menu v horní liště.")
                    .foregroundStyle(.secondary)
            }

            Section {
                ForEach(CursorStyle.allCases) { style in
                    UnlockableRow(
                        title: style.title,
                        symbol: style.symbol,
                        isSelected: themeManager.cursorStyle == style,
                        lockedLevel: lock(style, selected: themeManager.cursorStyle == style)
                    ) {
                        themeManager.cursorStyle = style
                    }
                }
            } header: {
                Text("Kurzor")
            } footer: {
                Text("Jak je vyznačený znak, který máš napsat. Žádný styl neposouvá text.")
                    .foregroundStyle(.secondary)
            }

            Section {
                ForEach(ComboEffect.allCases) { effect in
                    UnlockableRow(
                        title: effect.title,
                        symbol: effect.symbol,
                        isSelected: themeManager.comboEffect == effect,
                        lockedLevel: lock(effect, selected: themeManager.comboEffect == effect)
                    ) {
                        themeManager.comboEffect = effect
                    }
                }
            } header: {
                Text("Efekt combo")
            } footer: {
                Text("Odznak, který se ukáže při 10, 25, 50… správných znacích v řadě.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(height: 640)
    }
}

/// Miniatura tématu: pozadí, karta, text a průběh v barvách tématu.
private struct ThemePreviewCard: View {
    let theme: AppTheme
    let accent: Color?
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var systemScheme
    @Environment(\.theme) private var current
    @State private var isHovered = false

    var body: some View {
        let colors = theme.colors(accent: accent)
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                miniature(colors)
                    .environment(\.colorScheme, colors.colorScheme ?? systemScheme)
                HStack(spacing: 4) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(theme.title)
                            .font(.callout.weight(.semibold))
                        Text(theme.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(current.accent)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(isHovered ? 0.05 : 0.0))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isSelected ? current.accent : Color.primary.opacity(0.08), lineWidth: isSelected ? 2 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityLabel("Téma \(theme.title)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func miniature(_ colors: ThemeColors) -> some View {
        let background = colors.background ?? Color(nsColor: .windowBackgroundColor)
        let text = colors.textPrimary ?? .primary
        return ZStack(alignment: .topLeading) {
            background
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 0) {
                    Text("dobr")
                        .foregroundStyle(text.opacity(0.4))
                    Text("ý")
                        .foregroundStyle(colors.typingHighlight)
                        .underline(color: colors.typingHighlight)
                    Text(" den")
                        .foregroundStyle(text)
                }
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                Capsule()
                    .fill(colors.progressTrack)
                    .frame(height: 4)
                    .overlay(alignment: .leading) {
                        Capsule().fill(colors.accent).frame(width: 52, height: 4)
                    }
                HStack(spacing: 4) {
                    Capsule().fill(colors.accent).frame(width: 30, height: 9)
                    Capsule().fill(colors.secondaryAccent.opacity(0.7)).frame(width: 18, height: 9)
                }
            }
            .padding(9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(colors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(colors.cardBorder, lineWidth: 1)
            )
            .padding(8)
        }
        .frame(height: 82)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct AccentSwatch: View {
    let choice: AccentChoice
    let themeAccent: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                ZStack {
                    if choice == .automatic {
                        Circle()
                            .fill(AngularGradient(
                                colors: [.blue, .purple, .pink, .red, .orange, .green, .blue],
                                center: .center
                            ))
                        Circle()
                            .fill(themeAccent)
                            .padding(6)
                    } else {
                        Circle().fill(choice.color ?? themeAccent)
                    }
                    if isSelected {
                        Circle()
                            .fill(.white)
                            .frame(width: 7, height: 7)
                            .shadow(radius: 0.5)
                    }
                }
                .frame(width: 24, height: 24)
                .overlay(
                    Circle()
                        .strokeBorder(Color.primary.opacity(isSelected ? 0.5 : 0.12), lineWidth: isSelected ? 2 : 1)
                        .padding(-3)
                )
                Text(choice.title)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(choice == .automatic ? "Barva podle tématu" : choice.title)
        .accessibilityLabel("Barva \(choice.title)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct TypingStyleRow: View {
    @Environment(\.theme) private var theme
    let style: TypingStyle
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: style.symbol)
                    .font(.body)
                    .foregroundStyle(isSelected ? theme.accent : .secondary)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 1) {
                    Text(style.title)
                    Text(style.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(theme.accent)
                        .fontWeight(.semibold)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Zvuk

private struct SoundSettingsTab: View {
    @Environment(\.theme) private var theme
    @AppStorage(AudioSettings.Key.typingEnabled) private var typingEnabled = false
    @AppStorage(AudioSettings.Key.pack) private var pack: SoundPack = .soft
    @AppStorage(AudioSettings.Key.typingVolume) private var typingVolume = AudioSettings.defaultTypingVolume
    @AppStorage(AudioSettings.Key.errorEnabled) private var errorEnabled = false
    @AppStorage(AudioSettings.Key.rewardsEnabled) private var rewardsEnabled = false
    @AppStorage(AudioSettings.Key.rewardVolume) private var rewardVolume = AudioSettings.defaultRewardVolume
    @AppStorage(SettingsKey.metronomeEnabled) private var metronomeEnabled = false
    @Query(sort: \PlayerProgress.createdAt) private var progresses: [PlayerProgress]

    private var audio: AudioManager { .shared }
    private var level: Int { progresses.first?.playerLevel.level ?? 1 }

    var body: some View {
        Form {
            Section {
                Toggle("Zvuky úhozů", isOn: $typingEnabled)
                ForEach(SoundPack.allCases) { option in
                    let locked = option.isUnlocked(at: level) || pack == option ? nil : option.requiredLevel
                    SoundPackRow(
                        pack: option,
                        isSelected: pack == option,
                        isEnabled: typingEnabled && locked == nil,
                        lockedLevel: locked,
                        select: { pack = option },
                        preview: { audio.preview(option) }
                    )
                }
                VolumeSlider(title: "Hlasitost úhozů", value: $typingVolume) {
                    audio.preview(pack)
                }
                .disabled(!typingEnabled || pack == .silent)
            } header: {
                Text("Psaní")
            } footer: {
                Text("Zvuk zazní jen u správně napsaného znaku. Přehrává se mimo hlavní vlákno, psaní nezdrží.")
                    .foregroundStyle(.secondary)
            }

            Section {
                HStack {
                    Toggle("Zvuk při chybě", isOn: $errorEnabled)
                    Spacer()
                    PreviewButton { audio.preview(.error) }
                }
            } footer: {
                Text("Jemné, tlumené ťuknutí – upozorní, ale nevyruší.")
                    .foregroundStyle(.secondary)
            }

            Section {
                HStack {
                    Toggle("Metronom při psaní", isOn: $metronomeEnabled)
                    Spacer()
                    PreviewButton { audio.previewMetronome() }
                }
            } footer: {
                Text("Tiché tikání v cílovém tempu tvé rychlostní obtížnosti. Pomáhá psát rovnoměrně. Při psaní ho přepneš ⇧⌘M.")
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Zvuky odměn", isOn: $rewardsEnabled)
                VolumeSlider(title: "Hlasitost odměn", value: $rewardVolume) {
                    audio.preview(.completion)
                }
                .disabled(!rewardsEnabled)
                LabeledContent("Náhled") {
                    HStack(spacing: 6) {
                        ForEach(SoundEffect.rewards, id: \.self) { effect in
                            Button(effect.title) { audio.preview(effect) }
                                .controlSize(.small)
                        }
                    }
                }
            } header: {
                Text("Odměny")
            } footer: {
                Text("Dokončení lekce, nový rekord, denní výzva, odznak a nový level. Po lekci zazní nanejvýš dva zvuky.")
                    .foregroundStyle(.secondary)
            }

            Section("Zdroje zvuků") {
                SoundCredit(
                    title: "Typewriter.wav",
                    detail: "ddohler · Freesound · CC BY 4.0 · upraveno (oříznutí, hlasitost, výška)",
                    url: "https://freesound.org/people/ddohler/sounds/9098/"
                )
                SoundCredit(
                    title: "Typing on a mechanical keyboard",
                    detail: "Vladislav_Sazonov · Freesound · CC0",
                    url: "https://freesound.org/people/Vladislav_Sazonov/sounds/860426/"
                )
                SoundCredit(
                    title: "Typewriter soft click, Hard typewriter click, Mechanical typewriter single hit",
                    detail: "Mixkit · Mixkit Sound Effects Free License",
                    url: "https://mixkit.co/free-sound-effects/typewriter/"
                )
            }
        }
        .formStyle(.grouped)
        .frame(height: 600)
    }
}

private struct SoundPackRow: View {
    @Environment(\.theme) private var theme
    let pack: SoundPack
    let isSelected: Bool
    /// Vypnuté úhozy: výběr je ztlumený, náhled funguje dál.
    let isEnabled: Bool
    var lockedLevel: Int?
    let select: () -> Void
    let preview: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: select) {
                HStack(spacing: 12) {
                    Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                        .foregroundStyle(isSelected ? theme.accent : .secondary)
                    Image(systemName: pack.symbol)
                        .frame(width: 20)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(pack.title)
                        Text(pack.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1 : 0.5)
            .accessibilityLabel("Balíček \(pack.title)")
            .accessibilityAddTraits(isSelected ? .isSelected : [])

            if let lockedLevel {
                LockBadge(level: lockedLevel)
            }
            if pack != .silent {
                // Náhled jde přehrát i u zamčeného balíčku – ať víš, na co se těšit.
                PreviewButton(action: preview)
            }
        }
    }
}

private struct PreviewButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Přehrát", systemImage: "play.fill")
                .labelStyle(.iconOnly)
        }
        .buttonStyle(.borderless)
        .help("Přehrát ukázku")
    }
}

private struct VolumeSlider: View {
    let title: String
    @Binding var value: Double
    let onCommit: () -> Void

    var body: some View {
        LabeledContent(title) {
            HStack(spacing: 8) {
                Image(systemName: "speaker.fill")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                Slider(value: $value, in: 0...1) { editing in
                    if !editing { onCommit() }
                }
                .frame(width: 200)
                Image(systemName: "speaker.wave.3.fill")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
    }
}

/// Uvedení autora zvuku (licence CC BY vyžaduje zmínku v aplikaci).
private struct SoundCredit: View {
    let title: String
    let detail: String
    let url: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if let link = URL(string: url) {
                Link(destination: link) {
                    Image(systemName: "arrow.up.right.square")
                }
                .help(url)
            }
        }
    }
}

// MARK: - Levely a odemykání

/// Zámek s levelem, na kterém se položka odemkne.
private struct LockBadge: View {
    let level: Int

    var body: some View {
        Label("Lvl \(level)", systemImage: "lock.fill")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(.regularMaterial))
            .fixedSize()
            .help("Odemkne se na levelu \(level)")
    }
}

/// Hodnost, level a nejbližší odměna.
private struct RankSummary: View {
    @Environment(\.theme) private var theme
    let level: Int

    var body: some View {
        let rank = PlayerRank.rank(for: level)
        HStack(spacing: 12) {
            Image(systemName: rank.symbol)
                .font(.title2)
                .foregroundStyle(theme.accent)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(rank.title) · level \(level)")
                    .font(.headline)
                if let next = UnlockCatalog.next(after: level) {
                    Text("Další odměna: \(next.title) na levelu \(next.level)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Máš odemčené všechno.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let nextRank = rank.next {
                Text("\(nextRank.title) na levelu \(nextRank.requiredLevel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// Řádek volby, která se může odemknout levelem.
private struct UnlockableRow: View {
    @Environment(\.theme) private var theme
    let title: String
    let symbol: String
    let isSelected: Bool
    let lockedLevel: Int?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .foregroundStyle(isSelected ? theme.accent : .secondary)
                    .frame(width: 24)
                Text(title)
                Spacer()
                if let lockedLevel {
                    LockBadge(level: lockedLevel)
                } else if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(theme.accent)
                        .fontWeight(.semibold)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(lockedLevel != nil)
        .opacity(lockedLevel != nil ? 0.6 : 1)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Záloha

/// Soubor zálohy pro `fileExporter`.
struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

private struct BackupMessage: Identifiable {
    let id = UUID()
    let title: String
    let text: String
}
