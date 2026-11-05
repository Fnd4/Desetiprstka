import AVFoundation
import os

/// Nahrané zvuky úhozů přibalené v aplikaci (Resources/Sounds).
///
/// Soubory se jmenují `key-<balíček>-<n>.wav` (např. `key-mechanical-3.wav`),
/// jsou už předem oříznuté a normalizované: 44,1 kHz, mono.
/// Balíček bez souborů použije syntetizované zvuky jako dosud.
enum SampleLibrary {
    private static let log = Logger(subsystem: "cz.frantisekpetran.Desetiprstka", category: "audio")

    /// Varianty úhozu pro balíček, převedené do formátu enginu. Prázdné = žádné nahrávky.
    static func keyVariants(for pack: SoundPack, format: AVAudioFormat) -> [AVAudioPCMBuffer] {
        let prefix = "key-\(pack.rawValue)-"
        return soundURLs()
            .filter { $0.lastPathComponent.hasPrefix(prefix) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            .compactMap { load($0, format: format) }
    }

    private static func soundURLs() -> [URL] {
        // Synchronizovaná složka může skončit v kořeni Resources i v podsložce.
        let flat = Bundle.main.urls(forResourcesWithExtension: "wav", subdirectory: nil) ?? []
        let nested = Bundle.main.urls(forResourcesWithExtension: "wav", subdirectory: "Sounds") ?? []
        return Array(Set(flat + nested))
    }

    private static func load(_ url: URL, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        do {
            let file = try AVAudioFile(forReading: url, commonFormat: .pcmFormatFloat32, interleaved: false)
            let source = file.processingFormat
            let frames = AVAudioFrameCount(file.length)
            guard frames > 0, let raw = AVAudioPCMBuffer(pcmFormat: source, frameCapacity: frames) else { return nil }
            try file.read(into: raw)
            if source.sampleRate == format.sampleRate, source.channelCount == format.channelCount {
                return raw
            }
            return convert(raw, to: format)
        } catch {
            log.error("Zvuk \(url.lastPathComponent, privacy: .public) se nenačetl: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Pojistka pro soubor v jiném formátu (jiná frekvence nebo stereo).
    private static func convert(_ buffer: AVAudioPCMBuffer, to format: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard let converter = AVAudioConverter(from: buffer.format, to: format) else { return nil }
        let ratio = format.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 64
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return nil }
        var consumed = false
        var error: NSError?
        converter.convert(to: output, error: &error) { _, status in
            if consumed {
                status.pointee = .endOfStream
                return nil
            }
            consumed = true
            status.pointee = .haveData
            return buffer
        }
        return error == nil && output.frameLength > 0 ? output : nil
    }
}
