import Foundation

/// Generuje krátké zvuky přímo v kódu (bez audio souborů).
/// Volá se jen jednou při startu – výsledek se drží v paměti jako hotové buffery.
struct SoundSynthesizer {
    let sampleRate: Double
    private var rng: SeededRandomGenerator

    init(sampleRate: Double, seed: UInt64 = 0xD35E7) {
        self.sampleRate = sampleRate
        self.rng = SeededRandomGenerator(seed: seed)
    }

    // MARK: - Úhozy

    /// Několik mírně odlišných variant úhozu, aby rychlé psaní neznělo jako kulomet.
    mutating func keyVariants(for pack: SoundPack, count: Int = 4) -> [[Float]] {
        guard pack != .silent else { return [] }
        return (0..<count).map { _ in
            let pitch = Double.random(in: 0.94...1.06, using: &rng)
            let level = Float.random(in: 0.9...1.0, using: &rng)
            return normalized(key(for: pack, pitch: pitch), peak: 0.8 * level)
        }
    }

    private mutating func key(for pack: SoundPack, pitch p: Double) -> [Float] {
        switch pack {
        case .silent:
            return []
        case .soft:
            var out = buffer(seconds: 0.06)
            addNoise(&out, at: 0, center: 1500 * p, q: 0.8, decay: 0.012, amplitude: 0.25)
            addSine(&out, at: 0, frequency: 420 * p, decay: 0.025, amplitude: 0.12)
            return out
        case .mechanical:
            var out = buffer(seconds: 0.11)
            addNoise(&out, at: 0, center: 3500 * p, q: 1.2, decay: 0.004, amplitude: 0.5)
            addNoise(&out, at: 0.002, center: 600 * p, q: 1.0, decay: 0.03, amplitude: 0.35)
            addSine(&out, at: 0.002, frequency: 160 * p, decay: 0.035, amplitude: 0.2)
            addNoise(&out, at: 0.045, center: 2500 * p, q: 1.5, decay: 0.005, amplitude: 0.18)
            return out
        case .typewriter:
            var out = buffer(seconds: 0.14)
            addNoise(&out, at: 0, center: 2200 * p, q: 2.0, decay: 0.01, amplitude: 0.55)
            addSine(&out, at: 0.001, frequency: 2800 * p, decay: 0.07, amplitude: 0.08)
            addSine(&out, at: 0.001, frequency: 4150 * p, decay: 0.05, amplitude: 0.05)
            addSine(&out, at: 0.001, frequency: 5600 * p, decay: 0.035, amplitude: 0.03)
            addSine(&out, at: 0, frequency: 110 * p, decay: 0.03, amplitude: 0.15)
            return out
        case .clicky:
            var out = buffer(seconds: 0.05)
            addNoise(&out, at: 0, center: 4800 * p, q: 3.0, decay: 0.003, amplitude: 0.6)
            addNoise(&out, at: 0.014, center: 4200 * p, q: 3.0, decay: 0.003, amplitude: 0.45)
            addSine(&out, at: 0, frequency: 900 * p, decay: 0.01, amplitude: 0.1)
            return out
        }
    }

    /// Chyba – měkké „bum“ s klesající výškou, ne bzučák.
    mutating func error() -> [Float] {
        var out = buffer(seconds: 0.16)
        let count = out.count
        var phase = 0.0
        for i in 0..<count {
            let t = Double(i) / sampleRate
            let frequency = 330 - 90 * min(t / 0.09, 1)
            phase += 2 * .pi * frequency / sampleRate
            let envelope = attack(t, 0.004) * exp(-t / 0.05)
            out[i] += Float(sin(phase) * envelope * 0.35)
        }
        addNoise(&out, at: 0, center: 500, q: 0.7, decay: 0.015, amplitude: 0.08)
        return normalized(out, peak: 0.55)
    }

    /// Metronom – krátké dřevěné „tok“, nevtíravé i při 300 úderech za minutu.
    mutating func metronomeTick() -> [Float] {
        var out = buffer(seconds: 0.035)
        for i in 0..<out.count {
            let t = Double(i) / sampleRate
            let envelope = attack(t, 0.0008) * exp(-t / 0.008)
            out[i] += Float(sin(2 * .pi * 1_760 * t) * envelope * 0.5 + sin(2 * .pi * 880 * t) * envelope * 0.25)
        }
        addNoise(&out, at: 0, center: 2_400, q: 1.2, decay: 0.004, amplitude: 0.12)
        return normalized(out, peak: 0.4)
    }

    // MARK: - Odměny

    mutating func reward(_ effect: SoundEffect) -> [Float] {
        switch effect {
        case .milestone:
            return chime([(1318.5, 0)], length: 0.25, decay: 0.08, peak: 0.35)
        case .completion:
            return chime([(784, 0), (1046.5, 0.09)], length: 0.6, decay: 0.16, peak: 0.5)
        case .record:
            return chime([(1046.5, 0), (1318.5, 0.08), (1568, 0.16), (2093, 0.24)], length: 0.8, decay: 0.18, peak: 0.55)
        case .challenge:
            return chime([(659.3, 0), (987.8, 0), (1318.5, 0.12)], length: 0.75, decay: 0.2, peak: 0.5)
        case .achievement:
            return chime([(880, 0), (1108.7, 0.06), (1318.5, 0.12), (1760, 0.18)], length: 0.75, decay: 0.16, peak: 0.5)
        case .levelUp:
            return chime([(523.3, 0), (659.3, 0.1), (784, 0.2), (1046.5, 0.3)], length: 1.0, decay: 0.24, peak: 0.55)
        case .key, .error:
            return []
        }
    }

    /// Zvonkový tón (základ + dvě slabé harmonické) pro každou notu.
    private func chime(_ notes: [(frequency: Double, start: Double)], length: Double, decay: Double, peak: Float) -> [Float] {
        var out = buffer(seconds: length)
        for note in notes {
            addSine(&out, at: note.start, frequency: note.frequency, decay: decay, amplitude: 0.5, attackTime: 0.006)
            addSine(&out, at: note.start, frequency: note.frequency * 2, decay: decay * 0.6, amplitude: 0.12, attackTime: 0.006)
            addSine(&out, at: note.start, frequency: note.frequency * 3, decay: decay * 0.35, amplitude: 0.04, attackTime: 0.006)
        }
        return normalized(out, peak: peak)
    }

    // MARK: - Stavební bloky

    private func buffer(seconds: Double) -> [Float] {
        Array(repeating: 0, count: Int(seconds * sampleRate))
    }

    private func attack(_ t: Double, _ time: Double) -> Double {
        time > 0 ? min(t / time, 1) : 1
    }

    private func addSine(
        _ out: inout [Float],
        at start: Double,
        frequency: Double,
        decay: Double,
        amplitude: Double,
        attackTime: Double = 0.001
    ) {
        let first = Int(start * sampleRate)
        guard first < out.count else { return }
        for i in first..<out.count {
            let t = Double(i - first) / sampleRate
            let envelope = attack(t, attackTime) * exp(-t / decay)
            if envelope < 0.000_1, t > attackTime { break }
            out[i] += Float(sin(2 * .pi * frequency * t) * envelope * amplitude)
        }
    }

    /// Šum prohnaný pásmovou propustí – základ všech „cvaknutí“.
    private mutating func addNoise(
        _ out: inout [Float],
        at start: Double,
        center: Double,
        q: Double,
        decay: Double,
        amplitude: Double
    ) {
        let first = Int(start * sampleRate)
        guard first < out.count else { return }
        var filter = BandPass(center: min(center, sampleRate * 0.45), q: q, sampleRate: sampleRate)
        for i in first..<out.count {
            let t = Double(i - first) / sampleRate
            let envelope = attack(t, 0.0005) * exp(-t / decay)
            if envelope < 0.000_1, t > 0.001 { break }
            let noise = Double.random(in: -1...1, using: &rng)
            out[i] += Float(filter.process(noise) * envelope * amplitude * 2.5)
        }
    }

    private func normalized(_ samples: [Float], peak: Float) -> [Float] {
        let maximum = samples.map(abs).max() ?? 0
        guard maximum > 0 else { return samples }
        let gain = peak / maximum
        // Krátké doznění na konci, aby zvuk neskončil cvaknutím.
        let fade = min(samples.count, Int(sampleRate * 0.004))
        return samples.enumerated().map { index, value in
            let tail = samples.count - index
            let fadeGain: Float = tail < fade ? Float(tail) / Float(fade) : 1
            return value * gain * fadeGain
        }
    }
}

/// Jednoduchý bikvadratický pásmový filtr (RBJ cookbook).
private struct BandPass {
    private let b0, b1, b2, a1, a2: Double
    private var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0

    init(center: Double, q: Double, sampleRate: Double) {
        let w0 = 2 * Double.pi * center / sampleRate
        let alpha = sin(w0) / (2 * q)
        let a0 = 1 + alpha
        b0 = alpha / a0
        b1 = 0
        b2 = -alpha / a0
        a1 = -2 * cos(w0) / a0
        a2 = (1 - alpha) / a0
    }

    mutating func process(_ x: Double) -> Double {
        let y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2 = x1
        x1 = x
        y2 = y1
        y1 = y
        return y
    }
}
