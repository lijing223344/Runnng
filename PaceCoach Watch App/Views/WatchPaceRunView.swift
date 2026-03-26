import SwiftUI
import HealthKit

/// Pace Run training view for watchOS.
/// Runs a single group at a time with haptic feedback.
struct WatchPaceRunView: View {
    let plan: SavedPlan
    @Binding var isPresented: Bool

    @State private var training: PaceRunTraining?
    @State private var currentGroupIndex = 0
    @State private var currentSegment = 0
    @State private var currentSet = 0
    @State private var remainingTime: Double = 0
    @State private var phase: TrainingPhase = .countdown
    @State private var countdownValue = 3
    @State private var isPaused = false
    @State private var isCompleted = false
    @State private var showStopAlert = false
    @State private var elapsedTotal: Double = 0

    @State private var timer: Timer?
    @State private var workoutSession: HKWorkoutSession?
    @State private var workoutBuilder: HKLiveWorkoutBuilder?

    private let haptic = WatchHapticManager.shared
    private let healthStore = HKHealthStore()

    enum TrainingPhase {
        case countdown
        case running
        case segmentRest   // rest between segments (custom mode)
        case setRest       // rest between sets
        case completed
    }

    var body: some View {
        ZStack {
            WDS.Colors.bg.ignoresSafeArea()

            if isCompleted {
                completedView
            } else if phase == .countdown {
                countdownView
            } else {
                trainingView
            }
        }
        .alert("watch_stop_confirm".localized, isPresented: $showStopAlert) {
            Button("watch_stop".localized, role: .destructive) { stopTraining() }
            Button("watch_cancel".localized, role: .cancel) {}
        }
        .onAppear { setup() }
        .onDisappear { cleanup() }
    }

    // MARK: - Countdown

    private var countdownView: some View {
        VStack {
            Spacer()
            Text("\(countdownValue)")
                .font(WDS.Typo.countdownHero)
                .foregroundColor(WDS.Colors.textPrimary)
                .contentTransition(.numericText())
            Spacer()
        }
    }

    // MARK: - Training

    private var trainingView: some View {
        VStack(spacing: WDS.Space.md) {
            // Phase label
            phaseLabel
                .font(WDS.Typo.caption)
                .foregroundColor(currentAccent.opacity(0.8))

            // Timer
            Text(formatTime(remainingTime))
                .font(WDS.Typo.timerLarge)
                .foregroundColor(WDS.Colors.textPrimary)
                .monospacedDigit()

            // Progress
            if let group = currentGroup {
                progressInfo(group: group)
            }

            Spacer()

            // Controls
            HStack(spacing: WDS.Space.lg) {
                Button {
                    togglePause()
                } label: {
                    Image(systemName: isPaused ? "play.fill" : "pause.fill")
                        .font(.title3)
                }
                .tint(currentAccent)

                Button {
                    showStopAlert = true
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.title3)
                }
                .tint(WDS.Colors.error)
            }
        }
        .padding(.horizontal, WDS.Space.md)
    }

    private var phaseLabel: some View {
        Group {
            switch phase {
            case .running:
                Text("watch_running".localized)
            case .segmentRest, .setRest:
                Text("watch_resting".localized)
            default:
                Text("")
            }
        }
    }

    private func progressInfo(group: PaceRunGroup) -> some View {
        VStack(spacing: 2) {
            // Segment progress
            let total = group.segmentCount
            Text("\("watch_segment".localized) \(currentSegment + 1)/\(total)")
                .font(WDS.Typo.caption)
                .foregroundColor(WDS.Colors.textSecondary)

            // Set progress (if multi-set)
            if group.effectiveSetCount > 1 {
                Text("\("watch_set".localized) \(currentSet + 1)/\(group.effectiveSetCount)")
                    .font(WDS.Typo.caption)
                    .foregroundColor(WDS.Colors.textTertiary)
            }

            // Progress bar
            let segProgress = segmentProgress(group: group)
            ProgressView(value: segProgress)
                .tint(currentAccent)
                .padding(.horizontal)
        }
    }

    // MARK: - Completed

    private var completedView: some View {
        VStack(spacing: WDS.Space.lg) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(WDS.Colors.success)

            Text("watch_training_complete".localized)
                .font(WDS.Typo.timerMedium)
                .foregroundColor(WDS.Colors.textPrimary)

            Text(formatTime(elapsedTotal))
                .font(WDS.Typo.timerSmall)
                .foregroundColor(WDS.Colors.textSecondary)

            Button("watch_done".localized) {
                isPresented = false
            }
            .tint(WDS.Colors.success)
        }
    }

    // MARK: - Logic

    private var currentGroup: PaceRunGroup? {
        guard let training, currentGroupIndex < training.groups.count else { return nil }
        return training.groups[currentGroupIndex]
    }

    private var currentAccent: Color { WDS.Colors.paceRun }

    private func setup() {
        guard let decoded = try? JSONDecoder().decode(PaceRunTraining.self, from: plan.configData) else {
            isPresented = false
            return
        }
        training = decoded
        countdownValue = decoded.countdownSeconds
        startCountdown()
        startWorkoutSession()
    }

    private func startCountdown() {
        phase = .countdown
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if countdownValue > 1 {
                countdownValue -= 1
                if countdownValue <= 3 {
                    haptic.playCountdownTick()
                }
            } else {
                haptic.playCountdownFinal()
                timer?.invalidate()
                startRunning()
            }
        }
    }

    private func startRunning() {
        guard let group = currentGroup else {
            completeTraining()
            return
        }
        phase = .running
        currentSegment = 0
        currentSet = 0
        remainingTime = group.timeForSegment(0)
        haptic.playTrainingStart()
        startTrainingTimer()
    }

    private func startTrainingTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            guard !isPaused else { return }
            tick()
        }
    }

    private func tick() {
        guard let group = currentGroup else { return }

        elapsedTotal += 1.0
        remainingTime -= 1.0

        // Pre-warning at 3, 2, 1 seconds
        if remainingTime <= 3 && remainingTime > 0 {
            haptic.playPreWarning()
        }

        if remainingTime <= 0 {
            advancePhase(group: group)
        }
    }

    private func advancePhase(group: PaceRunGroup) {
        switch phase {
        case .running:
            // Check segment rest (custom mode)
            let restAfter = group.restAfterSegment(currentSegment)
            if restAfter > 0 && currentSegment < group.segmentCount - 1 {
                phase = .segmentRest
                remainingTime = restAfter
                haptic.playSegmentEnd()
                return
            }
            advanceSegment(group: group)

        case .segmentRest:
            advanceSegment(group: group)

        case .setRest:
            currentSet += 1
            currentSegment = 0
            phase = .running
            remainingTime = group.timeForSegment(0)
            haptic.playTrainingStart()

        default:
            break
        }
    }

    private func advanceSegment(group: PaceRunGroup) {
        let nextSegment = currentSegment + 1

        if nextSegment >= group.segmentCount {
            // Set complete
            if currentSet + 1 < group.effectiveSetCount {
                phase = .setRest
                remainingTime = group.effectiveSetRest
                haptic.playRepComplete()
            } else {
                // Move to next group or complete
                let nextGroup = currentGroupIndex + 1
                if let training, nextGroup < training.groups.count {
                    currentGroupIndex = nextGroup
                    startRunning()
                } else {
                    completeTraining()
                }
            }
        } else {
            currentSegment = nextSegment
            phase = .running
            remainingTime = group.timeForSegment(nextSegment)
            haptic.playSegmentEnd()
        }
    }

    private func togglePause() {
        isPaused.toggle()
        if isPaused {
            haptic.playPause()
        } else {
            haptic.playResume()
        }
    }

    private func stopTraining() {
        saveRecord(completed: false)
        cleanup()
        isPresented = false
    }

    private func completeTraining() {
        phase = .completed
        isCompleted = true
        timer?.invalidate()
        haptic.playTrainingComplete()
        saveRecord(completed: true)
        endWorkoutSession()
    }

    private func cleanup() {
        timer?.invalidate()
        timer = nil
        endWorkoutSession()
    }

    // MARK: - Workout Session

    private func startWorkoutSession() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let config = HKWorkoutConfiguration()
        config.activityType = .running
        config.locationType = .outdoor

        do {
            workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: config)
            workoutBuilder = workoutSession?.associatedWorkoutBuilder()
            workoutBuilder?.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: config)
            workoutSession?.startActivity(with: Date())
            workoutBuilder?.beginCollection(withStart: Date()) { _, _ in }
        } catch {
            // Workout session not available — continue without it
        }
    }

    private func endWorkoutSession() {
        workoutSession?.end()
        workoutBuilder?.endCollection(withEnd: Date()) { _, _ in
            self.workoutBuilder?.finishWorkout { _, _ in }
        }
    }

    // MARK: - Record

    private func saveRecord(completed: Bool) {
        let record = TrainingRecord(
            trainingType: .paceRun,
            configId: plan.id,
            configSnapshot: plan.name,
            startTime: Date().addingTimeInterval(-elapsedTotal),
            endTime: Date(),
            completed: completed
        )
        WatchStorageManager.shared.saveRecord(record)
    }

    // MARK: - Helpers

    private func segmentProgress(group: PaceRunGroup) -> Double {
        let total = group.timeForSegment(currentSegment)
        guard total > 0 else { return 0 }
        return max(0, min(1, 1.0 - remainingTime / total))
    }

    private func formatTime(_ seconds: Double) -> String {
        let s = max(0, Int(seconds))
        let m = s / 60
        let sec = s % 60
        return String(format: "%d:%02d", m, sec)
    }
}
