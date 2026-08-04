import WatchKit

/// Haptic + Sound feedback manager for watchOS.
/// Maps training events to appropriate Watch haptic patterns and audio cues.
/// Respects vibration preference synced from iPhone.
class WatchHapticManager {
    static let shared = WatchHapticManager()

    private let vibrationKey = "watch_vibration_enabled"
    private let sound = WatchSoundManager.shared

    var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: vibrationKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: vibrationKey) }
    }

    private init() {}

    private func play(_ type: WKHapticType) {
        guard isEnabled else { return }
        WKInterfaceDevice.current().play(type)
    }

    // MARK: - Training Events

    func playCountdownTick(count: Int) {
        play(.click)
        sound.playCountdown(count)
    }

    func playCountdownFinal() {
        play(.start)
        sound.playCountdown(1, whistleOnLast: true)
    }

    func playTrainingStart(sound type: SoundType) {
        play(.start)
        sound.playSound(type)
    }

    func playSegmentCue(sound type: SoundType) {
        play(.directionUp)
        sound.playSound(type)
    }

    func playRestStart(sound type: SoundType) {
        play(.stop)
        sound.playSound(type)
    }

    func playTrainingComplete(sound type: SoundType) {
        play(.success)
        sound.playSound(type)
    }

    func playPause() { play(.click) }
    func playResume() { play(.start) }

    func playPreWarning(secondsLeft: Int = 3) {
        play(.click)
        sound.playPreWarning(secondsLeft: secondsLeft)
    }
}
