import Foundation

/// Nastavení zvuku – ukládá se do UserDefaults (sdílené s `@AppStorage` v Nastavení).
struct AudioSettings: Equatable, Sendable {
    var typingEnabled: Bool
    var pack: SoundPack
    var typingVolume: Float
    var errorEnabled: Bool
    var rewardsEnabled: Bool
    var rewardVolume: Float

    enum Key {
        static let typingEnabled = "audio.typingEnabled"
        static let pack = "audio.typingPack"
        static let typingVolume = "audio.typingVolume"
        static let errorEnabled = SettingsKey.errorSoundEnabled
        /// Stejný klíč jako původní „Jemné zvukové efekty“ – starší nastavení zůstane.
        static let rewardsEnabled = SettingsKey.soundsEnabled
        static let rewardVolume = "audio.rewardVolume"
    }

    static let defaultTypingVolume = 0.45
    static let defaultRewardVolume = 0.6

    static func load(from defaults: UserDefaults = .standard) -> AudioSettings {
        AudioSettings(
            typingEnabled: defaults.bool(forKey: Key.typingEnabled),
            pack: SoundPack(rawValue: defaults.string(forKey: Key.pack) ?? "") ?? .soft,
            typingVolume: Float(defaults.object(forKey: Key.typingVolume) as? Double ?? defaultTypingVolume),
            errorEnabled: defaults.bool(forKey: Key.errorEnabled),
            rewardsEnabled: defaults.bool(forKey: Key.rewardsEnabled),
            rewardVolume: Float(defaults.object(forKey: Key.rewardVolume) as? Double ?? defaultRewardVolume)
        )
    }
}
