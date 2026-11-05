import AppKit
import SwiftUI

/// Obrazovka psaní. Primární je text, metriky jsou minimální.
struct PracticeView: View {
    @Environment(\.theme) private var theme
    let viewModel: PracticeViewModel
    let layout: KeyboardLayout
    let onClose: () -> Void

    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(SettingsKey.showsKeyboard) private var showsKeyboard = true
    @AppStorage(SettingsKey.showsHands) private var showsHands = true
    @AppStorage(SettingsKey.previousTypingStyle) private var previousStyleRaw = TypingStyle.standard.rawValue
    @AppStorage(SettingsKey.speedUnit) private var speedUnit: SpeedUnit = .wpm
    @AppStorage(SettingsKey.metronomeEnabled) private var metronomeEnabled = false
    @State private var visibleMilestone: Int?

    private var engine: TypingEngine { viewModel.engine }
    private var style: TypingStyle { themeManager.typingStyle }

    private var currentStroke: KeyStroke? {
        engine.expected.flatMap { layout.stroke(for: $0) }
    }

    private var surface: TypingTextView.Surface {
        switch style {
        case .standard, .focus: .card
        case .paper: .paper
        case .minimal: .bare
        }
    }

    var body: some View {
        VStack(spacing: style == .minimal ? 0 : 20) {
            if style == .minimal {
                minimalHeader
                Spacer(minLength: 0)
            } else {
                header
                progressBar
                if style == .focus {
                    // Focus: text uprostřed, nic dalšího pod ním.
                    Spacer(minLength: 0)
                }
            }

            TypingTextView(engine: engine, windowed: viewModel.mode.usesContinuousText, surface: surface,
                           cursor: themeManager.cursorStyle)
                .overlay(alignment: .topTrailing) { milestoneBadge }
                .layoutPriority(1)

            if style.showsKeyboard {
                hint
                    .frame(height: 22)
            }

            if style.showsKeyboard, showsKeyboard {
                // Klávesnice zabere zbylé místo (bez Spaceru, který by si půlku vzal pro sebe).
                KeyboardView(
                    layout: layout,
                    knownKeys: viewModel.knownKeys,
                    highlightedKeyIDs: currentStroke?.keyIDs ?? []
                )
                .frame(maxWidth: 820, maxHeight: .infinity, alignment: .bottom)
                .transition(.opacity)
            } else {
                Spacer(minLength: 0)
            }

            if style.showsKeyboard, showsHands {
                HandsView(activeFingers: currentStroke?.fingers ?? [], scale: 0.8)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, style.showsKeyboard ? 40 : 80)
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(shortcutButtons)
        .animation(reduceMotion ? nil : .smooth(duration: 0.25), value: style)
        .animation(reduceMotion ? nil : .smooth(duration: 0.2), value: showsKeyboard)
        .animation(reduceMotion ? nil : .smooth(duration: 0.2), value: showsHands)
        .onKeyDown(handleKeyDown)
        .task(id: engine.milestonePulse) {
            guard engine.milestonePulse > 0, let milestone = engine.comboMilestone else { return }
            withAnimation(reduceMotion ? nil : .snappy) { visibleMilestone = milestone }
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.4)) { visibleMilestone = nil }
        }
    }

    // MARK: - Hlavička

    private var closeButton: some View {
        Button(action: closeTapped) {
            Label(viewModel.mode == .endless ? "Dokončit" : "Ukončit",
                  systemImage: viewModel.mode == .endless ? "checkmark" : "xmark")
        }
        .help(viewModel.mode == .endless ? "Dokončit a uložit (Esc)" : "Ukončit cvičení (Esc)")
    }

    private var header: some View {
        HStack(spacing: 16) {
            closeButton

            if style != .focus {
                VStack(alignment: .leading, spacing: 2) {
                    Label(viewModel.mode == .practice ? viewModel.exercise.stage.title : viewModel.mode.title,
                          systemImage: viewModel.mode == .practice ? viewModel.exercise.stage.symbol : viewModel.mode.symbol)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            TimelineView(.periodic(from: .now, by: 0.25)) { context in
                HStack(spacing: 26) {
                    modeIndicator(at: context.date)
                    metric(speedUnit.symbol, liveSpeed(at: context.date), detail: targetLabel)
                    metric("Přesnost", Format.percent(engine.accuracy),
                           tint: engine.accuracy < 0.9 && engine.keystrokes > 10 ? .orange : .primary)
                    if style != .focus {
                        if viewModel.mode == .exam {
                            metric("Chyby", "\(engine.errors)", tint: engine.errors > 0 ? .orange : .primary)
                        } else {
                            metric("Combo", "\(engine.combo)")
                        }
                        if !viewModel.mode.isTimed {
                            metric("Čas", Format.duration(engine.elapsed(at: context.date)))
                        }
                    }
                }
            }

            HStack(spacing: 4) {
                if style.showsKeyboard {
                    toggleButton(isOn: $showsKeyboard, symbol: "keyboard", help: "Zobrazit klávesnici (⇧⌘K)", key: "k")
                    toggleButton(isOn: $showsHands, symbol: "hand.raised", help: "Zobrazit ruce (⇧⌘H)", key: "h")
                    Button {
                        viewModel.nextExercise()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .keyboardShortcut("r", modifiers: .command)
                    .help("Nový text (⌘R)")
                    .accessibilityLabel("Nový text")
                }
                metronomeButton
                styleMenu
            }
            .buttonStyle(.borderless)
            .imageScale(.large)
        }
    }

    /// Minimal: jen zavření a čas.
    private var minimalHeader: some View {
        HStack {
            Button(action: closeTapped) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help("Ukončit (Esc)")

            Spacer()

            TimelineView(.periodic(from: .now, by: 0.25)) { context in
                Text(Format.duration(viewModel.remainingTime(at: context.date)?.rounded(.up) ?? engine.elapsed(at: context.date)))
                    .font(.system(.title3, design: .rounded).weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            styleMenu
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
        }
    }

    private var metronomeButton: some View {
        Button {
            metronomeEnabled.toggle()
            viewModel.setMetronome(metronomeEnabled)
        } label: {
            Image(systemName: metronomeEnabled ? "metronome.fill" : "metronome")
                .foregroundStyle(metronomeEnabled ? theme.accent : Color.secondary)
                .frame(width: 26, height: 22)
        }
        .keyboardShortcut("m", modifiers: [.command, .shift])
        .help("Metronom – \(Int(viewModel.metronomeBeatsPerMinute)) úderů za minutu (⇧⌘M)")
        .accessibilityLabel(metronomeEnabled ? "Vypnout metronom" : "Zapnout metronom")
    }

    /// Živá rychlost ve zvolené jednotce.
    private func liveSpeed(at date: Date) -> String {
        switch speedUnit {
        case .wpm: Format.wpm(engine.wpm(at: date))
        case .cpm: Format.wpm(engine.wpm(at: date) * 5)
        case .strokes: Format.wpm(engine.strokesPerMinute(at: date))
        }
    }

    private var styleMenu: some View {
        Menu {
            Picker("Vzhled psaní", selection: styleBinding) {
                ForEach(TypingStyle.allCases) { option in
                    Label(option.title, systemImage: option.symbol).tag(option)
                }
            }
            .pickerStyle(.inline)
        } label: {
            Image(systemName: style.symbol)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Vzhled obrazovky psaní · Focus ⇧⌘F")
        .accessibilityLabel("Vzhled obrazovky psaní")
    }

    private var styleBinding: Binding<TypingStyle> {
        Binding(
            get: { themeManager.typingStyle },
            set: { newValue in
                withAnimation(reduceMotion ? nil : .smooth(duration: 0.25)) { themeManager.typingStyle = newValue }
            }
        )
    }

    /// Klávesové zkratky, které fungují i v Minimal (kde tlačítka nejsou vidět).
    private var shortcutButtons: some View {
        Button("Focus Mode") { toggleFocus() }
            .keyboardShortcut("f", modifiers: [.command, .shift])
            .opacity(0)
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
    }

    private func toggleFocus() {
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.25)) {
            if style == .focus {
                themeManager.typingStyle = TypingStyle(rawValue: previousStyleRaw) ?? .standard
            } else {
                previousStyleRaw = style.rawValue
                themeManager.typingStyle = .focus
            }
        }
    }

    private func toggleButton(isOn: Binding<Bool>, symbol: String, help: String, key: KeyEquivalent) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            Image(systemName: symbol)
                .symbolVariant(isOn.wrappedValue ? .fill : .none)
                .foregroundStyle(isOn.wrappedValue ? theme.accent : Color.secondary)
                .frame(width: 26, height: 22)
        }
        .keyboardShortcut(key, modifiers: [.command, .shift])
        .help(help)
        .accessibilityLabel(help)
    }

    private var subtitle: String {
        var parts = [viewModel.plan.difficulty.title, viewModel.plan.speed.label]
        let focus = viewModel.exercise.focusKeys.map { Curriculum.displayName(for: $0) }
        if !focus.isEmpty {
            parts.append("procvičujeme \(focus.joined(separator: ", "))")
        }
        return parts.joined(separator: " · ")
    }

    private var targetLabel: String? {
        guard let target = viewModel.plan.speed.targetWPM else { return nil }
        return "cíl \(speedUnit.format(target))"
    }

    @ViewBuilder
    private func modeIndicator(at date: Date) -> some View {
        switch viewModel.mode {
        case .timeAttack, .exam, .speedTest:
            let remaining = viewModel.remainingTime(at: date) ?? 0
            metric("Zbývá", Format.duration(remaining.rounded(.up)),
                   tint: remaining <= 5 && engine.isStarted ? .red : .primary)
        case .survival:
            VStack(alignment: .trailing, spacing: 0) {
                HStack(spacing: 3) {
                    ForEach(0..<viewModel.plan.lives, id: \.self) { index in
                        Image(systemName: index < viewModel.lives ? "heart.fill" : "heart")
                            .foregroundStyle(index < viewModel.lives ? Color.red : Color.secondary)
                    }
                }
                .font(.system(size: 17))
                .frame(height: 24)
                .symbolEffect(.bounce, value: viewModel.lifeLostPulse)
                Text("Vlna \(viewModel.wave) · min \(speedUnit.label(viewModel.survivalRequiredWPM ?? 0))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
            .fixedSize()
        case .accuracyChallenge:
            metric("Zbývá chyb", "\(viewModel.errorsLeft ?? 0)",
                   tint: (viewModel.errorsLeft ?? 0) == 0 ? .red : .primary)
        case .practice, .sprint, .endless, .customText:
            EmptyView()
        }
    }

    private func metric(_ title: String, _ value: String, detail: String? = nil, tint: Color = .primary) -> some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text(value)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tint)
                .contentTransition(.numericText())
            Text(detail.map { "\(title) · \($0)" } ?? title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .lineLimit(1)
        .fixedSize()
        .frame(minWidth: 50, alignment: .trailing)
    }

    // MARK: - Průběh

    @ViewBuilder
    private var progressBar: some View {
        if let limit = viewModel.plan.timeLimit {
            TimelineView(.periodic(from: .now, by: 0.1)) { context in
                let remaining = viewModel.remainingTime(at: context.date) ?? 0
                ProgressView(value: limit - remaining, total: limit)
            }
        } else if viewModel.mode.usesContinuousText {
            // Endless / Survival nemají konec – jen jemná linka.
            Divider()
        } else {
            ProgressView(value: engine.progress)
                .animation(.easeOut(duration: 0.15), value: engine.progress)
        }
    }

    @ViewBuilder
    private var milestoneBadge: some View {
        if let milestone = visibleMilestone {
            let effect = themeManager.comboEffect
            let tint: Color = effect == .flame ? .orange : theme.accent
            Label {
                Text("\(milestone) combo")
            } icon: {
                Image(systemName: effect.symbol)
                    .symbolRenderingMode(effect == .flame ? .multicolor : .monochrome)
                    .symbolEffect(.bounce, value: reduceMotion || effect == .classic ? 0 : milestone)
            }
            .font(effect == .classic ? .callout.weight(.semibold) : .title3.weight(.bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.regularMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(tint.opacity(effect == .classic ? 0.25 : 0.5), lineWidth: effect == .classic ? 1 : 1.5))
            .shadow(color: effect == .classic || reduceMotion ? .clear : tint.opacity(0.35), radius: 10)
            .padding(12)
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
        }
    }

    // MARK: - Nápověda

    @ViewBuilder
    private var hint: some View {
        if !engine.isStarted {
            Label(startHint, systemImage: "keyboard")
                .foregroundStyle(.secondary)
        } else if engine.currentHasError, let expected = engine.expected {
            Label("Zkus to znovu: \(displayName(for: expected))", systemImage: "arrow.uturn.backward")
                .foregroundStyle(.red)
        } else if let stroke = currentStroke {
            HStack(spacing: 6) {
                Circle().fill(stroke.primary.finger.color).frame(width: 8, height: 8)
                Text(fingerHint(for: stroke))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var startHint: String {
        switch viewModel.mode {
        case .timeAttack: "Odpočet se spustí prvním stiskem. Esc ukončí bez uložení."
        case .endless: "Piš, jak dlouho chceš. Esc nebo Dokončit výsledek uloží."
        case .survival: "Každá chyba stojí život. Esc ukončí bez uložení."
        case .accuracyChallenge: "Nejvýše \(viewModel.plan.maxErrors) chyby. Esc ukončí bez uložení."
        case .practice, .sprint: "Začni psát – čas se spustí prvním stiskem. Esc ukončí cvičení."
        case .exam: "Zkouška \(viewModel.plan.examDuration.title): čas běží od prvního stisku. Chyba = −100 úhozů. Esc ukončí bez uložení."
        case .customText: "Opiš svůj text. Čas se spustí prvním stiskem, Esc ukončí bez uložení."
        case .speedTest: "Test \(viewModel.plan.speedTestDuration.title): čas běží od prvního stisku. Esc ukončí bez uložení."
        }
    }

    private func fingerHint(for stroke: KeyStroke) -> String {
        guard let expected = engine.expected else { return "" }
        var text = "\(displayName(for: expected)) – \(stroke.primary.finger.name)"
        if let shift = stroke.keys.first(where: { $0.kind == .leftShift || $0.kind == .rightShift }) {
            text += " + \(shift.kind == .leftShift ? "levý" : "pravý") Shift (\(shift.finger.name))"
        }
        return text
    }

    private func displayName(for character: Character) -> String {
        character == " " ? "mezerník" : String(character)
    }

    // MARK: - Klávesnice

    private func closeTapped() {
        if viewModel.escape() == .close { onClose() }
    }

    @MainActor
    private func handleKeyDown(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        // Zkratky s ⌘ a ⌃ necháme systému (⌘R, ⌘Q…).
        if modifiers.contains(.command) || modifiers.contains(.control) { return false }

        switch event.keyCode {
        case 53: // Esc
            closeTapped()
            return true
        case 36, 48, 51, 76, 117: // Return, Tab, Backspace, Enter, Delete
            return true
        default:
            viewModel.handleInput(event.characters ?? "")
            return true
        }
    }
}
