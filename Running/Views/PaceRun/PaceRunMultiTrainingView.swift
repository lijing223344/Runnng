import SwiftUI

enum PaceRunPhase { case countdown, running, resting, paused, completed }
enum PaceRunRestKind { case segment, set }

struct PaceRunGroupState {
    var phase: PaceRunPhase = .countdown
    var currentSegment: Int = 1
    var currentSet: Int = 1
    var remainingTime: Double = 0
    var isPaused: Bool = false
    var isCompleted: Bool = false
    var restKind: PaceRunRestKind? = nil
}

struct PaceRunMultiTrainingView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var localization = LocalizationManager.shared
    @ObservedObject private var soundManager = SoundManager.shared
    let training: PaceRunTraining

    @State private var groupStates: [PaceRunGroupState] = []
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
            // Audit C1: plan context — name, status, scale, then the number.
            Text(training.name)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 32)
            Text("countdown_start".localized)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
                .tracking(2)
                .textCase(.uppercase)
            Text(String(format: "countdown_groups_hint".localized, training.groups.count))
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

    // MARK: - Training Content
    private var trainingContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                ForEach(Array(training.groups.enumerated()), id: \.element.id) { index, group in
                    if index < groupStates.count {
                    PaceRunGroupTrainingCard(
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
            // Pause / Resume
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

            // Stop
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
            var state = PaceRunGroupState()
            state.remainingTime = group.timeForSegment(0)
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
            groupStates[index].currentSegment = 1
            groupStates[index].currentSet = 1
            groupStates[index].remainingTime = training.groups[index].timeForSegment(0)
            groupStates[index].isCompleted = false
            groupStates[index].restKind = nil
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
                    groupStates[index].restKind = nil
                    soundManager.playSound(group.endSound)
                    break
                }
                let currentRemaining = max(0, groupStates[index].remainingTime)
                if currentRemaining > remainingElapsed + epsilon {
                    let previous = currentRemaining
                    let next = currentRemaining - remainingElapsed
                    groupStates[index].remainingTime = next
                    if groupStates[index].phase == .resting {
                        playRestCountdownCues(from: previous, to: next, lead: max(1, group.countdownSeconds))
                    }
                    remainingElapsed = 0
                } else {
                    let previous = currentRemaining
                    remainingElapsed -= currentRemaining
                    groupStates[index].remainingTime = 0
                    if groupStates[index].phase == .resting {
                        playRestCountdownCues(from: previous, to: 0, lead: max(1, group.countdownSeconds))
                    }
                    if groupStates[index].phase == .running {
                        if groupStates[index].currentSegment < group.segmentCount {
                            let finishedIndex = max(0, groupStates[index].currentSegment - 1)
                            let restAfter = max(0, group.restAfterSegment(finishedIndex))
                            if restAfter > epsilon {
                                soundManager.playSound(group.segmentSound)
                                groupStates[index].phase = .resting
                                groupStates[index].remainingTime = restAfter
                                groupStates[index].restKind = .segment
                            } else {
                                soundManager.playSound(group.segmentSound)
                                groupStates[index].currentSegment += 1
                                let nextSegIndex = max(0, groupStates[index].currentSegment - 1)
                                groupStates[index].remainingTime = max(0, group.timeForSegment(nextSegIndex))
                                groupStates[index].phase = .running
                                groupStates[index].restKind = nil
                            }
                        } else {
                            if groupStates[index].currentSet < group.effectiveSetCount {
                                let setRest = group.effectiveSetRest
                                if setRest > epsilon {
                                    soundManager.playSound(group.segmentSound)
                                    groupStates[index].phase = .resting
                                    groupStates[index].remainingTime = setRest
                                    groupStates[index].restKind = .set
                                } else {
                                    groupStates[index].currentSet += 1
                                    groupStates[index].currentSegment = 1
                                    groupStates[index].phase = .running
                                    groupStates[index].remainingTime = max(0, group.timeForSegment(0))
                                    groupStates[index].restKind = nil
                                    soundManager.playSound(group.startSound)
                                }
                            } else {
                                groupStates[index].isCompleted = true
                                groupStates[index].phase = .completed
                                groupStates[index].restKind = nil
                                soundManager.playSound(group.endSound)
                            }
                        }
                    } else if groupStates[index].phase == .resting {
                        if groupStates[index].restKind == .set {
                            if groupStates[index].currentSet < group.effectiveSetCount {
                                groupStates[index].currentSet += 1
                                groupStates[index].currentSegment = 1
                                groupStates[index].remainingTime = max(0, group.timeForSegment(0))
                                groupStates[index].phase = .running
                                groupStates[index].restKind = nil
                                soundManager.playSound(group.startSound)
                            } else {
                                groupStates[index].isCompleted = true
                                groupStates[index].phase = .completed
                                groupStates[index].restKind = nil
                                soundManager.playSound(group.endSound)
                            }
                        } else if groupStates[index].currentSegment < group.segmentCount {
                            groupStates[index].currentSegment += 1
                            let nextSegIndex = max(0, groupStates[index].currentSegment - 1)
                            groupStates[index].remainingTime = max(0, group.timeForSegment(nextSegIndex))
                            groupStates[index].phase = .running
                            groupStates[index].restKind = nil
                            soundManager.playSound(group.segmentSound)
                        } else {
                            groupStates[index].isCompleted = true
                            groupStates[index].phase = .completed
                            groupStates[index].restKind = nil
                            soundManager.playSound(group.endSound)
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
struct PaceRunGroupTrainingCard: View {
    let group: PaceRunGroup
    let state: PaceRunGroupState
    let onPauseToggle: () -> Void

    @State private var speedUnit: Int = 0  // 0=m/s, 1=min/km, 2=km/h

    private var groupColor: Color { Color(hex: group.colorHex) ?? .orange }
    private var segmentDistances: [Int] { group.segmentDistanceValues() }

    // Progress within current segment (0→1)
    private var segmentProgress: Double {
        if state.phase == .resting { return 1 }
        let segTime = group.timeForSegment(state.currentSegment - 1)
        guard segTime > 0 else { return 0 }
        return min(1, max(0, 1.0 - (state.remainingTime / segTime)))
    }

    // Overall distance progress
    private var overallProgress: Double {
        guard !segmentDistances.isEmpty else { return 0 }
        let totalDistance = Double(max(0, segmentDistances.reduce(0, +)))
        guard totalDistance > 0 else { return 0 }

        let currentIndex = max(0, min(state.currentSegment - 1, segmentDistances.count - 1))
        let completedDistance = Double(segmentDistances.prefix(currentIndex).reduce(0, +))
        let currentSegmentDistance = Double(max(0, segmentDistances[currentIndex]))

        if state.phase == .resting {
            return min(1, (completedDistance + currentSegmentDistance) / totalDistance)
        }
        let activeDistance = currentSegmentDistance * min(1, max(0, segmentProgress))
        return min(1, (completedDistance + activeDistance) / totalDistance)
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
        .onAppear {
            speedUnit = StorageManager.shared.loadSettings().speedUnit
        }
    }

    // MARK: Completed state
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

            Text("\(group.totalDistance)\("unit_meter_short".localized)")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(DS.Colors.textTertiary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
    }

    // MARK: Active state
    private var activeContent: some View {
        VStack(spacing: 0) {
            // ── Header ──────────────────────────────────────────
            HStack(alignment: .center) {
                // Color dot + name
                HStack(spacing: 8) {
                    Circle()
                        .fill(groupColor)
                        .frame(width: 10, height: 10)
                    Text(group.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                }

                Spacer()

                // Set progress pill
                if group.effectiveSetCount > 1 {
                    HStack(spacing: 4) {
                        Image(systemName: "repeat")
                            .font(.system(size: 10, weight: .bold))
                        Text(String(format: "set_progress".localized, state.currentSet, group.effectiveSetCount))
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(state.restKind == .set ? DS.Colors.warning : .white.opacity(0.7))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background((state.restKind == .set ? DS.Colors.warning : Color.white.opacity(0.1)).opacity(0.15))
                    .clipShape(Capsule())
                }

                // Status pill
                statusPill
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 14)

            // ── Segment track ────────────────────────────────────
            SegmentTrackView(
                currentSegment: state.currentSegment,
                totalSegments: group.segmentCount,
                segmentProgress: segmentProgress,
                color: groupColor,
                distanceMarkers: group.cumulativeDistanceMarkers(),
                segmentDistances: segmentDistances,
                showsCurrentOutline: true
            )
            .padding(.horizontal, 20)

            // ── Main timer + info row ────────────────────────────
            HStack(alignment: .center, spacing: 0) {
                // Segment counter
                VStack(spacing: 2) {
                    Text("\(state.currentSegment)")
                        .font(DS.Typo.timerMedium)
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.spring(duration: 0.25), value: state.currentSegment)
                    Text("/ \(group.segmentCount) \("segments".localized)")
                        .font(DS.Typo.sectionLabel)
                        .foregroundStyle(.white.opacity(DS.Opacity.strong))
                }
                .frame(maxWidth: .infinity)

                // Divider
                Rectangle()
                    .fill(DS.Colors.divider)
                    .frame(width: 1, height: 44)

                // Countdown timer
                VStack(spacing: 2) {
                    Text(remainingTimeText)
                        .font(DS.Typo.timerLarge)
                        .foregroundStyle(state.phase == .resting ? Color(white: 0.75) : .white)
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text("seconds".localized)
                        .font(DS.Typo.sectionLabel)
                        .foregroundStyle(.white.opacity(DS.Opacity.strong))
                }
                .frame(maxWidth: .infinity)

                // Divider
                Rectangle()
                    .fill(DS.Colors.divider)
                    .frame(width: 1, height: 44)

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

            // ── Overall progress bar + pause button ──────────────
            HStack(spacing: 14) {
                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(DS.Colors.divider)
                            .frame(height: 6)
                        Capsule()
                            .fill(groupColor)
                            .frame(width: geo.size.width * overallProgress, height: 6)
                            .animation(.linear(duration: 0.1), value: overallProgress)
                    }
                }
                .frame(height: 6)

                // Per-group pause button
                Button(action: onPauseToggle) {
                    Image(systemName: state.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(state.isPaused ? .black : .white)
                        .frame(width: 36, height: 36)
                        .background(state.isPaused ? groupColor : DS.Colors.divider)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
        }
    }

    // MARK: Status pill
    private var statusPill: some View {
        HStack(spacing: 5) {
            if state.isPaused {
                Image(systemName: "pause.fill")
                    .font(.system(size: 10, weight: .bold))
                Text("paused".localized)
                    .font(.system(size: 12, weight: .semibold))
            } else if state.phase == .resting {
                Image(systemName: "pause.circle.fill")
                    .font(.system(size: 10, weight: .bold))
                Text("resting".localized)
                    .font(.system(size: 12, weight: .semibold))
            } else {
                // Audit C4: header already carries the color dot; the pill
                // doesn't need a second one.
                Text("running".localized)
                    .font(.system(size: 12, weight: .semibold))
            }
        }
        .foregroundStyle(state.isPaused ? DS.Colors.warning : (state.phase == .resting ? Color(white: 0.75) : groupColor))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            (state.isPaused ? DS.Colors.warning : (state.phase == .resting ? Color(white: 0.75) : groupColor)).opacity(0.15)
        )
        .clipShape(Capsule())
    }

    private var paceString: String {
        let segIndex = max(0, state.currentSegment - 1)
        let segDist = group.distanceForSegment(segIndex)
        let segTime = group.timeForSegment(segIndex)
        guard segDist > 0, segTime > 0 else { return "--" }
        switch speedUnit {
        case 0: // m/s
            return String(format: "%.2f", segDist / segTime)
        case 2: // km/h
            return String(format: "%.1f", segDist / segTime * 3.6)
        default: // min/km
            let paceSeconds = segTime / segDist * 1000
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

    private var remainingTimeText: String {
        let t = max(0, state.remainingTime)
        // Keep a fixed 2-digit integer field below 100s (e.g. 09.98, 10.00)
        // to avoid visual size jump when crossing 10.xx -> 9.xx.
        return t < 100 ? String(format: "%05.2f", t) : String(format: "%.2f", t)
    }

    // MARK: Up-next preview (audit A4)

    /// One-glance description of what follows the current run/rest phase.
    private var upNextText: String? {
        if state.phase == .resting {
            if state.restKind == .set {
                let nextSet = min(group.effectiveSetCount, state.currentSet + 1)
                return String(format: "up_next_set".localized, nextSet, group.effectiveSetCount)
            }
            let next = state.currentSegment + 1
            guard next <= group.segmentCount else { return nil }
            let dist = segmentDistances.indices.contains(next - 1) ? segmentDistances[next - 1] : 0
            let time = group.timeForSegment(next - 1)
            return String(format: "up_next_segment".localized, next, dist, segmentDurationText(time))
        }

        if state.currentSegment < group.segmentCount {
            let next = state.currentSegment + 1
            let dist = segmentDistances.indices.contains(next - 1) ? segmentDistances[next - 1] : 0
            let time = group.timeForSegment(next - 1)
            return String(format: "up_next_segment".localized, next, dist, segmentDurationText(time))
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
}

// MARK: - Segment Track View
/// Renders a continuous capsule track with the current segment highlighted
/// and a smooth fill showing intra-segment progress.
struct SegmentTrackView: View {
    let currentSegment: Int
    let totalSegments: Int
    let segmentProgress: Double   // 0→1 within current segment
    let color: Color
    let distanceMarkers: [Int]
    let segmentDistances: [Int]
    let showsCurrentOutline: Bool

    // Cap display at 32 slots; beyond that collapse into a compact bar
    private var displayCount: Int { max(1, min(totalSegments, 32)) }
    private var useCompact: Bool { totalSegments > 32 }
    private var showInlineDistance: Bool { !useCompact && displayCount <= 12 }
    private var clampedCurrentSegment: Int { max(1, min(currentSegment, max(1, totalSegments))) }

    private var normalizedDistances: [Double] {
        TrackMath.normalizedValues(
            from: segmentDistances.map { Double(max(1, $0)) },
            desired: totalSegments,
            fallback: 1
        )
    }

    var body: some View {
        VStack(spacing: 8) {
            if useCompact {
                compactBar
            } else {
                segmentedTrack
            }
            distanceRuler
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(white: 0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(white: 0.15), lineWidth: 1)
                )
        )
        .padding(.bottom, 4)
    }

    // ── Segmented track (≤32 segments) ──────────────────────────
    private var segmentedTrack: some View {
        GeometryReader { geo in
            let gap: CGFloat = 3
            let widths = TrackMath.slotWidths(
                totalWidth: geo.size.width,
                gap: gap,
                weights: normalizedDistances,
                count: displayCount
            )

            HStack(spacing: gap) {
                ForEach(0..<displayCount, id: \.self) { idx in
                    let seg = idx + 1
                    let width = widths[idx]
                    let activeProgress = min(1, max(0, segmentProgress))

                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(slotBg(seg))

                        if seg == clampedCurrentSegment {
                            Capsule()
                                .fill(color)
                                .frame(width: max(6, width * activeProgress), height: TrackVisualStyle.slotHeight)
                                .animation(.linear(duration: 0.1), value: segmentProgress)
                                .shadow(color: color.opacity(TrackVisualStyle.activeShadowOpacity), radius: TrackVisualStyle.activeShadowRadius, x: 0, y: 0)
                        }

                        if showsCurrentOutline && seg == clampedCurrentSegment {
                            Capsule()
                                .stroke(color.opacity(0.9), lineWidth: TrackVisualStyle.activeOutlineWidth)
                        }
                    }
                    .frame(width: width, height: TrackVisualStyle.slotHeight)
                    .overlay {
                        if showInlineDistance && width > 28 {
                            Text("\(distanceForSegment(idx))\("unit_meter_short".localized)")
                                .font(.system(size: TrackVisualStyle.inlineLabelSize, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white.opacity(seg <= clampedCurrentSegment ? 0.95 : 0.7))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .padding(.horizontal, 2)
                        }
                    }
                }
            }
        }
        .frame(height: TrackVisualStyle.slotHeight)
        .padding(.horizontal, 4)
    }

    // ── Compact bar (>32 segments) ───────────────────────────────
    private var compactBar: some View {
        GeometryReader { geo in
            let totalDistance = CGFloat(max(0.001, normalizedDistances.reduce(0, +)))
            let currentIndex = max(0, min(clampedCurrentSegment - 1, normalizedDistances.count - 1))
            let completedDistance = CGFloat(normalizedDistances.prefix(currentIndex).reduce(0, +))
            let activeDistance = CGFloat(normalizedDistances[currentIndex]) * CGFloat(min(1, max(0, segmentProgress)))
            let completedFrac = completedDistance / totalDistance
            let fullFrac = min(1, (completedDistance + activeDistance) / totalDistance)

            ZStack(alignment: .leading) {
                Capsule().fill(Color(white: 0.15)).frame(height: TrackVisualStyle.compactHeight)
                // Completed segments
                Capsule()
                    .fill(color.opacity(0.4))
                    .frame(width: geo.size.width * completedFrac, height: TrackVisualStyle.compactHeight)
                // Current segment fill
                Capsule()
                    .fill(color)
                    .frame(width: geo.size.width * fullFrac, height: TrackVisualStyle.compactHeight)
                    .animation(.linear(duration: 0.1), value: fullFrac)
                    .shadow(color: color.opacity(TrackVisualStyle.activeShadowOpacity), radius: TrackVisualStyle.activeShadowRadius, x: 0, y: 0)
            }
        }
        .frame(height: TrackVisualStyle.compactHeight)
        .padding(.horizontal, 4)
    }

    // ── Distance Ruler ──────────────────────────────────────────
    private var distanceRuler: some View {
        GeometryReader { geo in
            let tickCount = useCompact ? 10 : displayCount
            let step = geo.size.width / CGFloat(tickCount)
            let plannedDistance = max(0, distanceMarkers.last ?? 0)
            let gap: CGFloat = 3
            let widths = TrackMath.slotWidths(
                totalWidth: geo.size.width,
                gap: gap,
                weights: normalizedDistances,
                count: displayCount
            )
            let boundaryX = TrackMath.boundaryPositions(widths: widths, gap: gap)
            
            // Logic to determine label frequency based on total count
            let baseLabelInterval: Int = {
                if tickCount <= 8 { return 1 }
                if tickCount <= 16 { return 2 }
                if tickCount <= 24 { return 4 }
                return 5
            }()
            // Audit A4: never let the fixed 44pt labels collide — raise the
            // interval until the label count fits the available width.
            let maxLabels = max(2, Int(geo.size.width / 46))
            let minInterval = Int(ceil(Double(tickCount + 1) / Double(maxLabels)))
            let labelInterval = max(baseLabelInterval, minInterval)

            ZStack(alignment: .topLeading) {
                // Tick Marks
                Path { path in
                    for i in 0...tickCount {
                        let x = useCompact ? (CGFloat(i) * step) : boundaryX[max(0, min(i, boundaryX.count - 1))]
                        let isMajor = i % labelInterval == 0 || i == tickCount
                        let height: CGFloat = isMajor ? 8 : 4
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: height))
                    }
                }
                .stroke(Color.white.opacity(0.25), lineWidth: 1)

                // Numerical Labels — indices pre-picked so clamped edge
                // labels can never stack (e.g. "750米"/"800米" at the right edge).
                ForEach(rulerLabelIndices(
                    tickCount: tickCount,
                    labelInterval: labelInterval,
                    useCompact: useCompact,
                    step: step,
                    boundaryX: boundaryX,
                    width: geo.size.width
                ), id: \.self) { i in
                    let isFirst = i == 0
                    let isLast = i == tickCount

                    let distance = useCompact ?
                        Int(round(Double(i) / Double(max(1, tickCount)) * Double(plannedDistance))) :
                        distanceAtBoundary(i)

                    // Audit A4: clamp edge labels inside the track so the
                    // first/last marker ("0米"/"800米") no longer overflow.
                    let rawX = useCompact ? (CGFloat(i) * step) : boundaryX[max(0, min(i, boundaryX.count - 1))]
                    let clampedX = min(max(rawX, 22), geo.size.width - 22)

                    Text("\(distance)\("unit_meter_short".localized)")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(isFirst || isLast ? .white : .white.opacity(0.5))
                        .frame(width: 44) // Constant width to help centering
                        .position(x: clampedX, y: 22)
                }
            }
        }
        .frame(height: 32)
        .padding(.horizontal, 4)
        .padding(.top, 4)
    }

    /// Audit A4 review pass: picks which ruler labels to render. The first
    /// and last markers are always kept; an intermediate label is skipped if
    /// its clamped position would collide with the previously kept label; if
    /// the final marker collides, it replaces the last kept candidate so the
    /// right edge always shows the planned total distance.
    private func rulerLabelIndices(
        tickCount: Int,
        labelInterval: Int,
        useCompact: Bool,
        step: CGFloat,
        boundaryX: [CGFloat],
        width: CGFloat
    ) -> [Int] {
        func clampedX(_ i: Int) -> CGFloat {
            let raw = useCompact ? (CGFloat(i) * step) : boundaryX[max(0, min(i, boundaryX.count - 1))]
            return min(max(raw, 22), width - 22)
        }

        let candidates = (0...tickCount).filter { $0 % labelInterval == 0 || $0 == tickCount }
        guard let first = candidates.first, let last = candidates.last else { return [] }

        var kept: [(index: Int, x: CGFloat)] = [(first, clampedX(first))]
        for i in candidates.dropFirst() where i != last {
            let x = clampedX(i)
            if x - kept.last!.x >= 44 {
                kept.append((i, x))
            }
        }
        if last != kept.last!.index {
            let x = clampedX(last)
            if kept.count == 1 || x - kept[kept.count - 2].x >= 44 {
                kept[kept.count - 1] = (last, x)
            }
        }
        return kept.map(\.index)
    }

    private func slotBg(_ seg: Int) -> Color {
        if seg < clampedCurrentSegment {
            return color.opacity(0.45)   // completed
        } else if seg == clampedCurrentSegment {
            return color.opacity(0.18)   // active (fill drawn on top)
        } else {
            return Color(white: 0.2)     // upcoming
        }
    }

    private func distanceForSegment(_ index: Int) -> Int {
        guard !segmentDistances.isEmpty else { return 0 }
        let clamped = max(0, min(index, segmentDistances.count - 1))
        return max(0, segmentDistances[clamped])
    }

    private func distanceAtBoundary(_ index: Int) -> Int {
        guard !distanceMarkers.isEmpty else { return 0 }
        let clamped = max(0, min(index, distanceMarkers.count - 1))
        return max(0, distanceMarkers[clamped])
    }
}

#Preview {
    PaceRunMultiTrainingView(
        training: PaceRunTraining(
            groups: [
                PaceRunGroup(name: "A组", colorHex: "#FF5733", totalDistance: 800, segmentDistance: 50, totalTime: 240),
                PaceRunGroup(name: "B组", colorHex: "#3B82F6", totalDistance: 400, segmentDistance: 50, totalTime: 120),
                PaceRunGroup(name: "C组", colorHex: "#22C55E", totalDistance: 1500, segmentDistance: 100, totalTime: 420)
            ]
        )
    )
}
