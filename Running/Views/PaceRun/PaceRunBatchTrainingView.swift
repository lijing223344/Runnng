import SwiftUI

private struct PaceRunBatchPlanState {
    var groupStates: [PaceRunGroupState]
    var didSaveRecord = false
}

struct PaceRunBatchTrainingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var localization = LocalizationManager.shared
    @ObservedObject private var soundManager = SoundManager.shared

    let session: PaceRunLaunchSession

    @State private var planStates: [PaceRunBatchPlanState] = []
    @State private var isGlobalPaused = false
    @State private var countdownSeconds = 3
    @State private var isCountdown = true
    @State private var timer: Timer?
    @State private var lastTickDate: Date?
    @State private var showConfirmStop = false
    @State private var sessionStartedAt: Date?

    private let maxTickElapsed: TimeInterval = 0.25
    private let maxStateTransitionsPerTick = 512

    private var allCompleted: Bool {
        !planStates.isEmpty && planStates.allSatisfy { !$0.groupStates.isEmpty && $0.groupStates.allSatisfy(\.isCompleted) } && !isCountdown
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if isCountdown {
                countdownOverlay
            } else {
                trainingContent
            }

            VStack {
                Spacer()
                bottomControls
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
            switch phase {
            case .active:
                resumeTimingIfNeeded()
            case .background, .inactive:
                // Leaving the foreground ends the island immediately: a card
                // must not keep showing a session that is no longer running.
                TrainingLiveActivityManager.shared.endAllImmediately()
                suspendTiming()
            @unknown default:
                break
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
            Text("countdown_start".localized)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
                .tracking(2)
                .textCase(.uppercase)
            Text(String(format: "countdown_groups_hint".localized, totalGroups))
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.55))
            Text("\(countdownSeconds)")
                .font(DS.Typo.countdownHero)
                .foregroundStyle(DS.Colors.paceRun)
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
                                PaceRunGroupTrainingCard(
                                    group: group,
                                    state: planStates[planIndex].groupStates[groupIndex],
                                    onPauseToggle: { togglePauseGroup(planIndex: planIndex, groupIndex: groupIndex) }
                                )
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 120)
        }
    }

    private func compactPlanBadge(for launchPlan: PaceRunLaunchPlan, planIndex: Int) -> some View {
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

    private func sectionAccent(for launchPlan: PaceRunLaunchPlan) -> Color {
        Color(hex: launchPlan.training.groups.first?.colorHex ?? "") ?? DS.Colors.paceRun
    }

    private var bottomControls: some View {
        let primaryHighlighted = allCompleted || isGlobalPaused
        return HStack(spacing: 12) {
            Button(action: allCompleted ? restartTraining : toggleGlobalPause) {
                HStack(spacing: 8) {
                    Image(systemName: allCompleted ? "arrow.clockwise" : (isGlobalPaused ? "play.fill" : "pause.fill"))
                        .font(.system(size: 16, weight: .semibold))
                    Text(allCompleted ? "restart_training".localized : (isGlobalPaused ? "resume".localized : "pause".localized))
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(primaryHighlighted ? Color.white : DS.Colors.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .trainingControlSurface(highlighted: primaryHighlighted, accent: DS.Colors.paceRun)
            }

            Button(action: { showConfirmStop = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text("stop".localized)
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(DS.Colors.error)
                .frame(width: 110)
                .frame(height: 56)
                .trainingStopSurface()
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 32)
        .padding(.top, 12)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0), Color.black],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.4)
            )
            .ignoresSafeArea()
        )
    }

    private func initializeStates() {
        timer?.invalidate()
        isCountdown = true
        isGlobalPaused = false
        showConfirmStop = false
        planStates = session.plans.map { launchPlan in
            let groupStates = launchPlan.training.groups.map { group in
                var state = PaceRunGroupState()
                state.remainingTime = group.timeForSegment(0)
                return state
            }
            return PaceRunBatchPlanState(groupStates: groupStates)
        }
        countdownSeconds = max(1, session.plans.first?.training.countdownSeconds ?? 3)
        sessionStartedAt = nil
        lastTickDate = nil
    }

    private func startCountdown() {
        isCountdown = true
        countdownSeconds = max(1, session.plans.first?.training.countdownSeconds ?? 3)
        sessionStartedAt = Date()
        soundManager.playCountdown(countdownSeconds)
        let countdownTimer = Timer(timeInterval: 1, repeats: true) { _ in
            if self.countdownSeconds > 1 {
                self.countdownSeconds -= 1
                self.soundManager.playCountdown(self.countdownSeconds)
            } else {
                self.timer?.invalidate()
                self.isCountdown = false
                self.soundManager.playConfiguredRunStartSound()
                self.startAllPlans()
            }
        }
        RunLoop.main.add(countdownTimer, forMode: .common)
        timer = countdownTimer
    }

    private func startAllPlans() {
        for planIndex in session.plans.indices {
            for groupIndex in session.plans[planIndex].training.groups.indices {
                planStates[planIndex].groupStates[groupIndex].phase = .running
                planStates[planIndex].groupStates[groupIndex].currentSegment = 1
                planStates[planIndex].groupStates[groupIndex].currentSet = 1
                planStates[planIndex].groupStates[groupIndex].remainingTime = session.plans[planIndex].training.groups[groupIndex].timeForSegment(0)
                planStates[planIndex].groupStates[groupIndex].isCompleted = false
                planStates[planIndex].groupStates[groupIndex].restKind = nil
            }
        }
        if let state = liveActivityState() {
            TrainingLiveActivityManager.shared.begin(trainingID: session.id, state: state)
        }
        startTimer()
    }

    private func startTimer() {
        lastTickDate = Date()
        let mainTimer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { _ in
            let now = Date()
            let rawElapsed = max(0, now.timeIntervalSince(lastTickDate ?? now))
            lastTickDate = now
            let elapsed = min(rawElapsed, self.maxTickElapsed)
            self.updateAllPlans(elapsed: elapsed)
        }
        RunLoop.main.add(mainTimer, forMode: .common)
        timer = mainTimer
    }

    private func suspendTiming() {
        lastTickDate = nil
    }

    private func resumeTimingIfNeeded() {
        guard !isCountdown, !isGlobalPaused, !allCompleted else {
            lastTickDate = Date()
            return
        }
        let now = Date()
        if let last = lastTickDate {
            let gap = max(0, now.timeIntervalSince(last))
            if gap > 0 {
                updateAllPlans(elapsed: gap)
            }
        }
        lastTickDate = now
    }

    private func updateAllPlans(elapsed: TimeInterval) {
        guard !isGlobalPaused else { return }
        guard elapsed > 0 else { return }
        let epsilon = 0.000_001

        for planIndex in session.plans.indices {
            let training = session.plans[planIndex].training
            for groupIndex in training.groups.indices {
                guard !planStates[planIndex].groupStates[groupIndex].isCompleted && !planStates[planIndex].groupStates[groupIndex].isPaused else { continue }
                let group = training.groups[groupIndex]
                var remainingElapsed = elapsed
                var transitions = 0

                while remainingElapsed > epsilon && !planStates[planIndex].groupStates[groupIndex].isCompleted {
                    transitions += 1
                    if transitions > maxStateTransitionsPerTick {
                        planStates[planIndex].groupStates[groupIndex].isCompleted = true
                        planStates[planIndex].groupStates[groupIndex].phase = .completed
                        planStates[planIndex].groupStates[groupIndex].remainingTime = 0
                        planStates[planIndex].groupStates[groupIndex].restKind = nil
                        soundManager.playSound(group.endSound)
                        break
                    }

                    let currentRemaining = max(0, planStates[planIndex].groupStates[groupIndex].remainingTime)
                    if currentRemaining > remainingElapsed + epsilon {
                        let previous = currentRemaining
                        let next = currentRemaining - remainingElapsed
                        planStates[planIndex].groupStates[groupIndex].remainingTime = next
                        if planStates[planIndex].groupStates[groupIndex].phase == .resting {
                            playRestCountdownCues(from: previous, to: next, lead: max(1, group.countdownSeconds))
                        }
                        remainingElapsed = 0
                    } else {
                        let previous = currentRemaining
                        remainingElapsed -= currentRemaining
                        planStates[planIndex].groupStates[groupIndex].remainingTime = 0
                        if planStates[planIndex].groupStates[groupIndex].phase == .resting {
                            playRestCountdownCues(from: previous, to: 0, lead: max(1, group.countdownSeconds))
                        }

                        if planStates[planIndex].groupStates[groupIndex].phase == .running {
                            if planStates[planIndex].groupStates[groupIndex].currentSegment < group.segmentCount {
                                let finishedIndex = max(0, planStates[planIndex].groupStates[groupIndex].currentSegment - 1)
                                let restAfter = max(0, group.restAfterSegment(finishedIndex))
                                if restAfter > epsilon {
                                    soundManager.playSegmentShortWhistle()
                                    planStates[planIndex].groupStates[groupIndex].phase = .resting
                                    planStates[planIndex].groupStates[groupIndex].remainingTime = restAfter
                                    planStates[planIndex].groupStates[groupIndex].restKind = .segment
                                } else {
                                    soundManager.playSegmentShortWhistle()
                                    planStates[planIndex].groupStates[groupIndex].currentSegment += 1
                                    let nextSegIndex = max(0, planStates[planIndex].groupStates[groupIndex].currentSegment - 1)
                                    planStates[planIndex].groupStates[groupIndex].remainingTime = max(0, group.timeForSegment(nextSegIndex))
                                    planStates[planIndex].groupStates[groupIndex].phase = .running
                                    planStates[planIndex].groupStates[groupIndex].restKind = nil
                                }
                            } else {
                                if planStates[planIndex].groupStates[groupIndex].currentSet < group.effectiveSetCount {
                                    let setRest = group.effectiveSetRest
                                    if setRest > epsilon {
                                        soundManager.playSegmentShortWhistle()
                                        planStates[planIndex].groupStates[groupIndex].phase = .resting
                                        planStates[planIndex].groupStates[groupIndex].remainingTime = setRest
                                        planStates[planIndex].groupStates[groupIndex].restKind = .set
                                    } else {
                                        planStates[planIndex].groupStates[groupIndex].currentSet += 1
                                        planStates[planIndex].groupStates[groupIndex].currentSegment = 1
                                        planStates[planIndex].groupStates[groupIndex].phase = .running
                                        planStates[planIndex].groupStates[groupIndex].remainingTime = max(0, group.timeForSegment(0))
                                        planStates[planIndex].groupStates[groupIndex].restKind = nil
                                        soundManager.playStandardWhistle()
                                    }
                                } else {
                                    planStates[planIndex].groupStates[groupIndex].isCompleted = true
                                    planStates[planIndex].groupStates[groupIndex].phase = .completed
                                    planStates[planIndex].groupStates[groupIndex].restKind = nil
                                    soundManager.playSound(group.endSound)
                                }
                            }
                        } else if planStates[planIndex].groupStates[groupIndex].phase == .resting {
                            if planStates[planIndex].groupStates[groupIndex].restKind == .set {
                                if planStates[planIndex].groupStates[groupIndex].currentSet < group.effectiveSetCount {
                                    planStates[planIndex].groupStates[groupIndex].currentSet += 1
                                    planStates[planIndex].groupStates[groupIndex].currentSegment = 1
                                    planStates[planIndex].groupStates[groupIndex].remainingTime = max(0, group.timeForSegment(0))
                                    planStates[planIndex].groupStates[groupIndex].phase = .running
                                    planStates[planIndex].groupStates[groupIndex].restKind = nil
                                    soundManager.playStandardWhistle()
                                } else {
                                    planStates[planIndex].groupStates[groupIndex].isCompleted = true
                                    planStates[planIndex].groupStates[groupIndex].phase = .completed
                                    planStates[planIndex].groupStates[groupIndex].restKind = nil
                                    soundManager.playSound(group.endSound)
                                }
                            } else if planStates[planIndex].groupStates[groupIndex].currentSegment < group.segmentCount {
                                planStates[planIndex].groupStates[groupIndex].currentSegment += 1
                                let nextSegIndex = max(0, planStates[planIndex].groupStates[groupIndex].currentSegment - 1)
                                planStates[planIndex].groupStates[groupIndex].remainingTime = max(0, group.timeForSegment(nextSegIndex))
                                planStates[planIndex].groupStates[groupIndex].phase = .running
                                planStates[planIndex].groupStates[groupIndex].restKind = nil
                                soundManager.playSegmentShortWhistle()
                            } else {
                                planStates[planIndex].groupStates[groupIndex].isCompleted = true
                                planStates[planIndex].groupStates[groupIndex].phase = .completed
                                planStates[planIndex].groupStates[groupIndex].restKind = nil
                                soundManager.playSound(group.endSound)
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
        planStates[planIndex].groupStates[groupIndex].isPaused.toggle()
        lastTickDate = Date()
        if let state = liveActivityState() {
            TrainingLiveActivityManager.shared.update(state)
        }
    }

    private func toggleGlobalPause() {
        isGlobalPaused.toggle()
        lastTickDate = Date()
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
        isCountdown = true
        startCountdown()
    }

    private func playRestCountdownCues(from previous: Double, to current: Double, lead: Int) {
        let upper = Int(floor(previous))
        let lower = Int(floor(current))
        guard lower < upper else { return }
        for sec in stride(from: upper, to: lower, by: -1) {
            if sec <= max(1, lead) && sec >= 1 {
                soundManager.playCountdown(sec)
            }
        }
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

    private func activeSnapshotTarget() -> (planIndex: Int, groupIndex: Int)? {
        for planIndex in session.plans.indices where planIndex < planStates.count {
            let states = planStates[planIndex].groupStates
            if let groupIndex = states.firstIndex(where: { !$0.isCompleted }) {
                return (planIndex, groupIndex)
            }
        }
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
        let segmentCount = max(1, group.segmentCount)
        let segment = min(max(state.currentSegment, 1), segmentCount)
        let distance = Int(group.distanceForSegment(segment - 1).rounded())
        let sets = group.effectiveSetCount
        let set = min(max(state.currentSet, 1), sets)
        let paused = state.isPaused || isGlobalPaused
        let complete = isComplete || state.isCompleted

        let phase: String
        if complete {
            phase = "completed".localized
        } else if state.phase == .resting {
            phase = state.restKind == .set ? "set_rest_label".localized : "resting".localized
        } else {
            phase = String(format: "current_segment".localized, segment, segmentCount) + " · \(distance) m"
        }

        let detail: String
        if complete {
            detail = String(format: "live_total_format".localized, group.totalDistance)
        } else if state.phase == .resting {
            let plannedRest = state.restKind == .set
                ? group.effectiveSetRest
                : group.restAfterSegment(max(0, segment - 1))
            detail = String(format: "live_rest_format".localized, Self.mmss(plannedRest))
        } else {
            detail = String(format: "live_target_format".localized, Self.mmss(group.timeForSegment(segment - 1)))
        }

        let step = sets > 1
            ? String(format: "live_set_step".localized, set, sets) + "  \(segment)/\(segmentCount)"
            : "\(segment) / \(segmentCount)"

        let status: String
        if complete { status = "completed".localized }
        else if paused { status = "paused".localized }
        else if state.phase == .resting { status = "resting".localized }
        else { status = "running".localized }

        let endDate: Date? = (paused || complete) ? nil : Date().addingTimeInterval(max(0, state.remainingTime))

        return .init(
            kindLabel: "pace_run".localized,
            planTitle: batchSessionTitle,
            phaseLabel: phase,
            detailLabel: detail,
            stepLabel: step,
            compactLabel: "\(segment)/\(segmentCount)",
            remainingText: Self.mmss(state.remainingTime),
            endDate: endDate,
            progress: overallProgress(activePlan: planIndex, activeGroup: groupIndex, state: state),
            accentHex: group.colorHex,
            isPaused: paused,
            isComplete: complete,
            statusLabel: status
        )
    }

    private var batchSessionTitle: String {
        let titles = session.plans.map(\.title).filter { !$0.isEmpty }
        if titles.isEmpty { return "pace_run".localized }
        return titles.joined(separator: " · ")
    }

    private func overallProgress(activePlan: Int, activeGroup: Int, state: PaceRunGroupState) -> Double {
        var total = 0.0
        var done = 0.0
        for (planIndex, launchPlan) in session.plans.enumerated() {
            guard planIndex < planStates.count else { continue }
            for (groupIndex, group) in launchPlan.training.groups.enumerated() {
                let unit = max(1, group.segmentCount) * group.effectiveSetCount
                total += Double(unit)
                guard groupIndex < planStates[planIndex].groupStates.count else { continue }
                let groupState = planStates[planIndex].groupStates[groupIndex]
                if groupState.isCompleted {
                    done += Double(unit)
                } else if planIndex == activePlan && groupIndex == activeGroup {
                    let segmentCount = max(1, group.segmentCount)
                    let segment = min(max(state.currentSegment, 1), segmentCount)
                    done += Double((min(max(state.currentSet, 1), group.effectiveSetCount) - 1) * segmentCount + (segment - 1))
                    if state.phase == .running {
                        let planned = max(0.001, group.timeForSegment(segment - 1))
                        done += max(0, min(1, 1 - state.remainingTime / planned))
                    }
                }
            }
        }
        return min(1, max(0, done / max(1, total)))
    }

    private func completedGroupCount(for planIndex: Int) -> Int {
        guard planIndex < planStates.count else { return 0 }
        return planStates[planIndex].groupStates.filter(\.isCompleted).count
    }

    private func planProgressText(for launchPlan: PaceRunLaunchPlan, planIndex: Int) -> String {
        let total = launchPlan.training.groups.count
        let completed = completedGroupCount(for: planIndex)
        if total > 0 && completed == total {
            return "completed".localized
        }
        return "\(completed)/\(total)"
    }
}
