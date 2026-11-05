import AVFoundation
import os

/// Události, které může spustit zbytek aplikace. View ani ViewModel nevědí nic o audiu.
protocol SoundPlaying: AnyObject {
    func playKeySound()
    func playError()
    func playMilestone()
    func playCompletion()
    func playRecord()
    func playChallenge()
    func playAchievement()
    func playLevelUp()
    /// Metronom pro rytmické psaní (běží, dokud se nezastaví).
    func startMetronome(beatsPerMinute: Double)
    func stopMetronome()
}

/// Nízkolatenční přehrávání krátkých zvuků přes AVAudioEngine.
///
/// - Všechny zvuky se vygenerují při startu do `AVAudioPCMBuffer` (žádné načítání při stisku).
/// - Každá kategorie má sadu přehrávačů, které se střídají → zvuky se mohou překrývat.
/// - Volání z UI jen zařadí práci na vlastní frontu a hned se vrátí → psaní nic nebrzdí.
final class AudioManager: SoundPlaying, @unchecked Sendable {
    static let shared = AudioManager()

    private static let typingVoices = 10
    private static let rewardVoices = 4
    private static let log = Logger(subsystem: "cz.frantisekpetran.Desetiprstka", category: "audio")

    private let queue = DispatchQueue(label: "cz.frantisekpetran.Desetiprstka.audio", qos: .userInteractive)
    private let engine = AVAudioEngine()
    private let typingMixer = AVAudioMixerNode()
    private let rewardMixer = AVAudioMixerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!

    // Vše níže se používá jen na `queue`.
    private var typingPlayers: [AVAudioPlayerNode] = []
    private var rewardPlayers: [AVAudioPlayerNode] = []
    private var nextTypingVoice = 0
    private var nextRewardVoice = 0
    private var nextVariant = 0
    private var keyBuffers: [SoundPack: [AVAudioPCMBuffer]] = [:]
    private var errorBuffer: AVAudioPCMBuffer?
    private var rewardBuffers: [SoundEffect: AVAudioPCMBuffer] = [:]
    private var settings = AudioSettings.load()
    private var isPrepared = false
    private var observers: [NSObjectProtocol] = []
    // Metronom – vlastní přehrávač, údery plánované na vzorek přesně.
    private let metronomePlayer = AVAudioPlayerNode()
    private var metronomeBuffer: AVAudioPCMBuffer?
    private var metronomeGeneration = 0
    private var metronomeNextBeat: AVAudioFramePosition = 0
    private var metronomeInterval: AVAudioFramePosition = 0
    private var metronomeQueued = 0

    private init() {}

    // MARK: - Příprava

    /// Volat jednou při startu aplikace – postaví buffery a spustí engine na pozadí.
    func prepare() {
        queue.async { self.setUp() }
    }

    private func setUp() {
        guard !isPrepared else { return }
        let started = DispatchTime.now().uptimeNanoseconds

        var synth = SoundSynthesizer(sampleRate: format.sampleRate)
        for pack in SoundPack.allCases where pack != .silent {
            // Nahrávky mají přednost, syntéza zůstává jako záloha.
            let recorded = SampleLibrary.keyVariants(for: pack, format: format)
            keyBuffers[pack] = recorded.isEmpty
                ? synth.keyVariants(for: pack).compactMap(makeBuffer)
                : recorded
            Self.log.info("Balíček \(pack.rawValue, privacy: .public): \(recorded.isEmpty ? "syntéza" : "\(recorded.count) nahrávek", privacy: .public)")
        }
        errorBuffer = makeBuffer(synth.error())
        metronomeBuffer = makeBuffer(synth.metronomeTick())
        for effect in [SoundEffect.milestone] + SoundEffect.rewards {
            rewardBuffers[effect] = makeBuffer(synth.reward(effect))
        }

        engine.attach(typingMixer)
        engine.attach(rewardMixer)
        engine.connect(typingMixer, to: engine.mainMixerNode, format: format)
        engine.connect(rewardMixer, to: engine.mainMixerNode, format: format)
        typingPlayers = (0..<Self.typingVoices).map { _ in attachPlayer(to: typingMixer) }
        rewardPlayers = (0..<Self.rewardVoices).map { _ in attachPlayer(to: rewardMixer) }
        engine.attach(metronomePlayer)
        engine.connect(metronomePlayer, to: typingMixer, format: format)
        applyVolumes()
        engine.prepare()
        startEngine()

        observers.append(NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: nil
        ) { [weak self] _ in
            // Změna výstupu (sluchátka, AirPods…) – engine je potřeba znovu spustit.
            self?.queue.async { self?.startEngine() }
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: nil
        ) { [weak self] _ in
            self?.queue.async { self?.reloadSettings() }
        })

        isPrepared = true
        let elapsed = Double(DispatchTime.now().uptimeNanoseconds - started) / 1_000_000
        Self.log.info("Audio připraveno za \(elapsed, format: .fixed(precision: 1), privacy: .public) ms, výstup \(self.engine.outputNode.outputFormat(forBus: 0).sampleRate, privacy: .public) Hz")
    }

    private func attachPlayer(to mixer: AVAudioMixerNode) -> AVAudioPlayerNode {
        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: mixer, format: format)
        return player
    }

    private func startEngine() {
        do {
            if !engine.isRunning { try engine.start() }
            // Přehrávače běží stále → naplánovaný buffer zazní okamžitě.
            (typingPlayers + rewardPlayers).forEach { if !$0.isPlaying { $0.play() } }
        } catch {
            Self.log.error("Audio engine se nespustil: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func reloadSettings() {
        let fresh = AudioSettings.load()
        guard fresh != settings else { return }
        settings = fresh
        applyVolumes()
    }

    private func applyVolumes() {
        typingMixer.outputVolume = settings.typingVolume
        rewardMixer.outputVolume = settings.rewardVolume
    }

    private func makeBuffer(_ samples: [Float]) -> AVAudioPCMBuffer? {
        guard !samples.isEmpty,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let channel = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { source in
            if let base = source.baseAddress { channel.update(from: base, count: samples.count) }
        }
        return buffer
    }

    // MARK: - Události

    func playKeySound() { play(.key) }
    func playError() { play(.error) }
    func playMilestone() { play(.milestone) }
    func playCompletion() { play(.completion) }
    func playRecord() { play(.record) }
    func playChallenge() { play(.challenge) }
    func playAchievement() { play(.achievement) }
    func playLevelUp() { play(.levelUp) }

    /// Zařadí zvuk a okamžitě se vrátí.
    func play(_ effect: SoundEffect, delay: TimeInterval = 0) {
        let enqueued = DispatchTime.now().uptimeNanoseconds
        let work = { [self] in
            guard isPrepared, isEnabled(effect), let buffer = buffer(for: effect) else { return }
            schedule(buffer, category: effect.category)
            if effect == .key { LatencyProbe.shared.recordAudioDispatch(since: enqueued) }
        }
        if delay > 0 {
            queue.asyncAfter(deadline: .now() + delay, execute: work)
        } else {
            queue.async(execute: work)
        }
    }

    // MARK: - Metronom

    func startMetronome(beatsPerMinute: Double) {
        queue.async { [self] in
            guard isPrepared, metronomeBuffer != nil, beatsPerMinute > 0 else { return }
            if !engine.isRunning { startEngine() }
            metronomeGeneration += 1
            metronomePlayer.stop()
            metronomeQueued = 0
            metronomeInterval = AVAudioFramePosition(format.sampleRate * 60 / beatsPerMinute)
            // Časová osa přehrávače začíná po play() od nuly → první úder za 30 ms.
            metronomeNextBeat = AVAudioFramePosition(format.sampleRate * 0.03)
            metronomePlayer.play()
            scheduleMetronomeBeats(generation: metronomeGeneration)
        }
    }

    func stopMetronome() {
        queue.async { [self] in
            metronomeGeneration += 1
            metronomeQueued = 0
            metronomePlayer.stop()
        }
    }

    /// Drží ve frontě pár úderů dopředu; po každém přehraném se doplní další.
    private func scheduleMetronomeBeats(generation: Int) {
        guard generation == metronomeGeneration, let tick = metronomeBuffer else { return }
        while metronomeQueued < 4 {
            let time = AVAudioTime(sampleTime: metronomeNextBeat, atRate: format.sampleRate)
            metronomePlayer.scheduleBuffer(tick, at: time, options: [], completionCallbackType: .dataPlayedBack) { [weak self] _ in
                guard let self else { return }
                self.queue.async {
                    guard generation == self.metronomeGeneration else { return }
                    self.metronomeQueued -= 1
                    self.scheduleMetronomeBeats(generation: generation)
                }
            }
            metronomeNextBeat += metronomeInterval
            metronomeQueued += 1
        }
    }

    // MARK: - Náhledy v Nastavení (hrají i když je kategorie vypnutá)

    func preview(_ pack: SoundPack) {
        queue.async { [self] in
            guard isPrepared, let variants = keyBuffers[pack], !variants.isEmpty else { return }
            // Krátká „věta“ úhozů s jednou chybou.
            let rhythm: [Double] = [0, 0.11, 0.2, 0.33, 0.42, 0.5, 0.64]
            for (index, time) in rhythm.enumerated() {
                queue.asyncAfter(deadline: .now() + time) { [self] in
                    if index == 4, settings.errorEnabled, let errorBuffer {
                        schedule(errorBuffer, category: .typing)
                    } else {
                        schedule(variants[index % variants.count], category: .typing)
                    }
                }
            }
        }
    }

    /// Pár úderů metronomu jako ukázka.
    func previewMetronome(beatsPerMinute: Double = 180) {
        startMetronome(beatsPerMinute: beatsPerMinute)
        queue.asyncAfter(deadline: .now() + 60 / beatsPerMinute * 4 + 0.05) { [self] in
            metronomeGeneration += 1
            metronomeQueued = 0
            metronomePlayer.stop()
        }
    }

    func preview(_ effect: SoundEffect) {
        queue.async { [self] in
            guard isPrepared, let buffer = buffer(for: effect) else { return }
            schedule(buffer, category: effect.category)
        }
    }

    // MARK: - Interní (na `queue`)

    private func isEnabled(_ effect: SoundEffect) -> Bool {
        switch effect {
        case .key: settings.typingEnabled && settings.pack != .silent
        case .error: settings.errorEnabled
        default: settings.rewardsEnabled
        }
    }

    private func buffer(for effect: SoundEffect) -> AVAudioPCMBuffer? {
        switch effect {
        case .key:
            guard let variants = keyBuffers[settings.pack], !variants.isEmpty else { return nil }
            nextVariant = (nextVariant + 1) % variants.count
            return variants[nextVariant]
        case .error:
            return errorBuffer
        default:
            return rewardBuffers[effect]
        }
    }

    private func schedule(_ buffer: AVAudioPCMBuffer, category: SoundEffect.Category) {
        if !engine.isRunning { startEngine() }
        let player: AVAudioPlayerNode
        switch category {
        case .typing:
            player = typingPlayers[nextTypingVoice]
            nextTypingVoice = (nextTypingVoice + 1) % typingPlayers.count
        case .reward:
            player = rewardPlayers[nextRewardVoice]
            nextRewardVoice = (nextRewardVoice + 1) % rewardPlayers.count
        }
        // `.interrupts` – starý zvuk na stejném hlasu se utne, nikdy se nic neřadí do fronty.
        player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        if !player.isPlaying { player.play() }
    }
}
