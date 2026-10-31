import SwiftUI
import HealthKit

/// Interval training view for watchOS.
struct WatchIntervalView: View {
    @Environment(\.scenePhase) private var scenePhase
    let plan: SavedPlan
    @Binding var isPresented: Bool

    @State private var training: IntervalTraining?
    @State private var hasInitialized = false
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
    @State private var workoutEnded = false
    @State private var lastTickUptime: TimeInterval = 0

    @State private var timer: Timer?
    @State private var workoutSession: HKWorkoutSession?
    @State private var workoutBuilder: HKLiveWorkoutBuilder?

    private let haptic = WatchHapticManager.shared
    private let healthStore = HKHealthStore()
    private let trainingTickInterval: TimeInterval = 0.1
    private let maxStateTransitionsPerTick = 128

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
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                handleSceneDidBecomeActive()
            }
        }
        .onDisappear {
            if isCompleted || !isPresented {
                cleanup()
            }
        }
    }

    // MARK: - Countdown

    private var countdownView: some View {
        VStack {
            Spacer()
            // Audit W3: plan context + domain-accent number on the countdown.
            Text(plan.name.isEmpty ? "interval_training".localized : plan.name)
                .font(WDS.Typo.cardTitle)
                .foregroundColor(WDS.Colors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, WDS.Space.xl)
            Text("\(countdownValue)")
                .font(WDS.Typo.countdownHero)
                .foregroundColor(WDS.Colors.interval)
                .contentTransition(.numericText(countsDown: true))
                .monospacedDigit()
                .animation(.easeOut(duration: 0.18), value: countdownValue)
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
                // Audit W2: pause/resume is amber across iPhone and watch.
                .tint(WDS.Colors.warning)

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
        // Audit W1: rest uses the cool rest token, not success green —
        // green stays reserved for the completed state.
        case .resting, .setRest: return WDS.Colors.rest
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
        guard !hasInitialized else { return }
        guard let decoded = try? JSONDecoder().decode(IntervalTraining.self, from: plan.configData) else {
            isPresented = false
            return
        }
        hasInitialized = true
        workoutEnded = false
        training = decoded
        countdownValue = max(1, decoded.countdownSeconds)
        startCountdown()
        startWorkoutSession()
    }

    private func startCountdown() {
        phase = .countdown
        timer?.invalidate()
        haptic.playCountdownTick(count: countdownValue)
        let countdownTimer = Timer(timeInterval: 1.0, repeats: true) { _ in
            guard !isPaused else { return }
            if countdownValue > 1 {
                countdownValue -= 1
                haptic.playCountdownTick(count: countdownValue)
            } else {
                timer?.invalidate()
                timer = nil
                startRunningPhase()
            }
        }
        countdownTimer.tolerance = 0.05
        RunLoop.main.add(countdownTimer, forMode: .common)
        timer = countdownTimer
    }

    private func startRunningPhase(startTimer: Bool = true) {
        guard let group = currentGroup else {
            completeTraining()
            return
        }
        phase = .running
        currentRep = 0
        currentSet = 0
        remainingTime = group.runTimeForRep(0)
        haptic.playTrainingStart(sound: group.startSound)
        if startTimer {
            startTrainingTimer()
        }
    }

    private func handleSceneDidBecomeActive() {
        guard phase != .countdown, phase != .completed, !isPaused else { return }
        let now = ProcessInfo.processInfo.systemUptime
        guard lastTickUptime > 0 else {
            lastTickUptime = now
            return
        }
        let elapsed = max(0, now - lastTickUptime)
        lastTickUptime = now
        tick(elapsed: elapsed)
    }

    private func startTrainingTimer() {
        timer?.invalidate()
        lastTickUptime = ProcessInfo.processInfo.systemUptime
        let trainingTimer = Timer(timeInterval: trainingTickInterval, repeats: true) { _ in
            guard !isPaused else { return }
            let now = ProcessInfo.processInfo.systemUptime
            let elapsed = max(0, now - lastTickUptime)
            lastTickUptime = now
            tick(elapsed: elapsed)
        }
        trainingTimer.tolerance = trainingTickInterval * 0.5
        RunLoop.main.add(trainingTimer, forMode: .common)
        timer = trainingTimer
    }

    private func tick(elapsed: TimeInterval) {
        guard elapsed > 0 else { return }

        let epsilon = 0.000_001
        elapsedTotal += elapsed
        var remainingElapsed = elapsed
        var transitions = 0

        while remainingElapsed > epsilon {
            guard let group = currentGroup else { return }
            transitions += 1
            if transitions > maxStateTransitionsPerTick {
                completeTraining(sound: group.endSound)
                return
            }

            let currentRemaining = max(0, remainingTime)
            if currentRemaining > remainingElapsed + epsilon {
                let previous = currentRemaining
                let next = currentRemaining - remainingElapsed
                remainingTime = next
                playRestCountdownCuesIfNeeded(group: group, from: previous, to: next)
                remainingElapsed = 0
            } else {
                let previous = currentRemaining
                remainingTime = 0
                playRestCountdownCuesIfNeeded(group: group, from: previous, to: 0)
                remainingElapsed -= currentRemaining
                advancePhase(group: group)
                if phase == .completed {
                    return
                }
            }
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
                advanceGroup(from: group)
            } else if isLastRep {
                // Set rest
                phase = .setRest
                remainingTime = group.effectiveSetRest
                haptic.playRestStart(sound: group.restSound)
            } else {
                // Regular rest between reps
                phase = .resting
                remainingTime = group.restTimeForRep(currentRep)
                haptic.playRestStart(sound: group.restSound)
            }

        case .resting:
            // After rest, next rep
            currentRep += 1
            phase = .running
            remainingTime = group.runTimeForRep(currentRep)
            haptic.playTrainingStart(sound: group.startSound)

        case .setRest:
            // After set rest, start next set
            currentSet += 1
            currentRep = 0
            phase = .running
            remainingTime = group.runTimeForRep(0)
            haptic.playTrainingStart(sound: group.startSound)

        default:
            break
        }
    }

    private func advanceGroup(from group: IntervalGroup) {
        let nextGroup = currentGroupIndex + 1
        if let training, nextGroup < training.groups.count {
            currentGroupIndex = nextGroup
            startRunningPhase(startTimer: false)
        } else {
            completeTraining(sound: group.endSound)
        }
    }

    private func togglePause() {
        isPaused.toggle()
        if isPaused {
            haptic.playPause()
            workoutSession?.pause()
        } else {
            haptic.playResume()
            workoutSession?.resume()
            lastTickUptime = ProcessInfo.processInfo.systemUptime
        }
    }

    private func stopTraining() {
        saveRecord(completed: false)
        cleanup()
        isPresented = false
    }

    private func completeTraining(sound: SoundType = .whistleStandard) {
        phase = .completed
        isCompleted = true
        timer?.invalidate()
        haptic.playTrainingComplete(sound: sound)
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
        guard !workoutEnded else { return }
        workoutEnded = true
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
        } else if phase == .setRest {
            total = group.effectiveSetRest
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

    private func playRestCountdownCuesIfNeeded(group: IntervalGroup, from previous: Double, to current: Double) {
        guard phase == .resting || phase == .setRest else { return }
        let lead = group.restCountdownLeadSeconds
        let upper = Int(floor(previous))
        let lower = Int(floor(current))
        guard lower < upper else { return }

        for sec in stride(from: upper, to: lower, by: -1) where sec <= lead && sec >= 1 {
            haptic.playPreWarning(secondsLeft: sec)
        }
    }
}
