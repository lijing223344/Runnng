import Foundation

/// Samples elapsed time once, whether the callback comes from the timer, a
/// pause button or a foreground transition. Any time past preparation belongs
/// to the run/rest state machine.
struct TrainingSessionClock {
    nonisolated enum Tick: Equatable {
        case idle, countdown(Int), start(TimeInterval), training(TimeInterval)
    }

    private(set) var sampleDate: Date
    private(set) var countdownRemaining: TimeInterval
    var countdownSeconds: Int { Int(ceil(countdownRemaining)) }

    init(countdown: Int = 3, at date: Date = .now) {
        sampleDate = date
        countdownRemaining = TimeInterval(countdown)
    }

    mutating func advance(to date: Date, paused: Bool) -> Tick {
        let elapsed = date.timeIntervalSince(sampleDate)
        sampleDate = date
        guard !paused, elapsed > 0 else { return .idle }
        guard countdownRemaining > 0 else { return .training(elapsed) }

        let previousSeconds = countdownSeconds
        let remaining = countdownRemaining - elapsed
        countdownRemaining = max(0, remaining)
        if remaining <= 0 { return .start(-remaining) }
        return countdownSeconds == previousSeconds ? .idle : .countdown(countdownSeconds)
    }

    /// Matches the system timer's minute, second and optional hour fields when frozen.
    static func remainingText(_ remaining: TimeInterval) -> String {
        let seconds = max(0, remaining.rounded(.up))
        let pattern: Duration.TimeFormatStyle.Pattern = seconds >= 3_600
            ? .hourMinuteSecond(padHourToLength: 1)
            : .minuteSecond(padMinuteToLength: 1)
        return Duration.seconds(seconds).formatted(.time(pattern: pattern))
    }

    func preparationActivity(kind: String, title: String, accentHex: String,
                             paused: Bool) -> TrainingActivityAttributes.ContentState {
        .init(kindLabel: kind, planTitle: title, phaseLabel: "countdown_start".localized,
              detailLabel: "", stepLabel: "", compactLabel: "",
              remainingText: Self.remainingText(countdownRemaining),
              endDate: paused ? nil : sampleDate.addingTimeInterval(countdownRemaining),
              progress: 0, accentHex: accentHex, isPaused: paused, isComplete: false,
              statusLabel: (paused ? "paused" : "countdown").localized)
    }
}
