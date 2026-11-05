import Foundation
import os

/// Měření latence psaní (jen v Debug buildu).
///
/// - `input` = jak dlouho trvá zpracování stisku na hlavním vlákně (včetně zařazení zvuku)
/// - `audio` = za jak dlouho se zvuk z fronty dostane do přehrávače
/// Souhrn se zapisuje do systémového logu (kategorie „latency“) každých 200 stisků.
final class LatencyProbe: @unchecked Sendable {
    static let shared = LatencyProbe()

    private struct Stats: Sendable {
        var count = 0
        var total: UInt64 = 0
        var maximum: UInt64 = 0

        mutating func add(_ nanoseconds: UInt64) {
            count += 1
            total += nanoseconds
            maximum = max(maximum, nanoseconds)
        }

        var averageMilliseconds: Double { count > 0 ? Double(total) / Double(count) / 1_000_000 : 0 }
        var maximumMilliseconds: Double { Double(maximum) / 1_000_000 }
    }

    private let lock = OSAllocatedUnfairLock(initialState: (input: Stats(), audio: Stats()))
    private let log = Logger(subsystem: "cz.frantisekpetran.Desetiprstka", category: "latency")
    private static let reportEvery = 200

    func recordInput(since start: UInt64) {
        #if DEBUG
        let elapsed = DispatchTime.now().uptimeNanoseconds &- start
        let report = lock.withLock { state -> (Stats, Stats)? in
            state.input.add(elapsed)
            guard state.input.count >= Self.reportEvery else { return nil }
            let snapshot = (state.input, state.audio)
            state = (Stats(), Stats())
            return snapshot
        }
        if let report {
            let (input, audio) = report
            log.info("""
            keys=\(input.count, privacy: .public) \
            input avg=\(input.averageMilliseconds, format: .fixed(precision: 3), privacy: .public)ms \
            max=\(input.maximumMilliseconds, format: .fixed(precision: 3), privacy: .public)ms \
            audio n=\(audio.count, privacy: .public) \
            avg=\(audio.averageMilliseconds, format: .fixed(precision: 3), privacy: .public)ms \
            max=\(audio.maximumMilliseconds, format: .fixed(precision: 3), privacy: .public)ms
            """)
        }
        #endif
    }

    func recordAudioDispatch(since start: UInt64) {
        #if DEBUG
        let elapsed = DispatchTime.now().uptimeNanoseconds &- start
        lock.withLock { $0.audio.add(elapsed) }
        #endif
    }
}
