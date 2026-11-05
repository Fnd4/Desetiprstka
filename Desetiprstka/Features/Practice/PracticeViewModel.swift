import Foundation
import Observation

/// Shrnutí po dokončení cvičení.
struct PracticeSummary {
    let result: SessionResult
    /// Vyhodnocení obtížnosti textu (jen klasické cvičení na úrovni podle pokroku).
    let evaluation: AdaptiveEngine.Evaluation?
    let recommendedKey: String?
    let outcome: SessionOutcome
    let plan: ResolvedPractice
}

/// Řídí průběh cvičení ve všech režimech: představení nových kláves → psaní → výsledky.
@MainActor
@Observable
final class PracticeViewModel {
    enum Phase {
        case intro([String])
        case typing
        case results(PracticeSummary)
    }

    enum EscapeAction {
        case close
        case handled
    }

    private(set) var phase: Phase
    private(set) var exercise: Exercise
    private(set) var engine: TypingEngine
    private(set) var knownKeys: Set<String>
    private(set) var plan: ResolvedPractice

    // Stav režimů
    private(set) var lives: Int
    private(set) var wave = 1
    private(set) var lifeLostPulse = 0

    private let configuration: PracticeConfiguration
    private let store: ProgressStore
    private let preferredLength: ExerciseLength
    private let generator = ExerciseGenerator()
    private let adaptive = AdaptiveEngine()
    /// Zvuky – ViewModel zná jen události, ne audio implementaci.
    private let sound: SoundPlaying

    @ObservationIgnored private var weights: [String: Double]
    @ObservationIgnored private var timerTask: Task<Void, Never>?
    @ObservationIgnored private var chunkEnds: [Int] = []
    @ObservationIgnored private var waveStartIndex = 0
    @ObservationIgnored private var waveStartDate: Date?
    @ObservationIgnored private var lastMilestonePulse = 0

    init(
        store: ProgressStore,
        configuration: PracticeConfiguration,
        preferredLength: ExerciseLength,
        sound: SoundPlaying = AudioManager.shared
    ) {
        self.store = store
        self.sound = sound
        self.configuration = configuration
        self.preferredLength = preferredLength
        let setup = Self.prepare(
            store: store,
            configuration: configuration,
            preferredLength: preferredLength,
            generator: ExerciseGenerator(),
            adaptive: AdaptiveEngine()
        )
        self.exercise = setup.exercise
        self.engine = TypingEngine(text: setup.exercise.text)
        self.knownKeys = setup.knownKeys
        self.plan = setup.plan
        self.weights = setup.weights
        self.lives = setup.plan.lives
        self.phase = setup.newKeys.isEmpty ? .typing : .intro(setup.newKeys)
        resetModeState()
    }

    var mode: GameMode { plan.mode }

    /// Zbývající čas (Time Attack, Zkouška).
    func remainingTime(at date: Date) -> TimeInterval? {
        guard let limit = plan.timeLimit else { return nil }
        return max(limit - engine.elapsed(at: date), 0)
    }

    /// Tempo metronomu: cílová rychlost převedená na úhozy za minutu.
    var metronomeBeatsPerMinute: Double {
        let wpm = plan.speed.targetWPM ?? 24
        return min(max(wpm * 5, 40), 400)
    }

    var errorsLeft: Int? {
        guard mode == .accuracyChallenge else { return nil }
        return max(plan.maxErrors - engine.errors, 0)
    }

    /// Minimální tempo aktuální vlny v Survival.
    var survivalRequiredWPM: Double? {
        guard mode == .survival else { return nil }
        return ModeRules.survivalRequiredWPM(wave: wave, baseTarget: plan.speed.targetWPM)
    }

    // MARK: - Akce

    /// Zpracuje text z klávesnice. Vrací `true`, pokud byl stisk použit.
    @discardableResult
    func handleInput(_ characters: String) -> Bool {
        guard case .typing = phase, !engine.isStopped else { return false }
        let started = DispatchTime.now().uptimeNanoseconds
        let wasStarted = engine.isStarted
        let outcome = engine.type(characters)
        guard outcome != .ignored else { return false }
        defer { LatencyProbe.shared.recordInput(since: started) }

        if !wasStarted, engine.isStarted { didStart() }

        switch outcome {
        case .correct:
            sound.playKeySound()
            didTypeCorrectly()
        case .incorrect:
            didMakeError()
        case .finished:
            sound.playKeySound()
            finish(completed: true)
        case .ignored:
            break
        }
        return true
    }

    /// Esc: většina režimů se zahodí, Endless se uloží.
    func escape() -> EscapeAction {
        guard case .typing = phase else { return .close }
        if mode.savesOnEscape, engine.position > 0 {
            finish(completed: true)
            return .handled
        }
        cancel()
        return .close
    }

    /// Uživatel ukončil Endless tlačítkem „Dokončit“.
    func finishEndless() {
        guard case .typing = phase, engine.position > 0 else { return }
        finish(completed: true)
    }

    func cancel() {
        timerTask?.cancel()
        timerTask = nil
        sound.stopMetronome()
    }

    /// Zapne/vypne metronom i během psaní.
    func setMetronome(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: SettingsKey.metronomeEnabled)
        guard case .typing = phase, engine.isStarted, !engine.isStopped else { return }
        if enabled {
            sound.startMetronome(beatsPerMinute: metronomeBeatsPerMinute)
        } else {
            sound.stopMetronome()
        }
    }

    func completeIntro() {
        if case .intro(let keys) = phase {
            store.markIntroduced(keys)
        }
        phase = .typing
    }

    /// Nové cvičení se stejnou konfigurací.
    func nextExercise() {
        cancel()
        let setup = Self.prepare(
            store: store,
            configuration: configuration,
            preferredLength: preferredLength,
            generator: generator,
            adaptive: adaptive
        )
        exercise = setup.exercise
        engine = TypingEngine(text: setup.exercise.text)
        knownKeys = setup.knownKeys
        plan = setup.plan
        weights = setup.weights
        resetModeState()
        phase = setup.newKeys.isEmpty ? .typing : .intro(setup.newKeys)
    }

    /// Stejný text znovu od začátku (nekonečné režimy dostanou nový text).
    func restart() {
        if mode.usesContinuousText {
            nextExercise()
            return
        }
        cancel()
        engine = TypingEngine(text: exercise.text)
        resetModeState()
        phase = .typing
    }

    func addKeyAndContinue(_ key: String) {
        store.addKnownKey(key)
        store.refreshAchievements()
        nextExercise()
    }

    func applySpeed(_ setting: SpeedSetting) {
        store.setSpeed(setting)
    }

    // MARK: - Průběh režimů

    private func resetModeState() {
        lives = plan.lives
        wave = 1
        waveStartIndex = 0
        waveStartDate = nil
        lastMilestonePulse = 0
        chunkEnds = [engine.characters.count]
        if mode.usesContinuousText {
            appendChunk()
            // Dost textu dopředu hned od začátku (stránky v TypingTextView jsou pevné).
            while engine.remainingCharacters < ModeRules.continuousLookahead { appendChunk() }
        }
    }

    private func didStart() {
        waveStartDate = engine.startedAt
        if UserDefaults.standard.bool(forKey: SettingsKey.metronomeEnabled) {
            sound.startMetronome(beatsPerMinute: metronomeBeatsPerMinute)
        }
        guard let limit = plan.timeLimit, let startedAt = engine.startedAt else { return }
        let deadline = startedAt.addingTimeInterval(limit)
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            let delay = max(deadline.timeIntervalSinceNow, 0)
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.timeUp(at: deadline)
        }
    }

    private func timeUp(at deadline: Date) {
        guard case .typing = phase else { return }
        engine.stop(at: deadline)
        finish(completed: true)
    }

    private func didTypeCorrectly() {
        if engine.milestonePulse != lastMilestonePulse {
            lastMilestonePulse = engine.milestonePulse
            if let milestone = engine.comboMilestone, milestone >= 25 {
                sound.playMilestone()
            }
        }

        if mode == .survival { checkSurvivalWave() }

        if mode.usesContinuousText, engine.remainingCharacters < ModeRules.continuousLookahead {
            appendChunk()
        }
    }

    private func didMakeError() {
        sound.playError()
        switch mode {
        case .accuracyChallenge:
            if engine.errors > plan.maxErrors {
                finish(completed: false)
            }
        case .survival:
            loseLife()
        case .practice, .timeAttack, .sprint, .endless, .exam, .customText, .speedTest:
            break
        }
    }

    private func loseLife() {
        guard lives > 0 else { return }
        lives -= 1
        lifeLostPulse += 1
        if lives == 0 {
            finish(completed: true)
        }
    }

    /// Survival: po dokončení vlny zkontroluje tempo a zvýší obtížnost.
    private func checkSurvivalWave() {
        guard wave - 1 < chunkEnds.count, engine.position >= chunkEnds[wave - 1] else { return }
        let now = Date.now
        if let start = waveStartDate {
            let typed = engine.position - waveStartIndex
            let waveWPM = TypingMetrics.wpm(characters: typed, duration: now.timeIntervalSince(start))
            if let required = survivalRequiredWPM, waveWPM < required {
                loseLife()
                guard case .typing = phase else { return }
            }
        }
        wave += 1
        waveStartIndex = engine.position
        waveStartDate = now
    }

    /// Připojí další blok textu (Survival: každý blok je o úroveň těžší).
    private func appendChunk() {
        let level: Int
        if mode == .survival {
            level = plan.difficulty.level + chunkEnds.count
        } else {
            level = plan.difficulty.level
        }
        let chunk = generator.makeExercise(
            knownKeys: knownKeys,
            difficulty: Difficulty(level: level),
            weights: weights,
            targetLength: plan.chunkLength
        )
        engine.append(chunk.text)
        chunkEnds.append(engine.characters.count)
    }

    private func finish(completed: Bool) {
        cancel()
        engine.stop()

        let score: Int?
        switch mode {
        case .timeAttack, .survival, .endless: score = engine.position
        case .exam:
            // Skóre zkoušky = čisté úhozy za minutu.
            let evaluation = ExamEvaluation(
                grossStrokes: engine.grossStrokes,
                errors: engine.errors,
                duration: plan.examDuration.seconds
            )
            score = Int(evaluation.netPerMinute.rounded())
        case .practice, .sprint, .accuracyChallenge, .customText, .speedTest: score = nil
        }

        guard let result = engine.makeResult(
            difficulty: plan.difficulty,
            mode: mode,
            targetWPM: plan.speed.targetWPM,
            completed: completed,
            score: score,
            timeLimit: plan.timeLimit.map { Int($0) },
            wave: mode == .survival ? wave : nil
        ) else { return }

        let profile = store.profile()
        var evaluation: AdaptiveEngine.Evaluation?
        if mode.affectsTextDifficulty, plan.usesProfileLevel {
            evaluation = adaptive.evaluate(
                result: result,
                current: profile.difficulty,
                goodStreak: profile.goodStreak,
                speedTarget: plan.speed.targetWPM
            )
        }

        let outcome = store.record(result, evaluation: evaluation)
        let recommended = adaptive.recommendNewKey(
            knownKeys: profile.knownKeySet,
            snapshots: store.snapshots(),
            lastResult: result
        )

        playRewardSounds(for: result, outcome: outcome)

        phase = .results(PracticeSummary(
            result: result,
            evaluation: evaluation,
            recommendedKey: recommended,
            outcome: outcome,
            plan: plan
        ))
    }

    /// Dokončení hned, nejdůležitější odměna o chvilku později (nikdy kakofonie).
    private func playRewardSounds(for result: SessionResult, outcome: SessionOutcome) {
        if result.completed { sound.playCompletion() }

        let effect: SoundEffect?
        if outcome.leveledUp {
            effect = .levelUp
        } else if !outcome.newRecords.isEmpty {
            effect = .record
        } else if !outcome.unlockedAchievements.isEmpty {
            effect = .achievement
        } else if outcome.completedChallenge != nil {
            effect = .challenge
        } else {
            effect = nil
        }
        guard let effect else { return }
        let sound = sound
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 450_000_000)
            switch effect {
            case .levelUp: sound.playLevelUp()
            case .record: sound.playRecord()
            case .achievement: sound.playAchievement()
            default: sound.playChallenge()
            }
        }
    }

    // MARK: - Příprava

    private struct Setup {
        let exercise: Exercise
        let knownKeys: Set<String>
        let newKeys: [String]
        let plan: ResolvedPractice
        let weights: [String: Double]
    }

    private static func prepare(
        store: ProgressStore,
        configuration: PracticeConfiguration,
        preferredLength: ExerciseLength,
        generator: ExerciseGenerator,
        adaptive: AdaptiveEngine
    ) -> Setup {
        let profile = store.profile()
        let progress = store.playerProgress()
        let plan = PracticePlanner().resolve(
            configuration,
            profileLevel: profile.level,
            speed: progress.speedSetting,
            preferredLength: preferredLength,
            recentAccuracy: store.recentAccuracy()
        )
        // Test rychlosti používá celou abecedu a rovné váhy – výsledky jsou porovnatelné.
        let known = plan.mode == .speedTest ? Curriculum.allLetters : profile.knownKeySet
        let weights = plan.mode == .speedTest
            ? [:]
            : adaptive.practiceWeights(knownKeys: known, snapshots: store.snapshots())
        let exercise: Exercise
        if plan.mode == .customText, let text = plan.customText, !text.isEmpty {
            exercise = Exercise(text: text, difficulty: plan.difficulty, focusKeys: [])
        } else {
            exercise = generator.makeExercise(
                knownKeys: known,
                difficulty: plan.difficulty,
                weights: weights,
                targetLength: plan.targetLength
            )
        }
        // Vlastní text a Zkouška nepřerušují úvodem nových písmen.
        let skipsIntro = plan.mode == .customText || plan.mode == .speedTest
        let newKeys = skipsIntro ? [] : Curriculum.sorted(known.subtracting(profile.introducedKeys))
        return Setup(exercise: exercise, knownKeys: known, newKeys: newKeys, plan: plan, weights: weights)
    }
}
