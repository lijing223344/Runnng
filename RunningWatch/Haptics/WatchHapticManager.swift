import WatchKit

/// Haptic feedback manager for watchOS.
/// Maps training events to appropriate Watch haptic patterns.
class WatchHapticManager {
    static let shared = WatchHapticManager()

    private init() {}

    // MARK: - Training Events

    func playCountdownTick() {
        WKInterfaceDevice.current().play(.click)
    }

    func playCountdownFinal() {
        WKInterfaceDevice.current().play(.start)
    }

    func playTrainingStart() {
        WKInterfaceDevice.current().play(.start)
    }

    func playSegmentEnd() {
        WKInterfaceDevice.current().play(.directionUp)
    }

    func playRestStart() {
        WKInterfaceDevice.current().play(.stop)
    }

    func playRepComplete() {
        WKInterfaceDevice.current().play(.directionUp)
    }

    func playTrainingComplete() {
        WKInterfaceDevice.current().play(.success)
    }

    func playPause() {
        WKInterfaceDevice.current().play(.click)
    }

    func playResume() {
        WKInterfaceDevice.current().play(.start)
    }

    func playPreWarning() {
        WKInterfaceDevice.current().play(.click)
    }
}
