import Foundation

/// Klíče pro `@AppStorage` – uživatelské předvolby (ne progres).
enum SettingsKey {
    static let keyboardLayout = "settings.keyboardLayout"
    static let practiceLanguage = "settings.practiceLanguage"
    static let exerciseLength = "settings.exerciseLength"
    static let showsKeyboard = "settings.showsKeyboard"
    static let showsHands = "settings.showsHands"
    /// Starší přepínač (v2) – převádí se na `TypingStyle.focus`.
    static let focusMode = "settings.focusMode"
    static let previousTypingStyle = "appearance.previousTypingStyle"
    static let soundsEnabled = "settings.soundsEnabled"
    static let errorSoundEnabled = "settings.errorSoundEnabled"
    static let homeDetailsExpanded = "home.detailsExpanded"
    static let lastTimeAttackDuration = "modes.timeAttackDuration"
    static let lastExamDuration = "modes.examDuration"
    static let lastSpeedTestDuration = "modes.speedTestDuration"
    static let customText = "modes.customText"
    static let speedUnit = "settings.speedUnit"
    static let metronomeEnabled = "audio.metronome"
}
