import SwiftUI

enum IntervalPhase { case countdown, running, resting, completed }

struct GroupTrainingState {
    var phase: IntervalPhase = .countdown
    var currentRepetition: Int = 1
    var currentSet: Int = 1
    var remainingTime: Double = 0
    var isPaused: Bool = false
    var isCompleted: Bool = false
    var isSetRest: Bool = false
}

struct IntervalTrainingView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var localization = LocalizationManager.shared
    @ObservedObject private var soundManager = SoundManager.shared
    let training: IntervalTraining

    @State private var groupStates: [GroupTrainingState] = []
    @State private var isGlobalPaused: Bool = false
    @State private var countdownSeconds: Int = 3
    @State private var isCountdown: Bool = true
    @State private var timer: Timer?
    @State private var lastTickUptime: TimeInterval = 0
    @State private var showConfirmStop = false
    @State private var didSaveRecord = false
    @State private var hasStartedTraining = false
    @State private var sessionStartedAt: Date?
    private let maxTickElapsed: TimeInterval = 0.25
    private let maxStateTransitionsPerTick = 512

    private var allCompleted: Bool {
        !groupStates.isEmpty && groupStates.allSatisfy { $0.isCompleted } && !isCountdown
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
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                lastTickUptime = ProcessInfo.processInfo.systemUptime
            }
        }
        .alert("confirm_stop".localized, isPresented: $showConfirmStop) {
            Button("cancel".localized, role: .cancel) {}
            Button("confirm".localized, role: .destructive) { stopTraining() }
        }
    }

    // MARK: - Countdown Overlay
    private var countdownOverlay: some View {
        VStack(spacing: 16) {
            Spacer()
            // Audit C1: give the blank countdown a plan context.
            Text(training.name)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 32)
            Text(String(format: "countdown_groups_hint".localized, training.groups.count))
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.55))
            Text("countdown_start".localized)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
                .tracking(2)
                .textCase(.uppercase)
            Text("\(countdownSeconds)")
                .font(DS.Typo.countdownHero)
                .foregroundStyle(DS.Colors.interval)
                .monospacedDigit()
                .contentTransition(.numericText(countsDown: true))
                .animation(.spring(duration: 0.3), value: countdownSeconds)
            Spacer()
        }
    }

    // MARK: - Training Content
    private var trainingContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                ForEach(Array(training.groups.enumerated()), id: \.element.id) { index, group in
                    if index < groupStates.count {
                    GroupTrainingCard(
                        group: group,
                        state: groupStates[index],
                        onPauseToggle: { togglePauseGroup(index) }
                    )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 120)
        }
    }

    // MARK: - Bottom Controls
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
                .trainingControlSurface(highlighted: primaryHighlighted, accent: DS.Colors.interval)
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

    // MARK: - Training Logic
    private func initializeStates() {
        timer?.invalidate()
        isCountdown = true
        isGlobalPaused = false
        showConfirmStop = false
        groupStates = training.groups.map { group in
            var state = GroupTrainingState()
            state.remainingTime = group.runTimeForRep(0)
            return state
        }
        countdownSeconds = max(1, training.countdownSeconds)
        didSaveRecord = false
        hasStartedTraining = false
        sessionStartedAt = nil
    }

    private func startCountdown() {
        isCountdown = true
        countdownSeconds = max(1, training.countdownSeconds)
        sessionStartedAt = Date()
        soundManager.playCountdown(countdownSeconds)
        let countdownTimer = Timer(timeInterval: 1, repeats: true) { _ in
            if self.countdownSeconds > 1 {
                self.countdownSeconds -= 1
                self.soundManager.playCountdown(self.countdownSeconds)
            } else {
                self.timer?.invalidate()
                self.isCountdown = false
                self.soundManager.playSound(self.training.groups.first?.startSound ?? .whistleStandard)
                self.startAllGroups()
            }
        }
        RunLoop.main.add(countdownTimer, forMode: .common)
        timer = countdownTimer
    }

    private func startAllGroups() {
        hasStartedTraining = true
        for index in training.groups.indices {
            groupStates[index].phase = .running
            groupStates[index].currentRepetition = 1
            groupStates[index].currentSet = 1
            groupStates[index].remainingTime = training.groups[index].runTimeForRep(0)
            groupStates[index].isCompleted = false
            groupStates[index].isSetRest = false
        }
        startTimer()
    }

    private func startTimer() {
        lastTickUptime = ProcessInfo.processInfo.systemUptime
        let mainTimer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { _ in
            let now = ProcessInfo.processInfo.systemUptime
            let rawElapsed = max(0, now - self.lastTickUptime)
            self.lastTickUptime = now
            let elapsed = min(rawElapsed, self.maxTickElapsed)
            self.updateAllGroups(elapsed: elapsed)
        }
        RunLoop.main.add(mainTimer, forMode: .common)
        timer = mainTimer
    }

    private func updateAllGroups(elapsed: TimeInterval) {
        guard !isGlobalPaused else { return }
        guard elapsed > 0 else { return }
        let epsilon = 0.000_001
        for index in training.groups.indices {
            guard !groupStates[index].isCompleted && !groupStates[index].isPaused else { continue }
            let group = training.groups[index]
            var remainingElapsed = elapsed
            var transitions = 0

            // Carry over overshoot across run/rest boundaries to keep wall-clock timing accurate.
            while remainingElapsed > epsilon && !groupStates[index].isCompleted {
                transitions += 1
                if transitions > maxStateTransitionsPerTick {
                    groupStates[index].isCompleted = true
                    groupStates[index].phase = .completed
                    groupStates[index].remainingTime = 0
                    groupStates[index].isSetRest = false
                    soundManager.playSound(group.endSound)
                    break
                }
                let currentRemaining = max(0, groupStates[index].remainingTime)
                if currentRemaining > remainingElapsed + epsilon {
                    let previous = currentRemaining
                    let next = currentRemaining - remainingElapsed
                    groupStates[index].remainingTime = next
                    if groupStates[index].phase == .resting {
                        playRestCountdownCues(from: previous, to: next, lead: group.restCountdownLeadSeconds)
                    }
                    remainingElapsed = 0
                } else {
                    let previous = currentRemaining
                    groupStates[index].remainingTime = 0
                    if groupStates[index].phase == .resting {
                        playRestCountdownCues(from: previous, to: 0, lead: group.restCountdownLeadSeconds)
                    }
                    remainingElapsed -= currentRemaining

                    if groupStates[index].phase == .running {
                        // Run ended -> enter rest (if any), otherwise jump to next run.
                        let totalReps = group.effectiveRepetitions
                        let currentRepIndex = max(0, groupStates[index].currentRepetition - 1)
                        let restAfter = max(0, group.restTimeForRep(currentRepIndex))

                        if groupStates[index].currentRepetition < totalReps {
                            if restAfter > epsilon {
                                groupStates[index].phase = .resting
                                groupStates[index].remainingTime = restAfter
                                groupStates[index].isSetRest = false
                                soundManager.playSound(group.restSound)
                            } else {
                                groupStates[index].currentRepetition += 1
                                groupStates[index].phase = .running
                                let nextRepIndex = max(0, groupStates[index].currentRepetition - 1)
                                groupStates[index].remainingTime = max(0, group.runTimeForRep(nextRepIndex))
                                groupStates[index].isSetRest = false
                                soundManager.playSound(group.startSound)
                            }
                        } else {
                            // Set completed
                            if groupStates[index].currentSet < group.effectiveSetCount {
                                let setRest = group.effectiveSetRest
                                if setRest > epsilon {
                                    groupStates[index].phase = .resting
                                    groupStates[index].remainingTime = setRest
                                    groupStates[index].isSetRest = true
                                    soundManager.playSound(group.restSound)
                                } else {
                                    groupStates[index].currentSet += 1
                                    groupStates[index].currentRepetition = 1
                                    groupStates[index].phase = .running
                                    groupStates[index].remainingTime = max(0, group.runTimeForRep(0))
                                    groupStates[index].isSetRest = false
                                    soundManager.playSound(group.startSound)
                                }
                            } else {
                                groupStates[index].isCompleted = true
                                groupStates[index].phase = .completed
                                soundManager.playSound(group.endSound)
                            }
                        }
                    } else if groupStates[index].phase == .resting {
                        if groupStates[index].isSetRest {
                            if groupStates[index].currentSet < group.effectiveSetCount {
                                groupStates[index].currentSet += 1
                                groupStates[index].currentRepetition = 1
                                groupStates[index].phase = .running
                                groupStates[index].remainingTime = max(0, group.runTimeForRep(0))
                                groupStates[index].isSetRest = false
                                soundManager.playSound(group.startSound)
                            } else {
                                groupStates[index].isCompleted = true
                                groupStates[index].phase = .completed
                                soundManager.playSound(group.endSound)
                            }
                        } else {
                            if groupStates[index].currentRepetition < group.effectiveRepetitions {
                                groupStates[index].currentRepetition += 1
                                groupStates[index].phase = .running
                                let nextRepIndex = max(0, groupStates[index].currentRepetition - 1)
                                groupStates[index].remainingTime = max(0, group.runTimeForRep(nextRepIndex))
                                soundManager.playSound(group.startSound)
                            } else {
                                groupStates[index].isCompleted = true
                                groupStates[index].phase = .completed
                                soundManager.playSound(group.endSound)
                            }
                        }
                    } else {
                        remainingElapsed = 0
                    }
                }
            }
        }
        if !groupStates.isEmpty && groupStates.allSatisfy({ $0.isCompleted }) {
            timer?.invalidate()
            saveTrainingRecord(completed: true)
        }
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

    private func togglePauseGroup(_ index: Int) {
        guard index >= 0, index < groupStates.count else { return }
        groupStates[index].isPaused.toggle()
    }
    private func toggleGlobalPause() { isGlobalPaused.toggle() }
    private func stopTraining() {
        timer?.invalidate()
        if sessionStartedAt != nil {
            saveTrainingRecord(completed: false)
        }
        dismiss()
    }
    private func restartTraining() {
        timer?.invalidate()
        isGlobalPaused = false
        initializeStates()
        isCountdown = true
        startCountdown()
    }

    private func saveTrainingRecord(completed: Bool) {
        guard !didSaveRecord else { return }
        didSaveRecord = true
        let endAt = Date()
        guard let record = try? TrainingRecordFactory.makeRecord(
            for: training,
            userId: StorageManager.shared.currentUser?.id ?? "",
            sessionStartedAt: sessionStartedAt,
            endAt: endAt,
            completed: completed
        ) else { return }
        StorageManager.shared.addTrainingRecord(record)
    }
}

// MARK: - Group Training Card
struct GroupTrainingCard: View {
    let group: IntervalGroup
    let state: GroupTrainingState
    let onPauseToggle: () -> Void
    @State private var speedUnit: Int = 0  // 0=m/s, 1=min/km, 2=km/h

    private var groupColor: Color { Color(hex: group.colorHex) ?? .orange }
    private var totalReps: Int { max(1, group.effectiveRepetitions) }
    private var repRunTimes: [Double] {
        (0..<totalReps).map { max(0, group.runTimeForRep($0)) }
    }
    private var repRestTimes: [Double] {
        (0..<totalReps).map { idx in
            idx < totalReps - 1 ? max(0, group.restTimeForRep(idx)) : 0
        }
    }
    private var repCycleDurations: [Double] {
        zip(repRunTimes, repRestTimes).map { max(0, $0 + $1) }
    }

    // Phase accent color
    private var phaseColor: Color {
        if state.isPaused { return .orange }
        if state.phase == .running { return groupColor }
        return Color.white.opacity(DS.Opacity.prominent)
    }

    // Progress within current phase (0→1)
    private var phaseProgress: Double {
        guard !state.isCompleted else { return 1 }
        let repIndex = max(0, state.currentRepetition - 1)
        let total: Double
        if state.phase == .running {
            total = group.runTimeForRep(repIndex)
        } else if state.phase == .resting && state.isSetRest {
            total = group.effectiveSetRest
        } else {
            total = group.restTimeForRep(repIndex)
        }
        guard total > 0 else { return 0 }
        return min(1, max(0, 1.0 - state.remainingTime / total))
    }

    // Overall per-set progress (0→1), weighted by per-repetition planned duration.
    private var overallProgress: Double {
        let totalDuration = repCycleDurations.reduce(0, +)
        guard totalDuration > 0 else { return 0 }

        let currentIndex = max(0, min(state.currentRepetition - 1, totalReps - 1))
        var elapsed = repCycleDurations.prefix(currentIndex).reduce(0, +)

        let run = repRunTimes[currentIndex]
        let rest = repRestTimes[currentIndex]

        switch state.phase {
        case .running:
            elapsed += run * min(1, max(0, phaseProgress))
        case .resting:
            if state.isSetRest {
                elapsed = totalDuration
            } else {
                elapsed += run + rest * min(1, max(0, phaseProgress))
            }
        case .completed:
            elapsed = totalDuration
        default:
            break
        }
        return min(1, max(0, elapsed / totalDuration))
    }

    private var remainingTimeText: String {
        let t = max(0, state.remainingTime)
        return t < 100 ? String(format: "%05.2f", t) : String(format: "%.2f", t)
    }

    private var paceString: String {
        let repIndex = max(0, state.currentRepetition - 1)
        let dist = Double(group.runDistance)
        let time = group.runTimeForRep(repIndex)
        guard dist > 0, time > 0 else { return "--" }
        switch speedUnit {
        case 0: return String(format: "%.2f", dist / time)
        case 2: return String(format: "%.1f", dist / time * 3.6)
        default:
            let paceSeconds = time / dist * 1000
            return String(format: "%d:%02d", Int(paceSeconds) / 60, Int(paceSeconds) % 60)
        }
    }

    private var speedUnitLabel: String {
        switch speedUnit {
        case 0: return "m_per_s".localized
        case 2: return "km_per_h".localized
        default: return "/km".localized
        }
    }

    // MARK: Up-next preview (audit A4)

    /// One-glance description of what follows the current run/rest phase.
    private var upNextText: String? {
        if state.phase == .resting {
            if state.isSetRest {
                let nextSet = min(group.effectiveSetCount, state.currentSet + 1)
                return String(format: "up_next_set".localized, nextSet, group.effectiveSetCount)
            }
            let next = state.currentRepetition + 1
            guard next <= totalReps else { return nil }
            let time = group.runTimeForRep(next - 1)
            return String(format: "up_next_rep".localized, next, group.runDistance, segmentDurationText(time))
        }

        if state.currentRepetition < totalReps {
            let next = state.currentRepetition + 1
            let time = group.runTimeForRep(next - 1)
            return String(format: "up_next_rep".localized, next, group.runDistance, segmentDurationText(time))
        }
        if group.effectiveSetCount > 1, state.currentSet < group.effectiveSetCount {
            return String(format: "up_next_set".localized, state.currentSet + 1, group.effectiveSetCount)
        }
        return nil
    }

    private func upNextRow(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.turn.down.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(groupColor)
            Text(text)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(DS.Colors.textSecondary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(DS.Colors.cardHover)
        )
        .padding(.horizontal, 20)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("up_next_title".localized + ", " + text)
    }

    private func segmentDurationText(_ seconds: Double) -> String {
        if seconds >= 60 {
            let total = Int(seconds.rounded())
            return String(format: "%d:%02d", total / 60, total % 60)
        }
        return String(format: "%.1f%@", seconds, "sec_label".localized)
    }

    var body: some View {
        VStack(spacing: 0) {
            if state.isCompleted {
                completedContent
            } else {
                activeContent
            }
        }
        .dsCard(radius: DS.Radius.lg, padding: 0)
        .onAppear { speedUnit = StorageManager.shared.loadSettings().speedUnit }
    }

    // MARK: Completed
    private var completedContent: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(groupColor.opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(groupColor)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(group.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                Text("completed".localized)
                    .font(.system(size: 13))
                    .foregroundStyle(groupColor)
            }
            Spacer()
            Text("\(group.effectiveRepetitions) \("repetitions".localized)")
                .font(.system(size: 13))
                .foregroundStyle(DS.Colors.textTertiary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
    }

    // MARK: Active
    private var activeContent: some View {
        VStack(spacing: 0) {
            // ── Header ──────────────────────────────────────────
            HStack {
                HStack(spacing: 8) {
                    Circle().fill(groupColor).frame(width: 10, height: 10)
                    Text(group.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                }
                Spacer()
                if group.effectiveSetCount > 1 {
                    HStack(spacing: 4) {
                        Image(systemName: "repeat")
                            .font(.system(size: 10, weight: .bold))
                        Text(String(format: "set_progress".localized, state.currentSet, group.effectiveSetCount))
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(state.isSetRest ? DS.Colors.warning : .white.opacity(0.7))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background((state.isSetRest ? DS.Colors.warning : Color.white.opacity(0.1)).opacity(0.15))
                    .clipShape(Capsule())
                }
                statusPill
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 14)

            // ── Rep track ────────────────────────────────────────
            RepTrackView(
                currentRep: state.currentRepetition,
                totalReps: group.effectiveRepetitions,
                phase: state.phase,
                phaseProgress: phaseProgress,
                color: groupColor,
                isSetRest: state.isSetRest,
                repRunTimes: repRunTimes,
                repRestTimes: repRestTimes,
                showsCurrentOutline: true
            )
            .padding(.horizontal, 20)

            // ── Stats row ────────────────────────────────────────
            HStack(alignment: .center, spacing: 0) {
                // Rep counter
                VStack(spacing: 2) {
                    Text("\(state.currentRepetition)")
                        .font(DS.Typo.timerMedium)
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.spring(duration: 0.25), value: state.currentRepetition)
                    Text("/ \(group.effectiveRepetitions) \("repetitions".localized)")
                        .font(DS.Typo.sectionLabel)
                        .foregroundStyle(.white.opacity(DS.Opacity.strong))
                }
                .frame(maxWidth: .infinity)

                Rectangle().fill(DS.Colors.divider).frame(width: 1, height: 44)

                // Timer
                VStack(spacing: 2) {
                    Text(remainingTimeText)
                        .font(DS.Typo.timerLarge)
                        .foregroundStyle(phaseColor)
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text("seconds".localized)
                        .font(DS.Typo.sectionLabel)
                        .foregroundStyle(.white.opacity(DS.Opacity.strong))
                }
                .frame(maxWidth: .infinity)

                Rectangle().fill(DS.Colors.divider).frame(width: 1, height: 44)

                // Pace
                VStack(spacing: 2) {
                    Text(paceString)
                        .font(DS.Typo.timerSmall)
                        .foregroundStyle(.white)
                        .monospacedDigit()
                    Text(speedUnitLabel)
                        .font(DS.Typo.sectionLabel)
                        .foregroundStyle(.white.opacity(DS.Opacity.strong))
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    speedUnit = (speedUnit + 1) % 3
                    var settings = StorageManager.shared.loadSettings()
                    settings.speedUnit = speedUnit
                    StorageManager.shared.saveSettings(settings)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)

            // ── Up-next preview (audit A4) ───────────────────────
            if let upNextText { upNextRow(upNextText) }

            // ── Overall progress + pause button ──────────────────
            HStack(spacing: 14) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(DS.Colors.divider).frame(height: 6)
                        Capsule()
                            .fill(groupColor)
                            .frame(width: geo.size.width * overallProgress, height: 6)
                            .animation(.linear(duration: 0.3), value: overallProgress)
                    }
                }
                .frame(height: 6)

                Button(action: onPauseToggle) {
                    Image(systemName: state.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(state.isPaused ? .black : .white)
                        .frame(width: 36, height: 36)
                        .background(state.isPaused ? groupColor : DS.Colors.divider)
                        .clipShape(Circle())
                }
                .accessibilityLabel(state.isPaused ? "resume".localized : "pause".localized)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
        }
    }

    // MARK: Status pill
    private var statusPill: some View {
        HStack(spacing: 5) {
            if state.isPaused {
                Image(systemName: "pause.fill").font(.system(size: 10, weight: .bold))
                Text("paused".localized).font(.system(size: 12, weight: .semibold))
            } else if state.phase == .running {
                Image(systemName: "figure.run").font(.system(size: 10, weight: .bold))
                Text("running".localized).font(.system(size: 12, weight: .semibold))
            } else {
                Image(systemName: "pause.circle.fill").font(.system(size: 10, weight: .bold))
                Text("resting".localized).font(.system(size: 12, weight: .semibold))
            }
        }
        .foregroundStyle(phaseColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(phaseColor.opacity(0.15))
        .clipShape(Capsule())
    }

}

// MARK: - Rep Track View
/// Renders repetitions as a segmented track.
/// Slot width and fill are weighted by each repetition's planned run/rest duration.
/// The active slot shows animated fill for the current phase.
struct RepTrackView: View {
    let currentRep: Int
    let totalReps: Int
    let phase: IntervalPhase
    let phaseProgress: Double   // 0→1 within current phase
    let color: Color
    let isSetRest: Bool
    let repRunTimes: [Double]
    let repRestTimes: [Double]
    let showsCurrentOutline: Bool

    private let trackGap: CGFloat = 3
    private var useCompact: Bool { totalReps > 36 }
    private var segmentsPerRow: Int {
        if totalReps <= 12 { return max(1, totalReps) }
        if totalReps <= 24 { return 12 }
        return 9
    }
    private var clampedCurrentRep: Int { max(1, min(currentRep, max(1, totalReps))) }
    private var normalizedRunTimes: [Double] {
        TrackMath.normalizedValues(from: repRunTimes, desired: totalReps, fallback: 1)
    }
    private var normalizedRestTimes: [Double] {
        TrackMath.normalizedValues(from: repRestTimes, desired: totalReps, fallback: 0)
    }
    private var cycleDurations: [Double] {
        zip(normalizedRunTimes, normalizedRestTimes).map { max(0.001, $0 + $1) }
    }
    private var showInlineDuration: Bool { !useCompact && totalReps <= 24 }
    private var rowRanges: [Range<Int>] {
        guard !useCompact else { return [] }
        var ranges: [Range<Int>] = []
        var start = 0
        let strideCount = max(1, segmentsPerRow)
        while start < totalReps {
            let end = min(totalReps, start + strideCount)
            ranges.append(start..<end)
            start = end
        }
        return ranges
    }
    private var currentRepDurationText: String {
        let index = max(0, min(clampedCurrentRep - 1, max(0, totalReps - 1)))
        return slotDurationLabel(index: index)
    }

    var body: some View {
        VStack(spacing: 6) {
            if useCompact {
                compactBar
            } else {
                VStack(spacing: 4) {
                    ForEach(Array(rowRanges.enumerated()), id: \.offset) { _, range in
                        segmentedTrack(range: range)
                    }
                }
            }
            HStack(spacing: 5) {
                Image(systemName: "clock")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                Text(currentRepDurationText)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .accessibilityElement(children: .combine)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .background(Color(red: 0.04, green: 0.04, blue: 0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.bottom, 4)
    }

    // ── Segmented track ──────────────────────────────────────────
    private func segmentedTrack(range: Range<Int>) -> some View {
        GeometryReader { geo in
            let widths = rowWidths(for: range, availableWidth: geo.size.width)
            let showRowDuration = showInlineDuration && (widths.min() ?? 0) >= 28

            HStack(spacing: trackGap) {
                ForEach(Array(range.enumerated()), id: \.element) { offset, globalIndex in
                    let rep = globalIndex + 1
                    let width = widths[safe: offset] ?? 0
                    ZStack(alignment: .leading) {
                        repSlotBackground(rep: rep, width: width)
                        if rep == clampedCurrentRep {
                            activeFill(slotWidth: width, repIndex: globalIndex)
                        }
                        if showsCurrentOutline && rep == clampedCurrentRep {
                            Capsule()
                                .stroke(color.opacity(0.9), lineWidth: TrackVisualStyle.activeOutlineWidth)
                        }
                    }
                    .frame(width: width, height: TrackVisualStyle.slotHeight)
                    .overlay {
                        if showRowDuration {
                            Text(slotDurationLabel(index: globalIndex))
                                .font(.system(size: TrackVisualStyle.inlineLabelSize, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.85))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: TrackVisualStyle.slotHeight)
        .padding(.horizontal, 8)
    }

    @ViewBuilder
    private func repSlotBackground(rep: Int, width: CGFloat) -> some View {
        if rep < clampedCurrentRep || (isSetRest && rep == clampedCurrentRep) {
            // Completed rep
            Capsule()
                .fill(color.opacity(0.4))
                .frame(width: width, height: TrackVisualStyle.slotHeight)
        } else if rep == clampedCurrentRep {
            // Active rep background
            Capsule()
                .fill(DS.Colors.divider)
                .frame(width: width, height: TrackVisualStyle.slotHeight)
        } else {
            // Upcoming rep
            Capsule()
                .fill(Color(white: 0.18))
                .frame(width: width, height: TrackVisualStyle.slotHeight)
        }
    }

    @ViewBuilder
    private func activeFill(slotWidth: CGFloat, repIndex: Int) -> some View {
        let run = normalizedRunTimes[safe: repIndex] ?? 0
        let rest = normalizedRestTimes[safe: repIndex] ?? 0
        let cycle = max(0.001, run + rest)
        let runFrac = CGFloat(run / cycle)
        let restFrac = CGFloat(rest / cycle)
        let p = CGFloat(min(1, max(0, phaseProgress)))

        if phase == .running {
            Capsule()
                .fill(color)
                .frame(width: max(4, slotWidth * runFrac * p), height: TrackVisualStyle.slotHeight)
                .animation(.linear(duration: 0.2), value: phaseProgress)
                .shadow(color: color.opacity(TrackVisualStyle.activeShadowOpacity), radius: TrackVisualStyle.activeShadowRadius, x: 0, y: 0)
        } else if phase == .resting {
            if isSetRest {
                Capsule()
                    .fill(color.opacity(0.45))
                    .frame(width: slotWidth, height: TrackVisualStyle.slotHeight)
                    .shadow(color: color.opacity(TrackVisualStyle.activeShadowOpacity * 0.8), radius: TrackVisualStyle.activeShadowRadius, x: 0, y: 0)
            } else {
                Capsule()
                    .fill(color)
                    .frame(width: max(4, slotWidth * (runFrac + restFrac * p)), height: TrackVisualStyle.slotHeight)
                    .animation(.linear(duration: 0.2), value: phaseProgress)
                    .shadow(color: color.opacity(TrackVisualStyle.activeShadowOpacity), radius: TrackVisualStyle.activeShadowRadius, x: 0, y: 0)
            }
        }
    }

    // ── Compact bar ──────────────────────────────────────────────
    private var compactBar: some View {
        GeometryReader { geo in
            let totalDuration = max(0.001, cycleDurations.reduce(0, +))
            let idx = max(0, min(clampedCurrentRep - 1, cycleDurations.count - 1))
            let completedDuration = cycleDurations.prefix(idx).reduce(0, +)
            let run = normalizedRunTimes[idx]
            let rest = normalizedRestTimes[idx]
            let p = min(1, max(0, phaseProgress))

            let activeDuration: Double = {
                switch phase {
                case .running:
                    return run * p
                case .resting:
                    if isSetRest { return cycleDurations[idx] }
                    return run + rest * p
                case .completed:
                    return cycleDurations[idx]
                default:
                    return 0
                }
            }()

            let fillFrac = CGFloat(min(1, (completedDuration + activeDuration) / totalDuration))
            let completedFrac = CGFloat(min(1, completedDuration / totalDuration))

            ZStack(alignment: .leading) {
                Capsule().fill(Color(white: 0.2)).frame(height: TrackVisualStyle.compactHeight)
                Capsule()
                    .fill(color.opacity(0.4))
                    .frame(width: geo.size.width * completedFrac, height: TrackVisualStyle.compactHeight)
                Capsule()
                    .fill(color)
                    .frame(width: geo.size.width * fillFrac, height: TrackVisualStyle.compactHeight)
                    .animation(.linear(duration: 0.2), value: fillFrac)
                    .shadow(color: color.opacity(TrackVisualStyle.activeShadowOpacity), radius: TrackVisualStyle.activeShadowRadius, x: 0, y: 0)
            }
        }
        .frame(height: TrackVisualStyle.compactHeight)
        .padding(.horizontal, 8)
    }

    private func rowWidths(for range: Range<Int>, availableWidth: CGFloat) -> [CGFloat] {
        let rowDurations = Array(cycleDurations[range])
        guard !rowDurations.isEmpty else { return [] }

        let maxRowWeight = max(
            0.001,
            rowRanges.map { Array(cycleDurations[$0]).reduce(0, +) }.max() ?? rowDurations.reduce(0, +)
        )
        let maxSlots = max(1, rowRanges.map { $0.count }.max() ?? range.count)
        let maxGapTotal = trackGap * CGFloat(max(0, maxSlots - 1))
        let pxPerWeight = max(1, (availableWidth - maxGapTotal)) / CGFloat(maxRowWeight)

        var widths = rowDurations.map { max(8, CGFloat($0) * pxPerWeight) }
        let rowGapTotal = trackGap * CGFloat(max(0, widths.count - 1))
        let currentRowTotal = widths.reduce(0, +)

        if currentRowTotal + rowGapTotal > availableWidth {
            let target = max(1, availableWidth - rowGapTotal)
            let safeTotal = max(0.001, currentRowTotal)
            widths = widths.map { target * ($0 / safeTotal) }
        }

        return widths
    }

    private func slotDurationLabel(index: Int) -> String {
        let run = Int((normalizedRunTimes[safe: index] ?? 0).rounded())
        let rest = Int((normalizedRestTimes[safe: index] ?? 0).rounded())
        if rest > 0 {
            return "\(run)/\(rest)\("sec_label".localized)"
        }
        return "\(run)\("sec_label".localized)"
    }
}

#Preview {
    IntervalTrainingView(
        training: IntervalTraining(
            groups: [
                IntervalGroup(name: "Group A", colorHex: "#FF5733", runDistance: 100, runTime: 15, restTime: 45, repetitions: 10),
                IntervalGroup(name: "Group B", colorHex: "#3B82F6", runDistance: 100, runTime: 18, restTime: 50, repetitions: 8),
                IntervalGroup(name: "Group C", colorHex: "#22C55E", runDistance: 200, runTime: 30, restTime: 60, repetitions: 6)
            ]
        )
    )
}
