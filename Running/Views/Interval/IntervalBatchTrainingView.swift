import SwiftUI

private struct IntervalBatchPlanState {
    var groupStates: [GroupTrainingState]
    var didSaveRecord = false
}

struct IntervalBatchTrainingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var localization = LocalizationManager.shared
    @ObservedObject private var soundManager = SoundManager.shared

    let session: IntervalLaunchSession

    @State private var planStates: [IntervalBatchPlanState] = []
    @State private var isGlobalPaused = false
    @State private var clock = TrainingSessionClock()
    private var countdownSeconds: Int { clock.countdownSeconds }
    private var isCountdown: Bool { clock.countdownRemaining > 0 }
    @State private var timer: Timer?
    @State private var showConfirmStop = false
    @State private var sessionStartedAt: Date?


    private var allCompleted: Bool {
        !planStates.isEmpty && planStates.allSatisfy({ !$0.groupStates.isEmpty && $0.groupStates.allSatisfy(\.isCompleted) }) && !isCountdown
    }

    /// iOS asks the user to allow Live Activities on the app's first request;
    /// if it was declined, offer a way back instead of failing silently.
    private var showsLiveActivityHint: Bool {
        sessionStartedAt != nil && !TrainingLiveActivityManager.shared.isEnabled
    }

    var body: some View {
        TrainingSessionScreen(
            accent: DS.Colors.interval, isPaused: isGlobalPaused, isComplete: allCompleted,
            showsActivityHint: showsLiveActivityHint,
            onPause: toggleGlobalPause, onRestart: restartTraining,
            onStop: { showConfirmStop = true }
        ) {
            if isCountdown {
                countdownOverlay
            } else {
                trainingContent
            }
        }
        .onAppear {
            soundManager.beginTrainingRuntimeSupport()
            initializeStates()
            startCountdown()
        }
        .onDisappear {
            timer?.invalidate()
            soundManager.endTrainingRuntimeSupport()
            TrainingLiveActivityManager.shared.end()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, sessionStartedAt != nil, !allCompleted {
                tick()
                if !allCompleted, let state = liveActivityState() {
                    TrainingLiveActivityManager.shared.begin(trainingID: session.id, state: state)
                }
            }
        }
        .alert("confirm_stop".localized, isPresented: $showConfirmStop) {
            Button("cancel".localized, role: .cancel) {}
            Button("confirm".localized, role: .destructive) { stopTraining() }
        }
    }

    private var countdownOverlay: some View {
        let totalGroups = session.plans.reduce(0) { $0 + $1.training.groups.count }
        let sessionTitle = session.plans.map(\.title).joined(separator: " · ")
        return VStack(spacing: 16) {
            Spacer()
            if !sessionTitle.isEmpty {
                Text(sessionTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, 32)
            }
            Text((isGlobalPaused ? "paused" : "countdown_start").localized)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
                .tracking(2)
                .textCase(.uppercase)
            Text(String(format: "countdown_groups_hint".localized, totalGroups))
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.55))
            Text("\(countdownSeconds)")
                .accessibilityIdentifier("training_preparation_seconds")
                .font(DS.Typo.countdownHero)
                .foregroundStyle(DS.Colors.interval)
                .monospacedDigit()
                .contentTransition(.numericText(countsDown: true))
                .animation(.spring(duration: 0.3), value: countdownSeconds)
            Spacer()
        }
    }

    private var trainingContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                ForEach(Array(session.plans.enumerated()), id: \.element.id) { planIndex, launchPlan in
                    VStack(alignment: .leading, spacing: 10) {
                        if session.plans.count > 1 {
                            compactPlanBadge(for: launchPlan, planIndex: planIndex)
                        }

                        ForEach(Array(launchPlan.training.groups.enumerated()), id: \.element.id) { groupIndex, group in
                            if planIndex < planStates.count, groupIndex < planStates[planIndex].groupStates.count {
                                GroupTrainingCard(
                                    group: group,
                                    state: planStates[planIndex].groupStates[groupIndex],
                                    isSessionPaused: isGlobalPaused,
                                    onPauseToggle: { togglePauseGroup(planIndex: planIndex, groupIndex: groupIndex) }
                                )
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
        }
    }

    private func compactPlanBadge(for launchPlan: IntervalLaunchPlan, planIndex: Int) -> some View {
        let accent = sectionAccent(for: launchPlan)
        return HStack(spacing: 8) {
            Circle()
                .fill(accent.opacity(0.92))
                .frame(width: 8, height: 8)
            Text("PLAN \(planIndex + 1)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.88))
            Spacer()
            Text(planProgressText(for: launchPlan, planIndex: planIndex))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(accent.opacity(0.96))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func sectionAccent(for launchPlan: IntervalLaunchPlan) -> Color {
        Color(hex: launchPlan.training.groups.first?.colorHex ?? "") ?? DS.Colors.interval
    }

    private func initializeStates() {
        timer?.invalidate()
        isGlobalPaused = false
        showConfirmStop = false
        planStates = session.plans.map { launchPlan in
            let groupStates = launchPlan.training.groups.map { group in
                var state = GroupTrainingState()
                state.phase = .running
                state.remainingTime = group.runTimeForRep(0)
                return state
            }
            return IntervalBatchPlanState(groupStates: groupStates)
        }
        sessionStartedAt = nil
    }

    private func startCountdown() {
        let now = Date.now
        clock = TrainingSessionClock(countdown: max(1, session.plans.first?.training.countdownSeconds ?? 3), at: now)
        sessionStartedAt = now
        if let state = liveActivityState() {
            TrainingLiveActivityManager.shared.begin(trainingID: session.id, state: state)
        }
        soundManager.playCountdown(countdownSeconds)
        let mainTimer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { _ in tick() }
        RunLoop.main.add(mainTimer, forMode: .common)
        timer = mainTimer
    }

    private func tick() {
        switch clock.advance(to: .now, paused: isGlobalPaused) {
        case .idle:
            break
        case .countdown(let seconds):
            soundManager.playCountdown(seconds)
        case .start(let elapsed):
            if elapsed < 1 { soundManager.playConfiguredRunStartSound() }
            updateAllPlans(elapsed: elapsed)
        case .training(let elapsed):
            updateAllPlans(elapsed: elapsed)
        }
    }

    private func updateAllPlans(elapsed: TimeInterval) {
        guard !isGlobalPaused else { return }
        // A delayed callback can cross several phases. Skip their expired audio cues.
        let cues = elapsed < 1 ? soundManager : nil
        let epsilon = 0.000_001

        for planIndex in session.plans.indices {
            let training = session.plans[planIndex].training
            for groupIndex in training.groups.indices {
                guard !planStates[planIndex].groupStates[groupIndex].isCompleted && !planStates[planIndex].groupStates[groupIndex].isPaused else { continue }
                let group = training.groups[groupIndex]
                var remainingElapsed = elapsed

                while remainingElapsed > epsilon && !planStates[planIndex].groupStates[groupIndex].isCompleted {

                    let currentRemaining = max(0, planStates[planIndex].groupStates[groupIndex].remainingTime)
                    if currentRemaining > remainingElapsed + epsilon {
                        let previous = currentRemaining
                        let next = currentRemaining - remainingElapsed
                        planStates[planIndex].groupStates[groupIndex].remainingTime = next
                        if planStates[planIndex].groupStates[groupIndex].phase == .resting {
                            cues?.playRestCountdownCues(from: previous, to: next, lead: group.restCountdownLeadSeconds)
                        }
                        remainingElapsed = 0
                    } else {
                        let previous = currentRemaining
                        planStates[planIndex].groupStates[groupIndex].remainingTime = 0
                        if planStates[planIndex].groupStates[groupIndex].phase == .resting {
                            cues?.playRestCountdownCues(from: previous, to: 0, lead: group.restCountdownLeadSeconds)
                        }
                        remainingElapsed -= currentRemaining

                        if planStates[planIndex].groupStates[groupIndex].phase == .running {
                            let totalReps = group.effectiveRepetitions
                            let currentRepIndex = max(0, planStates[planIndex].groupStates[groupIndex].currentRepetition - 1)
                            let restAfter = max(0, group.restTimeForRep(currentRepIndex))

                            if planStates[planIndex].groupStates[groupIndex].currentRepetition < totalReps {
                                if restAfter > epsilon {
                                    planStates[planIndex].groupStates[groupIndex].phase = .resting
                                    planStates[planIndex].groupStates[groupIndex].remainingTime = restAfter
                                    planStates[planIndex].groupStates[groupIndex].isSetRest = false
                                    cues?.playSound(group.restSound)
                                } else {
                                    planStates[planIndex].groupStates[groupIndex].currentRepetition += 1
                                    planStates[planIndex].groupStates[groupIndex].phase = .running
                                    let nextRepIndex = max(0, planStates[planIndex].groupStates[groupIndex].currentRepetition - 1)
                                    planStates[planIndex].groupStates[groupIndex].remainingTime = max(0, group.runTimeForRep(nextRepIndex))
                                    planStates[planIndex].groupStates[groupIndex].isSetRest = false
                                    cues?.playStandardWhistle()
                                }
                            } else {
                                if planStates[planIndex].groupStates[groupIndex].currentSet < group.effectiveSetCount {
                                    let setRest = group.effectiveSetRest
                                    if setRest > epsilon {
                                        planStates[planIndex].groupStates[groupIndex].phase = .resting
                                        planStates[planIndex].groupStates[groupIndex].remainingTime = setRest
                                        planStates[planIndex].groupStates[groupIndex].isSetRest = true
                                        cues?.playSound(group.restSound)
                                    } else {
                                        planStates[planIndex].groupStates[groupIndex].currentSet += 1
                                        planStates[planIndex].groupStates[groupIndex].currentRepetition = 1
                                        planStates[planIndex].groupStates[groupIndex].phase = .running
                                        planStates[planIndex].groupStates[groupIndex].remainingTime = max(0, group.runTimeForRep(0))
                                        planStates[planIndex].groupStates[groupIndex].isSetRest = false
                                        cues?.playStandardWhistle()
                                    }
                                } else {
                                    planStates[planIndex].groupStates[groupIndex].isCompleted = true
                                    planStates[planIndex].groupStates[groupIndex].phase = .completed
                                    cues?.playSound(group.endSound)
                                }
                            }
                        } else if planStates[planIndex].groupStates[groupIndex].phase == .resting {
                            if planStates[planIndex].groupStates[groupIndex].isSetRest {
                                if planStates[planIndex].groupStates[groupIndex].currentSet < group.effectiveSetCount {
                                    planStates[planIndex].groupStates[groupIndex].currentSet += 1
                                    planStates[planIndex].groupStates[groupIndex].currentRepetition = 1
                                    planStates[planIndex].groupStates[groupIndex].phase = .running
                                    planStates[planIndex].groupStates[groupIndex].remainingTime = max(0, group.runTimeForRep(0))
                                    planStates[planIndex].groupStates[groupIndex].isSetRest = false
                                    cues?.playStandardWhistle()
                                } else {
                                    planStates[planIndex].groupStates[groupIndex].isCompleted = true
                                    planStates[planIndex].groupStates[groupIndex].phase = .completed
                                    cues?.playSound(group.endSound)
                                }
                            } else {
                                if planStates[planIndex].groupStates[groupIndex].currentRepetition < group.effectiveRepetitions {
                                    planStates[planIndex].groupStates[groupIndex].currentRepetition += 1
                                    planStates[planIndex].groupStates[groupIndex].phase = .running
                                    let nextRepIndex = max(0, planStates[planIndex].groupStates[groupIndex].currentRepetition - 1)
                                    planStates[planIndex].groupStates[groupIndex].remainingTime = max(0, group.runTimeForRep(nextRepIndex))
                                    cues?.playStandardWhistle()
                                } else {
                                    planStates[planIndex].groupStates[groupIndex].isCompleted = true
                                    planStates[planIndex].groupStates[groupIndex].phase = .completed
                                    cues?.playSound(group.endSound)
                                }
                            }
                        } else {
                            remainingElapsed = 0
                        }
                    }
                }
            }
        }

        if let state = liveActivityState() {
            TrainingLiveActivityManager.shared.update(state)
        }
        if allCompleted {
            timer?.invalidate()
            saveTrainingRecords(completed: true)
            if let final = liveActivityState(isComplete: true) {
                TrainingLiveActivityManager.shared.end(final: final, keepVisibleFor: 90)
            }
        }
    }

    private func togglePauseGroup(planIndex: Int, groupIndex: Int) {
        tick()
        planStates[planIndex].groupStates[groupIndex].isPaused.toggle()
        if let state = liveActivityState() {
            TrainingLiveActivityManager.shared.update(state)
        }
    }

    private func toggleGlobalPause() {
        tick()
        isGlobalPaused.toggle()
        if let state = liveActivityState() {
            TrainingLiveActivityManager.shared.update(state)
        }
    }

    private func stopTraining() {
        timer?.invalidate()
        TrainingLiveActivityManager.shared.end(
            final: liveActivityState(isComplete: allCompleted),
            keepVisibleFor: allCompleted ? 90 : 0
        )
        if sessionStartedAt != nil {
            saveTrainingRecords(completed: false)
        }
        dismiss()
    }

    private func restartTraining() {
        timer?.invalidate()
        TrainingLiveActivityManager.shared.end()
        isGlobalPaused = false
        initializeStates()
        startCountdown()
    }

    private func saveTrainingRecords(completed: Bool) {
        let endAt = Date()
        for index in session.plans.indices where index < planStates.count && !planStates[index].didSaveRecord {
            planStates[index].didSaveRecord = true
            guard let record = try? TrainingRecordFactory.makeRecord(
                for: session.plans[index].training,
                userId: StorageManager.shared.currentUser?.id ?? "",
                sessionStartedAt: sessionStartedAt,
                endAt: endAt,
                completed: completed
            ) else { continue }
            StorageManager.shared.addTrainingRecord(record)
        }
    }

    // MARK: - Live Activity snapshot

    private static func mmss(_ value: Double) -> String {
        let seconds = max(0, Int(value.rounded()))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    /// Locates the first unfinished plan/group across the batch, mirroring the
    /// single-session snapshot used by `IntervalTrainingView`.
    private func activeSnapshotTarget() -> (planIndex: Int, groupIndex: Int)? {
        var paused: (Int, Int)?
        for (planIndex, plan) in planStates.enumerated() {
            for (groupIndex, group) in plan.groupStates.enumerated() where !group.isCompleted {
                if !group.isPaused { return (planIndex, groupIndex) }
                if paused == nil { paused = (planIndex, groupIndex) }
            }
        }
        if let paused { return paused }
        guard let lastPlan = planStates.indices.last,
              let lastGroup = planStates[lastPlan].groupStates.indices.last else { return nil }
        return (lastPlan, lastGroup)
    }

    private func liveActivityState(isComplete: Bool = false) -> TrainingActivityAttributes.ContentState? {
        guard let (planIndex, groupIndex) = activeSnapshotTarget(),
              planIndex < session.plans.count,
              groupIndex < planStates[planIndex].groupStates.count else { return nil }
        let state = planStates[planIndex].groupStates[groupIndex]
        let group = session.plans[planIndex].training.groups[groupIndex]
        if isCountdown, !isComplete {
            return clock.preparationActivity(kind: "interval_training".localized, title: batchSessionTitle,
                                             accentHex: group.colorHex, paused: isGlobalPaused)
        }
        let repetitions = max(1, group.effectiveRepetitions)
        let rep = min(max(state.currentRepetition, 1), repetitions)
        let sets = group.effectiveSetCount
        let set = min(max(state.currentSet, 1), sets)
        let paused = state.isPaused || isGlobalPaused
        let complete = isComplete || state.isCompleted

        let phase: String
        if complete {
            phase = "completed".localized
        } else if state.phase == .resting {
            phase = state.isSetRest ? "set_rest_label".localized : "resting".localized
        } else {
            phase = String(format: "live_interval_phase".localized, set, rep, repetitions)
        }

        let detail: String
        if complete {
            detail = String(format: "live_total_format".localized, group.runDistance * repetitions * sets)
        } else if state.phase == .resting {
            let plannedRest = state.isSetRest
                ? group.effectiveSetRest
                : group.restTimeForRep(max(0, rep - 1))
            detail = String(format: "live_rest_format".localized, Self.mmss(plannedRest))
        } else {
            detail = String(format: "live_interval_detail".localized, group.runDistance, Self.mmss(group.runTimeForRep(rep - 1)))
        }

        let step = "\(rep) / \(repetitions)"
        let status: String
        if complete { status = "completed".localized }
        else if paused { status = "paused".localized }
        else if state.phase == .resting { status = "resting".localized }
        else { status = "running".localized }

        let endDate: Date? = (paused || complete) ? nil : clock.sampleDate.addingTimeInterval(max(0, state.remainingTime))

        return .init(
            kindLabel: "interval_training".localized,
            planTitle: batchSessionTitle,
            phaseLabel: phase,
            detailLabel: detail,
            stepLabel: step,
            compactLabel: "\(rep)/\(repetitions)",
            remainingText: TrainingSessionClock.remainingText(state.remainingTime),
            endDate: endDate,
            progress: overallProgress,
            accentHex: group.colorHex,
            isPaused: paused,
            isComplete: complete,
            statusLabel: status
        )
    }

    private var batchSessionTitle: String {
        let titles = session.plans.map(\.title).filter { !$0.isEmpty }
        if titles.isEmpty { return "interval_training".localized }
        return titles.joined(separator: " · ")
    }

    private var overallProgress: Double {
        var total = 0
        var done = 0.0
        for (plan, state) in zip(session.plans, planStates) {
            for (group, groupState) in zip(plan.training.groups, state.groupStates) {
                total += group.effectiveRepetitions * group.effectiveSetCount
                done += groupState.completedSteps(in: group)
            }
        }
        return done / Double(max(1, total))
    }

    private func completedGroupCount(for planIndex: Int) -> Int {
        guard planIndex < planStates.count else { return 0 }
        return planStates[planIndex].groupStates.filter(\.isCompleted).count
    }

    private func planProgressText(for launchPlan: IntervalLaunchPlan, planIndex: Int) -> String {
        let total = launchPlan.training.groups.count
        let completed = completedGroupCount(for: planIndex)
        if total > 0 && completed == total {
            return "completed".localized
        }
        return "\(completed)/\(total)"
    }
}
