import SwiftUI
import HealthKit

/// Interval training view for watchOS.
struct WatchIntervalView: View {
    let plan: SavedPlan
    @Binding var isPresented: Bool

    @State private var training: IntervalTraining?
    @State private var currentGroupIndex = 0
    @State private var currentRep = 0
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
        case resting
        case setRest
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
                .foregroundColor(phaseColor.opacity(0.8))

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
                .tint(WDS.Colors.interval)

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
            case .resting, .setRest:
                Text("watch_resting".localized)
            default:
                Text("")
            }
        }
    }

    private var phaseColor: Color {
        switch phase {
        case .running: return WDS.Colors.interval
        case .resting, .setRest: return WDS.Colors.success
        default: return WDS.Colors.textSecondary
        }
    }

    private func progressInfo(group: IntervalGroup) -> some View {
        VStack(spacing: 2) {
            let totalReps = group.effectiveRepetitions
            Text("\("watch_rep".localized) \(currentRep + 1)/\(totalReps)")
                .font(WDS.Typo.caption)
                .foregroundColor(WDS.Colors.textSecondary)

            if group.effectiveSetCount > 1 {
                Text("\("watch_set".localized) \(currentSet + 1)/\(group.effectiveSetCount)")
                    .font(WDS.Typo.caption)
                    .foregroundColor(WDS.Colors.textTertiary)
            }

            ProgressView(value: repProgress(group: group))
                .tint(phaseColor)
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

    private var currentGroup: IntervalGroup? {
        guard let training, currentGroupIndex < training.groups.count else { return nil }
        return training.groups[currentGroupIndex]
    }

    private func setup() {
        guard let decoded = try? JSONDecoder().decode(IntervalTraining.self, from: plan.configData) else {
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
                startRunningPhase()
            }
        }
    }

    private func startRunningPhase() {
        guard let group = currentGroup else {
            completeTraining()
            return
        }
        phase = .running
        currentRep = 0
        currentSet = 0
        remainingTime = group.runTimeForRep(0)
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

        // Pre-warning
        if remainingTime <= 3 && remainingTime > 0 {
            haptic.playPreWarning()
        }

        if remainingTime <= 0 {
            advancePhase(group: group)
        }
    }

    private func advancePhase(group: IntervalGroup) {
        switch phase {
        case .running:
            // After running, enter rest (unless last rep of last set)
            let isLastRep = (currentRep + 1 >= group.effectiveRepetitions)
            let isLastSet = (currentSet + 1 >= group.effectiveSetCount)

            if isLastRep && isLastSet {
                // Move to next group or complete
                advanceGroup()
            } else if isLastRep {
                // Set rest
                phase = .setRest
                remainingTime = group.effectiveSetRest
                haptic.playRepComplete()
            } else {
                // Regular rest between reps
                phase = .resting
                remainingTime = group.restTimeForRep(currentRep)
                haptic.playRestStart()
            }

        case .resting:
            // After rest, next rep
            currentRep += 1
            phase = .running
            remainingTime = group.runTimeForRep(currentRep)
            haptic.playTrainingStart()

        case .setRest:
            // After set rest, start next set
            currentSet += 1
            currentRep = 0
            phase = .running
            remainingTime = group.runTimeForRep(0)
            haptic.playTrainingStart()

        default:
            break
        }
    }

    private func advanceGroup() {
        let nextGroup = currentGroupIndex + 1
        if let training, nextGroup < training.groups.count {
            currentGroupIndex = nextGroup
            startRunningPhase()
        } else {
            completeTraining()
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
            // Continue without workout session
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
            trainingType: .intervalTraining,
            configId: plan.id,
            configSnapshot: plan.name,
            startTime: Date().addingTimeInterval(-elapsedTotal),
            endTime: Date(),
            completed: completed
        )
        WatchStorageManager.shared.saveRecord(record)
    }

    // MARK: - Helpers

    private func repProgress(group: IntervalGroup) -> Double {
        let total: Double
        if phase == .running {
            total = group.runTimeForRep(currentRep)
        } else {
            total = group.restTimeForRep(currentRep)
        }
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
