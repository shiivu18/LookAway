import AppKit

public final class SoundManager {
    public static let shared = SoundManager()

    public static let availableSounds: [String] = [
        "Tink", "Glass", "Ping", "Hero", "Purr", "Pop", "Submarine", "Bottle", "Blow"
    ]

    private init() {}

    public func playAlertSound(named name: String? = nil) {
        guard AppSettings.shared.soundEnabled else { return }
        let soundToPlay = name ?? AppSettings.shared.soundName
        if let sound = NSSound(named: soundToPlay) {
            sound.stop()
            sound.play()
        } else {
            // Fallback system beep
            NSSound.beep()
        }
    }

    public func playCompletionSound() {
        guard AppSettings.shared.soundEnabled else { return }
        // Use a gentle sound on completion (Glass or Tink)
        if let sound = NSSound(named: "Glass") ?? NSSound(named: "Tink") {
            sound.stop()
            sound.play()
        } else {
            NSSound.beep()
        }
    }
}
