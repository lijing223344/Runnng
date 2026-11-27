import SwiftUI

private enum PacePlanLimits {
    static let maxCountdown = 60
    static let maxSetCount = 200
    static let maxTotalDistance = 100_000
    static let maxSegmentDistance = 5_000
    static let maxCustomSegments = 200
    static let maxSetRestSeconds: Double = 3_600
    static let maxTotalTimeSeconds: Double = 24 * 60 * 60
    static let minSegmentTimeSeconds: Double = 0.1
}

// MARK: - Setup View

struct PaceRunSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var localization = LocalizationManager.shared
    let isQuickStart: Bool
    let seedTraining: PaceRunTraining?
    @State private var training = PaceRunTraining()
    @State private var editingGroup: PaceRunGroup?
    @State private var trainingToStart: PaceRunTraining?
    @State private var historyLaunchSession: PaceRunLaunchSession?
    @State private var didLoad = false
    @State private var selectedGroupIDs: Set<UUID> = []
    @State private var activeTab: SetupTab = .create
    @State private var historyPlans: [SavedPlan] = []
    @State private var selectedHistoryPlanIDs: Set<UUID> = []
    @State private var copiedHistoryPlanSourceID: UUID?

    private enum SetupTab: String, CaseIterable, Identifiable {
        case create
        case history
        var id: String { rawValue }
    }

    private var canStartCreatePlan: Bool { !selectedGroupIDs.isEmpty }
    private var canStartHistoryPlan: Bool { !selectedHistoryPlanIDs.isEmpty }
    private var selectedHistoryPlans: [SavedPlan] {
        historyPlans.filter { selectedHistoryPlanIDs.contains($0.id) }
    }
    init(isQuickStart: Bool = false, seedTraining: PaceRunTraining? = nil) {
        self.isQuickStart = isQuickStart
        self.seedTraining = seedTraining
    }

    var body: some View {
        VStack(spacing: 0) {
            if !isQuickStart {
                tabSwitcher
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
            }

            if isHistoryTab {
                historyList
            } else {
                if !training.groups.isEmpty {
                    startCountdownCard
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                }
                if training.groups.isEmpty {
                    emptyState
                } else {
                    groupsList
                }
            }

            bottomBar
        }
        .frame(maxWidth: 1000)
        .background(TrainingPageBackground())
        .navigationTitle("pace_run".localized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isQuickStart {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel".localized) { dismiss() }
                }
            }
            if !isQuickStart && !isHistoryTab {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: createNewPlan) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .accessibilityLabel("add_plan".localized)
                    .accessibilityIdentifier("pace_add_plan_toolbar_button")
                }
            }
        }
        .fullScreenCover(item: $editingGroup) { group in
            ZStack {
                DS.Colors.bg.ignoresSafeArea()
            PaceRunGroupEditorView(group: group) { savedGroup in
                if let index = training.groups.firstIndex(where: { $0.id == savedGroup.id }) {
                    training.groups[index] = savedGroup
                } else {
                    training.groups.append(savedGroup)
                    // 新建后只勾这一条，避免与旧方案一起被启动。
                    selectedGroupIDs = [savedGroup.id]
                }
                persistTraining()
                syncSelectedGroups()
            }
            }
            .presentationBackground(DS.Colors.bg)
        }
        .fullScreenCover(item: $trainingToStart, onDismiss: handleTrainingDismiss) { launchTraining in
            PaceRunMultiTrainingView(training: launchTraining)
        }
        .fullScreenCover(item: $historyLaunchSession, onDismiss: handleTrainingDismiss) { launchSession in
            PaceRunBatchTrainingView(session: launchSession)
        }
        .onAppear {
            guard !didLoad else { return }
            didLoad = true
            if let seedTraining {
                training = normalizedTraining(seedTraining)
            } else if !isQuickStart, let saved = StorageManager.shared.loadPaceRunTraining() {
                training = normalizedTraining(saved)
            }
            if isQuickStart, training.groups.isEmpty {
                initializeQuickStartTrainingIfNeeded()
            }
            syncSelectedGroups(selectFirstIfEmpty: true)
            refreshHistoryPlans(selectFirstIfNeeded: true)
        }
        .onChange(of: training.countdownSeconds) { _, _ in
            persistTraining()
        }
        .onChange(of: activeTab) { _, tab in
            if tab == .history {
                refreshHistoryPlans(selectFirstIfNeeded: true)
            }
        }
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {

            Image(systemName: "figure.run")
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(DS.Colors.textTertiary)

            Text("empty_no_plans".localized)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(DS.Colors.textPrimary)
                .padding(.top, DS.Space.xxs)

            Text("pace_run_desc".localized)
                .font(.system(size: 14))
                .foregroundStyle(DS.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if !isHistoryTab {
                Button(action: createNewPlan) {
                    Label("add_plan".localized, systemImage: "plus")
                }
                .buttonStyle(DSSecondaryButtonStyle())
                .frame(width: 168)
                .padding(.top, DS.Space.sm)
                .accessibilityIdentifier("pace_add_plan_empty_button")
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, DS.Space.page)
        .padding(.top, DS.Space.xxl)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var isHistoryTab: Bool {
        !isQuickStart && activeTab == .history
    }

    private var tabSwitcher: some View {
        DSSegmentedPicker(selection: $activeTab, options: SetupTab.allCases, accent: DS.Colors.paceRun) { tab in
            tab == .create ? "plan_create_tab".localized : "plan_history_tab".localized
        }
        .accessibilityIdentifier("pace_setup_tab_picker")
    }

    private var historyList: some View {
        List {
            if historyPlans.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 34))
                            .foregroundStyle(.secondary)
                        Text("no_history_plans".localized)
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                ForEach(historyPlans) { plan in
                    historyPlanRow(plan)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button {
                                editHistoryPlanAsCopy(plan)
                            } label: {
                                Label("edit_plan".localized, systemImage: "pencil")
                            }
                            .tint(.blue)
                            .accessibilityIdentifier("pace_history_edit_button")

                            Button(role: .destructive) {
                                StorageManager.shared.deletePlan(plan)
                                refreshHistoryPlans(selectFirstIfNeeded: true)
                            } label: {
                                Label("delete_plan".localized, systemImage: "trash")
                            }
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func historyPlanRow(_ plan: SavedPlan) -> some View {
        let isSelected = selectedHistoryPlanIDs.contains(plan.id)
        let decoded = decodePacePlan(plan)
        let groupCount = decoded?.groups.count ?? 0
        let totalDistance = decoded?.groups.reduce(0) { $0 + max(0, $1.totalDistance) } ?? 0
        let plannedDuration = decoded?.plannedSessionDuration() ?? 0
        let title = decoded.map { inferredPlanName(groups: $0.groups) } ?? plan.name
        return Button {
            if isSelected {
                selectedHistoryPlanIDs.remove(plan.id)
            } else {
                selectedHistoryPlanIDs.insert(plan.id)
            }
        } label: {
            HStack(alignment: .center, spacing: DS.Space.md) {
                TrainingSelectionIndicator(isSelected: isSelected, accent: DS.Colors.paceRun)

                VStack(alignment: .leading, spacing: DS.Space.sm) {
                    HStack(alignment: .firstTextBaseline, spacing: DS.Space.sm) {
                        Text(title)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(DS.Colors.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)

                        Spacer(minLength: DS.Space.sm)

                        Text(formattedDateTime(plan.lastUsedAt))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(DS.Colors.textTertiary)
                            .lineLimit(1)
                    }

                    HStack(spacing: DS.Space.md) {
                        StatChip(icon: "arrow.right", value: "\(totalDistance)\("unit_meter_short".localized)")
                        StatChip(icon: "clock", value: formatDuration(plannedDuration))
                        StatChip(icon: "square.stack.3d.up", value: "\(groupCount)\("groups".localized)")
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, DS.Space.lg)
            .padding(.vertical, DS.Space.md)
            .trainingSelectableCardContainer(
                accent: DS.Colors.paceRun,
                isSelected: isSelected,
                cornerRadius: DS.Radius.lg
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Groups List
    private var groupsList: some View {
        List {
            ForEach(training.groups) { group in
                PaceRunGroupCard(group: group, isSelected: selectedGroupIDs.contains(group.id)) {
                    editingGroup = group
                } onToggleSelect: {
                    toggleGroupSelection(group.id)
                } onDuplicate: {
                    duplicateGroup(group)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        deleteGroup(group)
                    } label: {
                        Label("delete".localized, systemImage: "trash")
                    }
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Bottom Bar
    private var bottomBar: some View {
        let canStart = isHistoryTab ? canStartHistoryPlan : canStartCreatePlan
        let actionTitle = isHistoryTab ? "start_selected_plan".localized : "start_training".localized
        let selectedCount = isHistoryTab ? selectedHistoryPlanIDs.count : selectedGroupIDs.count
        let buttonTitle = selectedCount > 0 ? "\(actionTitle) (\(selectedCount))" : actionTitle
        return VStack(alignment: .leading, spacing: DS.Space.sm) {
            if !sessionSummary.isEmpty {
                Text(sessionSummary)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(DS.Colors.textTertiary)
            }

            Button(action: isHistoryTab ? startSelectedHistoryPlan : startSelectedTraining) {
                HStack(spacing: DS.Space.sm) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 13, weight: .medium))
                    Text(buttonTitle)
                        .font(.system(size: 16, weight: .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .foregroundStyle(canStart ? DS.Colors.bg : DS.Colors.textTertiary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .trainingPrimaryActionSurface(isEnabled: canStart, colors: [DS.Colors.paceRun])
            }
            .disabled(!canStart)
            .buttonStyle(ScaleButtonStyle())
            .accessibilityIdentifier("pace_start_training_button")
        }
        .padding(.horizontal, DS.Space.page)
        .padding(.top, DS.Space.md)
        .padding(.bottom, DS.Space.xl)
        .background(
            DS.Colors.bg
                .overlay(alignment: .top) { Rectangle().fill(DS.Colors.borderLight).frame(height: 1) }
        )
    }

    private var sessionSummary: String {
        if isHistoryTab {
            let count = selectedHistoryPlanIDs.count
            return count > 0 ? "\(count)\("groups".localized)" : ""
        }
        let groups = training.groups.filter { selectedGroupIDs.contains($0.id) }
        guard !groups.isEmpty else { return "" }
        let distance = groups.reduce(0) { $0 + $1.totalDistance }
        let seconds = groups.reduce(0.0) { $0 + $1.totalTime }
        return "\(groups.count)\("groups".localized) · \(distance)\("unit_meter_short".localized) · \(formatDuration(seconds))"
    }

    private func addGroup() {
        var newGroup = PaceRunGroup()
        newGroup.sortOrder = training.groups.count
        newGroup.colorHex = GroupColor.allCases[training.groups.count % GroupColor.allCases.count].rawValue
        // Distinct cue per moment: go, split, finish — never the same blast twice.
        newGroup.startSound = .startTriad
        newGroup.segmentSound = .splitTick
        newGroup.endSound = .finishArpeggio
        editingGroup = newGroup
    }

    private func createNewPlan() {
        guard !isHistoryTab else { return }
        persistTraining()
        addGroup()
    }

    private func startSelectedTraining() {
        var launch = normalizedTraining(training)
        launch.groups = launch.groups.filter { selectedGroupIDs.contains($0.id) }
        guard !launch.groups.isEmpty else { return }
        rememberPlanUsage(for: launch)
        trainingToStart = launch
    }

    private func startSelectedHistoryPlan() {
        let plansToStart = selectedHistoryPlans
        guard !plansToStart.isEmpty else { return }

        let runtimeCountdown = max(1, training.countdownSeconds)
        for plan in plansToStart {
            StorageManager.shared.touchPlanUsage(plan.id)
        }

        let launchPlans = TrainingLaunchFactory.makePaceHistoryLaunchPlans(
            from: plansToStart,
            runtimeCountdownSeconds: runtimeCountdown,
            decode: decodePacePlan(_:),
            fallbackTitle: { training, savedPlan in
                savedPlan.name.isEmpty ? inferredPlanName(groups: training.groups) : savedPlan.name
            }
        )
        guard !launchPlans.isEmpty else { return }
        if launchPlans.count == 1, let first = launchPlans.first {
            trainingToStart = first.training
        } else {
            historyLaunchSession = PaceRunLaunchSession(plans: launchPlans)
        }
        refreshHistoryPlans(selectFirstIfNeeded: false)
    }

    private func applyHistoryPlan(_ plan: SavedPlan) {
        guard let decoded = decodePacePlan(plan) else { return }
        training = normalizedTraining(decoded)
        copiedHistoryPlanSourceID = nil
        persistTraining()
        syncSelectedGroups(selectFirstIfEmpty: true)
        selectedHistoryPlanIDs = [plan.id]
        activeTab = .create
    }

    private func editHistoryPlanAsCopy(_ plan: SavedPlan) {
        guard let decoded = decodePacePlan(plan) else { return }
        training = normalizedTraining(decoded)
        copiedHistoryPlanSourceID = plan.id
        persistTraining()
        syncSelectedGroups(selectFirstIfEmpty: true)
        selectedHistoryPlanIDs = [plan.id]
        activeTab = .create
    }

    private func rememberPlanUsage(for planTraining: PaceRunTraining) {
        guard let data = try? JSONEncoder().encode(planTraining) else { return }
        let name = inferredPlanName(groups: planTraining.groups)

        if copiedHistoryPlanSourceID != nil {
            let createdAt = Date()
            let newPlan = SavedPlan(
                name: name,
                trainingType: .paceRun,
                configData: data,
                createdAt: createdAt,
                updatedAt: createdAt,
                lastUsedAt: createdAt
            )
            StorageManager.shared.addPlan(newPlan)
            copiedHistoryPlanSourceID = nil
            selectedHistoryPlanIDs = [newPlan.id]
            refreshHistoryPlans(selectFirstIfNeeded: true)
            return
        }

        let updated = StorageManager.shared.upsertPlan(
            name: name,
            trainingType: .paceRun,
            configData: data,
            lastUsedAt: Date()
        )
        selectedHistoryPlanIDs = [updated.id]
        refreshHistoryPlans(selectFirstIfNeeded: true)
    }

    private func refreshHistoryPlans(selectFirstIfNeeded: Bool = false) {
        historyPlans = StorageManager.shared.loadPlans().filter { $0.trainingType == .paceRun }
        selectedHistoryPlanIDs = selectedHistoryPlanIDs.intersection(Set(historyPlans.map(\.id)))
        if selectFirstIfNeeded && selectedHistoryPlanIDs.isEmpty, let first = historyPlans.first {
            selectedHistoryPlanIDs = [first.id]
        }
    }

    private func inferredPlanName(groups: [PaceRunGroup]) -> String {
        if groups.isEmpty { return "pace_run".localized }
        if groups.count == 1 { return groups[0].name }
        return "\(groups[0].name) +\(groups.count - 1)"
    }

    private func formattedDateTime(_ date: Date) -> String {
        date.formatted(
            Date.FormatStyle(date: .abbreviated, time: .shortened)
                .locale(LocalizationManager.shared.locale)
        )
    }

    private func decodePacePlan(_ plan: SavedPlan) -> PaceRunTraining? {
        guard let decoded = try? JSONDecoder().decode(PaceRunTraining.self, from: plan.configData) else { return nil }
        return normalizedTraining(decoded)
    }

    private func formatDuration(_ totalSeconds: Double) -> String {
        let safe = max(0, Int(totalSeconds.rounded()))
        let h = safe / 3600
        let m = (safe % 3600) / 60
        let s = safe % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    private func duplicateGroup(_ group: PaceRunGroup) {
        var copied = group
        copied.id = UUID()
        copied.name = "\(group.name) \("group_copy_suffix".localized)"
        copied.sortOrder = training.groups.count
        training.groups.append(copied)
        selectedGroupIDs.insert(copied.id)
        persistTraining()
    }

    private func deleteGroup(_ group: PaceRunGroup) {
        training.groups.removeAll { $0.id == group.id }
        selectedGroupIDs.remove(group.id)
        persistTraining()
        syncSelectedGroups()
    }

    private func persistTraining() {
        guard !isQuickStart else { return }
        StorageManager.shared.savePaceRunTraining(training)
    }

    private func initializeQuickStartTrainingIfNeeded() {
        guard isQuickStart, training.groups.isEmpty else { return }
        var defaultGroup = PaceRunGroup()
        defaultGroup.sortOrder = 0
        defaultGroup.colorHex = GroupColor.allCases[0].rawValue
        defaultGroup.startSound = .startTriad
        defaultGroup.segmentSound = .splitTick
        defaultGroup.endSound = .finishArpeggio
        training = PaceRunTraining(
            groups: [defaultGroup],
            countdownSeconds: max(1, training.countdownSeconds)
        )
        selectedGroupIDs = [defaultGroup.id]
        editingGroup = nil
    }

    private func handleTrainingDismiss() {
        if isQuickStart {
            dismiss()
        }
    }

    private func toggleGroupSelection(_ id: UUID) {
        if selectedGroupIDs.contains(id) {
            selectedGroupIDs.remove(id)
        } else {
            selectedGroupIDs.insert(id)
        }
    }

    private func syncSelectedGroups(selectFirstIfEmpty: Bool = false) {
        let existing = Set(training.groups.map { $0.id })
        selectedGroupIDs = selectedGroupIDs.intersection(existing)
        if selectFirstIfEmpty && selectedGroupIDs.isEmpty,
           let first = training.groups.min(by: { $0.sortOrder < $1.sortOrder }) {
            // 旧逻辑会在空选时勾上全部分组，一次启动多个方案容易误开。
            // 现在只预选排序最前的一个，其余由用户显式勾选。
            selectedGroupIDs = [first.id]
        }
    }

    private func normalizedTraining(_ value: PaceRunTraining) -> PaceRunTraining {
        var fixed = value
        fixed.countdownSeconds = min(PacePlanLimits.maxCountdown, max(1, fixed.countdownSeconds))
        for idx in fixed.groups.indices {
            fixed.groups[idx].countdownSeconds = min(PacePlanLimits.maxCountdown, max(1, fixed.groups[idx].countdownSeconds))
            fixed.groups[idx].setCount = min(PacePlanLimits.maxSetCount, max(1, fixed.groups[idx].setCount ?? 1))
            fixed.groups[idx].setRestTime = min(PacePlanLimits.maxSetRestSeconds, max(0, fixed.groups[idx].setRestTime ?? 0))
            fixed.groups[idx].intensityPercent = TrainingIntensity.clampedPercent(fixed.groups[idx].intensityPercent)
            fixed.groups[idx].totalDistance = min(PacePlanLimits.maxTotalDistance, max(1, fixed.groups[idx].totalDistance))
            fixed.groups[idx].segmentDistance = min(PacePlanLimits.maxSegmentDistance, max(1, fixed.groups[idx].segmentDistance))
            fixed.groups[idx].totalTime = min(PacePlanLimits.maxTotalTimeSeconds, max(PacePlanLimits.minSegmentTimeSeconds, fixed.groups[idx].totalTime))

            if let customSegments = fixed.groups[idx].customSegments, !customSegments.isEmpty {
                let normalizedSegments = Array(customSegments.prefix(PacePlanLimits.maxCustomSegments)).map { segment in
                    CustomSegment(
                        id: segment.id,
                        distance: min(PacePlanLimits.maxSegmentDistance, max(1, segment.distance)),
                        time: min(PacePlanLimits.maxTotalTimeSeconds, max(PacePlanLimits.minSegmentTimeSeconds, segment.time)),
                        restAfter: min(PacePlanLimits.maxSetRestSeconds, max(0, segment.restAfter))
                    )
                }
                fixed.groups[idx].customSegments = normalizedSegments
            }
        }
        return fixed
    }

    private var startCountdownCard: some View {
        EditorCard(title: "countdown".localized, icon: "clock.badge.checkmark.fill", iconColor: DS.Colors.rest) {
            HStack(spacing: DS.Space.xs) {
                ForEach([3, 5, 10, 15, 20], id: \.self) { sec in
                    DSPresetTile(
                        title: "\(sec)\("sec_label".localized)",
                        isSelected: training.countdownSeconds == sec
                    ) {
                        training.countdownSeconds = sec
                    }
                }
            }
        }
    }

}

// MARK: - Group Card

struct PaceRunGroupCard: View {
    let group: PaceRunGroup
    let isSelected: Bool
    let onEdit: () -> Void
    let onToggleSelect: () -> Void
    let onDuplicate: () -> Void

    private var groupColor: Color { Color(hex: group.colorHex) ?? .orange }

    var body: some View {
        HStack(alignment: .center, spacing: DS.Space.md) {
            Button(action: onToggleSelect) {
                TrainingSelectionIndicator(isSelected: isSelected, accent: DS.Colors.paceRun)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isSelected ? "a11y_deselect_group".localized : "a11y_select_group".localized)
            .accessibilityIdentifier("pace_group_select_\(group.id.uuidString)")

            VStack(alignment: .leading, spacing: DS.Space.sm) {
                HStack(alignment: .firstTextBaseline, spacing: DS.Space.sm) {
                    Circle()
                        .fill(groupColor)
                        .frame(width: 8, height: 8)

                    Text(group.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(DS.Colors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Spacer(minLength: DS.Space.sm)

                    Text("\(group.segmentCount) \("segments".localized)")
                        .font(.system(size: 11, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(DS.Colors.textTertiary)
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: DS.Space.md) {
                        StatChip(icon: "arrow.right", value: "\(group.totalDistance)\("unit_meter_short".localized)")
                        StatChip(icon: "clock", value: formatTime(group.totalTime))
                        StatChip(icon: "speedometer", value: formatPace())
                    }
                    VStack(alignment: .leading, spacing: DS.Space.xxs) {
                        HStack(spacing: DS.Space.md) {
                            StatChip(icon: "arrow.right", value: "\(group.totalDistance)\("unit_meter_short".localized)")
                            StatChip(icon: "clock", value: formatTime(group.totalTime))
                        }
                        StatChip(icon: "speedometer", value: formatPace())
                    }
                }
            }

            Spacer(minLength: DS.Space.sm)

            HStack(spacing: DS.Space.xxs) {
                Button(action: onDuplicate) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(DS.Colors.textTertiary)
                        .frame(width: 34, height: 34)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("a11y_duplicate_group".localized)
                .accessibilityIdentifier("pace_group_duplicate_\(group.id.uuidString)")

                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(DS.Colors.textTertiary)
                        .frame(width: 34, height: 34)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("a11y_edit_group".localized)
                .accessibilityIdentifier("pace_group_edit_\(group.id.uuidString)")
            }
        }
        .padding(.horizontal, DS.Space.lg)
        .padding(.vertical, DS.Space.md)
        .frame(maxWidth: .infinity)
        .trainingSelectableCardContainer(
            accent: DS.Colors.paceRun,
            isSelected: isSelected,
            cornerRadius: DS.Radius.lg
        )
        .accessibilityIdentifier("pace_group_card_\(group.id.uuidString)")
    }

    private func formatTime(_ seconds: Double) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        let cs = Int((seconds.truncatingRemainder(dividingBy: 1) * 100).rounded())
        if m > 0 {
            return cs > 0 ? "\(m)'\(s).\(cs / 10)\"" : "\(m)'\(s)\""
        }
        return cs > 0
            ? "\(s).\(cs / 10)\("sec_label".localized)"
            : "\(s)\("sec_label".localized)"
    }

    private func formatPace() -> String {
        guard group.totalDistance > 0, group.totalTime > 0 else { return "--" }
        let ps = group.totalTime / Double(group.totalDistance) * 1000
        return String(format: "%d:%02d/km", Int(ps) / 60, Int(ps) % 60)
    }
}

// MARK: - Stat Chip

struct StatChip: View {
    let icon: String
    let value: String
    var body: some View {
        HStack(spacing: DS.Space.xxs) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(DS.Colors.textHint)
            Text(value)
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .foregroundStyle(DS.Colors.textSecondary)
    }
}

// MARK: - Group Editor

struct PaceRunGroupEditorView: View {
    @Environment(\.dismiss) var dismiss
    @State var group: PaceRunGroup
    let onSave: (PaceRunGroup) -> Void
    let isNew: Bool

    // MM:SS.cc wheels
    @State private var pickerMinutes: Int = 0
    @State private var pickerSeconds: Int = 0
    @State private var pickerCenti:   Int = 0   // 0–99 centiseconds
    @State private var useCustomSegments: Bool = false
    @State private var speedUnit: Int = 0  // 0=m/s, 1=min/km, 2=km/h
    @State private var editingField: SegmentEditField? = nil
    @State private var editText: String = ""
    @FocusState private var segmentEditorFocused: Bool
    private let customSegmentsActionAnchorID = "pace-custom-segments-actions-anchor"
    @State private var intensityText = TrainingIntensity.displayText(TrainingIntensity.fullPercent)
    private let quickIntensityOptions = TrainingIntensity.quickOptions

    enum SegmentEditField: Identifiable {
        case distance(Int)
        case time(Int)
        case rest(Int)

        var id: String {
            switch self {
            case .distance(let i): return "dist-\(i)"
            case .time(let i): return "time-\(i)"
            case .rest(let i): return "rest-\(i)"
            }
        }

        var isDistance: Bool {
            if case .distance = self { return true }
            return false
        }

        var isRest: Bool {
            if case .rest = self { return true }
            return false
        }

        var segmentIndex: Int {
            switch self {
            case .distance(let i), .time(let i), .rest(let i): return i
            }
        }
    }

    init(group: PaceRunGroup, onSave: @escaping (PaceRunGroup) -> Void) {
        self._group = State(initialValue: group)
        self.onSave = onSave
        self.isNew = group.name == PaceRunGroup.defaultName
        self._useCustomSegments = State(initialValue: group.customSegments != nil && !(group.customSegments!.isEmpty))
    }

    // Derived total seconds from wheels
    private var pickerTotalTime: Double {
        Double(pickerMinutes * 60 + pickerSeconds) + Double(pickerCenti) / 100.0
    }

    private var parsedIntensityPercent: Double? {
        TrainingIntensity.parsePercent(intensityText)
    }

    private var normalizedIntensityPercent: Double? {
        guard let parsedIntensityPercent else { return nil }
        return TrainingIntensity.clampedPercent(parsedIntensityPercent)
    }

    private var hasNonDefaultIntensity: Bool {
        guard let normalizedIntensityPercent else { return false }
        return abs(normalizedIntensityPercent - TrainingIntensity.fullPercent) > 0.0001
    }

    private var baseTotalTimeAtHundredPercent: Double {
        if useCustomSegments, let segments = group.customSegments, !segments.isEmpty {
            return segments.reduce(0) { $0 + max(0, $1.time) }
        }
        return pickerTotalTime
    }

    private func adjustedTimeForSelectedIntensity(_ baseTimeAtHundredPercent: Double) -> Double? {
        guard let normalizedIntensityPercent else { return nil }
        return TrainingIntensity.adjustedTime(
            baseTimeAtHundredPercent: baseTimeAtHundredPercent,
            intensityPercent: normalizedIntensityPercent
        )
    }

    private var effectiveTotalTimeForSelectedIntensity: Double? {
        adjustedTimeForSelectedIntensity(baseTotalTimeAtHundredPercent)
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(spacing: 16) {
                        nameCard
                        distanceCard
                        if useCustomSegments {
                            customSegmentsCard(scrollProxy: scrollProxy)
                        } else {
                            segmentCard
                            timeCard
                        }
                        intensityCard
                        countdownCard
                        setCard
                        colorCard
                        soundCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
                .background(TrainingPageBackground())
                .safeAreaInset(edge: .bottom) { editorBottomSaveBar }
                .safeAreaInset(edge: .top, spacing: 0) { editorHeader }
                .toolbar(.hidden, for: .navigationBar)
                .onAppear {
                    group = prepareGroupForEditor(group)
                    syncPickerFromGroup()
                    intensityText = TrainingIntensity.displayText(group.intensityPercent)
                    speedUnit = StorageManager.shared.loadSettings().speedUnit
                }
                // 容器曾带 pace_group_editor 标识，会覆盖内部保存栏与取消按钮的 id，
                // 标识保留在内部 ScrollView 上即可。
                .sheet(item: $editingField, onDismiss: {
                    segmentEditorFocused = false
                    editText = ""
                }) { _ in
                    segmentValueEditorSheet
                }
            }
        }
    }

    private var canSave: Bool {
        !(normalizedIntensityPercent == nil ||
          (useCustomSegments
              ? (group.customSegments?.reduce(0.0) { $0 + $1.time } ?? 0) <= 0
              : pickerTotalTime <= 0))
    }

    private func performSave() {
        guard let selectedIntensity = normalizedIntensityPercent else { return }
        group.intensityPercent = selectedIntensity

        if useCustomSegments, let cs = group.customSegments, !cs.isEmpty {
            let scaledSegments = cs.map { segment in
                var scaled = segment
                let baseTime = min(
                    PacePlanLimits.maxTotalTimeSeconds,
                    max(PacePlanLimits.minSegmentTimeSeconds, segment.time)
                )
                let adjusted = TrainingIntensity.adjustedTime(
                    baseTimeAtHundredPercent: baseTime,
                    intensityPercent: selectedIntensity
                ) ?? baseTime
                scaled.time = min(
                    PacePlanLimits.maxTotalTimeSeconds,
                    max(PacePlanLimits.minSegmentTimeSeconds, adjusted)
                )
                return scaled
            }
            group.customSegments = scaledSegments
            group.totalTime = scaledSegments.reduce(0) { $0 + $1.time }
            group.segmentTime = group.totalTime / Double(max(1, scaledSegments.count))
        } else {
            let baseTotal = min(
                PacePlanLimits.maxTotalTimeSeconds,
                max(PacePlanLimits.minSegmentTimeSeconds, pickerTotalTime)
            )
            let adjustedTotal = TrainingIntensity.adjustedTime(
                baseTimeAtHundredPercent: baseTotal,
                intensityPercent: selectedIntensity
            ) ?? baseTotal
            group.totalTime = min(
                PacePlanLimits.maxTotalTimeSeconds,
                max(PacePlanLimits.minSegmentTimeSeconds, adjustedTotal)
            )
            group.customSegments = nil
            group.segmentTime = group.totalTime / Double(max(1, group.segmentCount))
        }
        onSave(normalizeGroupForSave(group))
        dismiss()
    }

    /// Bottom fixed save bar — save without scrolling back to top (audit A2).
    private var editorHeader: some View {
        ZStack {
            Text(isNew ? "add_plan".localized : "edit_group".localized)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(DS.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 72)

            HStack {
                Button("cancel".localized) { dismiss() }
                    .font(.system(size: 15))
                    .foregroundStyle(DS.Colors.textSecondary)
                    .accessibilityIdentifier("pace_editor_cancel_button")
                Spacer()
            }
            .padding(.horizontal, DS.Space.page)
        }
        .frame(height: 52)
        .frame(maxWidth: .infinity)
        .background(DS.Colors.bg.ignoresSafeArea(edges: .top))
        .overlay(alignment: .bottom) {
            Rectangle().fill(DS.Colors.borderLight).frame(height: 1)
        }
    }

    private var editorBottomSaveBar: some View {
        VStack(spacing: 0) {
            Button(action: performSave) {
                Label("save".localized, systemImage: "checkmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(canSave ? DS.Colors.bg : DS.Colors.textTertiary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .trainingPrimaryActionSurface(isEnabled: canSave)
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(!canSave)
            .accessibilityIdentifier("pace_editor_save_bar_button")
        }
        .padding(.horizontal, DS.Space.page)
        .padding(.top, DS.Space.md)
        .padding(.bottom, DS.Space.md)
        .background(
            DS.Colors.bg
                .overlay(alignment: .top) { Rectangle().fill(DS.Colors.borderLight).frame(height: 1) }
                .ignoresSafeArea(edges: .bottom)
        )
    }

    // ── Sync helpers ────────────────────────────────────────────────
    private func syncPickerFromGroup() {
        let total = group.totalTime
        pickerMinutes = Int(total) / 60
        pickerSeconds = Int(total) % 60
        pickerCenti   = Int((total.truncatingRemainder(dividingBy: 1) * 100).rounded())
    }

    /// When picker wheels change → distribute evenly to custom segments
    private func distributeTimeToSegments() {
        guard useCustomSegments, let segs = group.customSegments, !segs.isEmpty else { return }
        let total = pickerTotalTime
        let perSeg = total / Double(segs.count)
        for i in segs.indices {
            group.customSegments?[i].time = perSeg
        }
    }

    private func prepareGroupForEditor(_ input: PaceRunGroup) -> PaceRunGroup {
        var prepared = normalizeGroupForSave(input)
        prepared.intensityPercent = TrainingIntensity.clampedPercent(prepared.intensityPercent)
        let storedIntensity = prepared.intensityPercent

        guard abs(storedIntensity - TrainingIntensity.fullPercent) > 0.0001 else {
            return prepared
        }

        if let customSegments = prepared.customSegments, !customSegments.isEmpty {
            let baselineSegments = customSegments.map { segment in
                var baseline = segment
                let source = min(
                    PacePlanLimits.maxTotalTimeSeconds,
                    max(PacePlanLimits.minSegmentTimeSeconds, segment.time)
                )
                let converted = TrainingIntensity.baselineTime(
                    trainingTimeAtSelectedIntensity: source,
                    intensityPercent: storedIntensity
                ) ?? source
                baseline.time = min(
                    PacePlanLimits.maxTotalTimeSeconds,
                    max(PacePlanLimits.minSegmentTimeSeconds, converted)
                )
                return baseline
            }
            prepared.customSegments = baselineSegments
            prepared.totalTime = baselineSegments.reduce(0.0) { $0 + $1.time }
            prepared.segmentTime = prepared.totalTime / Double(max(1, baselineSegments.count))
        } else {
            let source = min(
                PacePlanLimits.maxTotalTimeSeconds,
                max(PacePlanLimits.minSegmentTimeSeconds, prepared.totalTime)
            )
            let baselineTotal = TrainingIntensity.baselineTime(
                trainingTimeAtSelectedIntensity: source,
                intensityPercent: storedIntensity
            ) ?? source
            prepared.totalTime = min(
                PacePlanLimits.maxTotalTimeSeconds,
                max(PacePlanLimits.minSegmentTimeSeconds, baselineTotal)
            )
            prepared.segmentTime = max(
                PacePlanLimits.minSegmentTimeSeconds,
                prepared.totalTime / Double(max(1, prepared.segmentCount))
            )
        }
        return prepared
    }

    // ── Cards ────────────────────────────────────────────────────────

    private var nameCard: some View {
        EditorCard(title: "plan_name".localized, icon: "tag.fill", iconColor: .blue) {
            HStack {
                FloatingTextInputField(
                    placeholder: "plan_name_placeholder".localized,
                    title: "plan_name".localized,
                    value: $group.name,
                    allowEmpty: true
                )
                Spacer()
            }
        }
    }

    private var distanceCard: some View {
        EditorCard(title: "total_distance".localized, icon: "arrow.right.circle.fill", iconColor: DS.Colors.paceRun) {
            VStack(spacing: 12) {
                // Preset chips
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DS.Space.sm), count: 4), spacing: DS.Space.xs) {
                    ForEach(PresetDistance.allCases) { preset in
                        DSPresetTile(title: preset.displayName, isSelected: group.totalDistance == preset.rawValue) {
                            group.totalDistance = preset.rawValue
                        }
                        .accessibilityIdentifier("pace_total_distance_\(preset.rawValue)")
                    }
                }
                Divider()
                // Custom input
                HStack {
                    Text("custom".localized)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(DS.Colors.textSecondary)
                    Spacer()
                    HStack(spacing: 4) {
                        FloatingIntInputField(
                            placeholder: "800",
                            title: "total_distance".localized,
                            value: $group.totalDistance,
                            width: 60,
                            minValue: 1,
                            maxValue: PacePlanLimits.maxTotalDistance,
                            accessibilityIdentifier: "pace_quick_distance_field"
                        )
                        Text("meters".localized)
                            .font(.system(size: 14))
                            .foregroundStyle(DS.Colors.textSecondary)
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 12))
                            .foregroundStyle(DS.Colors.textTertiary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(DS.Colors.field)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(DS.Colors.fieldBorder, lineWidth: 1)
                    )
                }
            }
        }
    }

    private var segmentCard: some View {
        EditorCard(title: "segment_distance".localized, icon: "ruler.fill", iconColor: DS.Colors.paceRun) {
            VStack(spacing: 12) {
                // Mode toggle
                HStack(spacing: DS.Space.xs) {
                    DSPresetTile(title: "segment_uniform".localized, isSelected: !useCustomSegments) {
                        useCustomSegments = false
                        group.customSegments = nil
                    }
                    DSPresetTile(title: "segment_custom".localized, isSelected: useCustomSegments) {
                        useCustomSegments = true
                        if group.customSegments == nil || group.customSegments!.isEmpty {
                            initCustomSegments()
                        }
                    }
                }

                if !useCustomSegments {
                    // Uniform mode presets
                    HStack(spacing: DS.Space.xs) {
                        ForEach(PresetSegmentDistance.allCases) { preset in
                            DSPresetTile(title: preset.displayName, isSelected: group.segmentDistance == preset.rawValue) {
                                group.segmentDistance = preset.rawValue
                            }
                            .accessibilityIdentifier("pace_segment_distance_\(preset.rawValue)")
                        }
                    }
                    Divider()
                    HStack {
                        Text("custom".localized)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(DS.Colors.textSecondary)
                        Spacer()
                        HStack(spacing: 4) {
                            FloatingIntInputField(
                                placeholder: "50",
                                title: "segment_distance".localized,
                                value: $group.segmentDistance,
                                width: 60,
                                minValue: 1,
                                maxValue: PacePlanLimits.maxSegmentDistance
                            )
                            Text("meters".localized)
                                .font(.system(size: 14))
                                .foregroundStyle(DS.Colors.textSecondary)
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 12))
                                .foregroundStyle(DS.Colors.textTertiary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(DS.Colors.field)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(DS.Colors.fieldBorder, lineWidth: 1)
                        )
                    }
                }

                HStack {
                    Text("segment".localized)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(group.segmentCount)")
                        .font(.system(size: 15, weight: .medium, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(DS.Colors.textPrimary)
                    Text("segments".localized)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // Initialize custom segments from current uniform config
    private func initCustomSegments() {
        let distances = group.segmentDistanceValues()
        let timePerSeg = pickerTotalTime > 0 ? pickerTotalTime / Double(distances.count) : 30.0
        group.customSegments = distances.map { distance in
            CustomSegment(distance: distance, time: timePerSeg)
        }
    }

    private func customSegmentsCard(scrollProxy: ScrollViewProxy) -> some View {
        EditorCard(title: "segment_custom".localized, icon: "list.number", iconColor: DS.Colors.paceRun) {
            VStack(spacing: 10) {
                // Mode toggle (same as segmentCard)
                HStack(spacing: DS.Space.xs) {
                    DSPresetTile(title: "segment_uniform".localized, isSelected: !useCustomSegments) {
                        useCustomSegments = false
                        group.customSegments = nil
                    }
                    DSPresetTile(title: "segment_custom".localized, isSelected: useCustomSegments) {
                        useCustomSegments = true
                        if group.customSegments == nil || group.customSegments!.isEmpty {
                            initCustomSegments()
                        }
                    }
                }

                if let segments = group.customSegments {
                    HStack(spacing: 10) {
                        Text("segment".localized)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 30, alignment: .center)
                        Text("distance".localized)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.clear)
                            .frame(width: 14)
                        Text("time".localized)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("rest_time".localized)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 8)

                    ForEach(Array(segments.enumerated()), id: \.element.id) { idx, seg in
                        customSegmentRow(index: idx, segment: seg)
                    }

                    // Summary stats
                    VStack(spacing: 6) {
                        let totalDist = segments.reduce(0) { $0 + $1.distance }
                        let totalSec = segments.reduce(0.0) { $0 + $1.time }
                        let totalRest = segments.dropLast().reduce(0.0) { $0 + max(0, $1.restAfter) }
                        let remaining = group.totalDistance - totalDist

                        HStack(spacing: 0) {
                            // Total distance
                            VStack(spacing: 2) {
                                Text("\(totalDist)\("unit_meter_short".localized)")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(DS.Colors.paceRun)
                                Text("total_distance".localized)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)

                            Divider().frame(height: 28)

                            // Running time
                            VStack(spacing: 2) {
                                Text(formatSegTime(totalSec))
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(.green)
                                Text("run_time".localized)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)

                            Divider().frame(height: 28)

                            // Total workout time (run + rests)
                            VStack(spacing: 2) {
                                Text(formatSegTime(totalSec + totalRest))
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(.orange)
                                Text("total_time".localized)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.vertical, 8)
                        .background(DS.Colors.field)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                        if remaining != 0 {
                            HStack(spacing: 4) {
                                Image(systemName: remaining > 0 ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(remaining > 0 ? .orange : .green)
                                Text("\("distance_diff".localized): \(remaining > 0 ? "+" : "")\(remaining)\("unit_meter_short".localized)")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(remaining > 0 ? .orange : .green)
                            }
                        }

                        if let normalizedIntensityPercent,
                           let adjustedTotalSec = adjustedTimeForSelectedIntensity(totalSec) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(
                                    String(
                                        format: "training_intensity_target_time".localized,
                                        formatSegTime(totalSec)
                                    )
                                )
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                                Text(
                                    String(
                                        format: "training_intensity_effective_total_time".localized,
                                        normalizedIntensityPercent,
                                        formatSegTime(adjustedTotalSec)
                                    )
                                )
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(DS.Colors.paceRun)
                                .opacity(hasNonDefaultIntensity ? 1 : 0)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    // Add / remove buttons
                    HStack(spacing: 8) {
                        let canAddSegment = segments.count < PacePlanLimits.maxCustomSegments
                        Button(action: {
                            guard canAddSegment else { return }
                            let inherited = segments.last
                            let inheritedDistance = inherited?.distance ?? group.segmentDistance
                            let inheritedTime = inherited?.time ?? max(PacePlanLimits.minSegmentTimeSeconds, group.segmentTime)
                            let inheritedRest = inherited?.restAfter ?? 0
                            group.customSegments?.append(
                                CustomSegment(
                                    distance: min(PacePlanLimits.maxSegmentDistance, max(1, inheritedDistance)),
                                    time: min(PacePlanLimits.maxTotalTimeSeconds, max(PacePlanLimits.minSegmentTimeSeconds, inheritedTime)),
                                    restAfter: min(PacePlanLimits.maxSetRestSeconds, max(0, inheritedRest))
                                )
                            )
                            keepActionAnchorVisible(scrollProxy: scrollProxy, anchorID: customSegmentsActionAnchorID)
                        }) {
                            Label("segment_add".localized, systemImage: "plus")
                                .font(.system(size: 13, weight: .medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(DS.Colors.paceRun.opacity(0.1))
                                .foregroundStyle(DS.Colors.paceRun)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        .disabled(!canAddSegment)
                        if segments.count > 1 {
                            Button(action: {
                                group.customSegments?.removeLast()
                                keepActionAnchorVisible(scrollProxy: scrollProxy, anchorID: customSegmentsActionAnchorID)
                            }) {
                                Label("segment_remove".localized, systemImage: "minus")
                                    .font(.system(size: 13, weight: .medium))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(DS.Colors.error.opacity(0.1))
                                    .foregroundStyle(.red)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .id(customSegmentsActionAnchorID)
                }
            }
        }
    }

    private func keepActionAnchorVisible(scrollProxy: ScrollViewProxy, anchorID: String) {
        DispatchQueue.main.async {
            var transaction = Transaction()
            transaction.animation = nil
            withTransaction(transaction) {
                scrollProxy.scrollTo(anchorID, anchor: .bottom)
            }
        }
    }

    @ViewBuilder
    private func customSegmentRow(index: Int, segment: CustomSegment) -> some View {
        HStack(spacing: 10) {
            // Number circle
            ZStack {
                Circle()
                    .fill(DS.Colors.paceRun.opacity(0.15))
                    .frame(width: 28, height: 28)
                Text("\(index + 1)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(DS.Colors.paceRun)
            }
            .frame(width: 30)

            // Distance chip (tappable)
            Button {
                beginEditDistance(index)
            } label: {
                HStack(spacing: 2) {
                    Text("\(segment.distance)")
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text("unit_meter_short".localized)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(DS.Colors.field)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)

            // Arrow
            Image(systemName: "arrow.right")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)
                .frame(width: 14)

            // Time chip (tappable)
            Button {
                beginEditTime(index)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(formatSegTime(segment.time))
                        .font(.system(size: 15, weight: .semibold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                        .allowsTightening(true)
                    if let adjustedTime = adjustedTimeForSelectedIntensity(segment.time) {
                        Text("-> \(formatSegTime(adjustedTime))")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .opacity(hasNonDefaultIntensity ? 1 : 0)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(DS.Colors.field)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)

            // Rest chip (tappable)
            if index < max(0, (group.customSegments?.count ?? 0) - 1) {
                Button {
                    beginEditRest(index)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text(formatSegTime(max(0, segment.restAfter)))
                            .font(.system(size: 14, weight: .semibold))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                            .allowsTightening(true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(DS.Colors.field)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            } else {
                Text("segment_end".localized)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(DS.Colors.field)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .background(DS.Colors.field.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Segment Value Editor Sheet

    @ViewBuilder
    private var segmentValueEditorSheet: some View {
        if let field = editingField {
            let idx = field.segmentIndex
            VStack(spacing: 12) {
                // Header bar
                HStack {
                    Button("cancel".localized) {
                        editingField = nil
                        editText = ""
                    }
                    Spacer()
                    Text(field.isDistance ? "distance".localized : (field.isRest ? "rest_time".localized : "time".localized))
                        .font(.system(size: 15, weight: .semibold))
                    Spacer()
                    Button("confirm".localized) {
                        applySegmentEdit(field)
                        editingField = nil
                        editText = ""
                    }
                    .fontWeight(.semibold)
                    .disabled(editText.isEmpty)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                // Current value
                HStack {
                    Text("current_value".localized)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if field.isDistance, let seg = group.customSegments?[idx] {
                        Text("\(seg.distance)\("unit_meter_short".localized)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                    } else if field.isRest, let seg = group.customSegments?[idx] {
                        Text(formatSegTime(seg.restAfter))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                    } else if let seg = group.customSegments?[idx] {
                        Text(formatSegTime(seg.time))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 20)

                // Input field
                HStack(spacing: 8) {
                    TextField(
                        field.isDistance
                            ? "enter_meters".localized
                            : (field.isRest ? "enter_rest_seconds".localized : "enter_seconds".localized),
                        text: $editText
                    )
                    .keyboardType(field.isDistance ? .numberPad : .decimalPad)
                    .font(.system(size: 20, weight: .semibold))
                    .focused($segmentEditorFocused)

                    if !editText.isEmpty {
                        Button {
                            editText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
                .background(DS.Colors.field)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 20)
                .onAppear {
                    editText = ""
                    DispatchQueue.main.async {
                        segmentEditorFocused = true
                    }
                }

                if !field.isDistance {
                    Text("time_input_hint".localized)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20)
                }
            }
            .padding(.bottom, 8)
            .presentationDetents([.height(200)])
            .interactiveDismissDisabled(!editText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("done".localized) {
                        segmentEditorFocused = false
                    }
                }
            }
        }
    }

    private func applySegmentEdit(_ field: SegmentEditField) {
        // Normalize: replace comma with dot for locales that use comma as decimal separator
        let trimmed = editText.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard !trimmed.isEmpty else { return }

        switch field {
        case .distance(let idx):
            if let val = Int(trimmed), val > 0 {
                group.customSegments?[idx].distance = val
            }
        case .time(let idx):
            if let val = Double(trimmed), val > 0 {
                group.customSegments?[idx].time = val
            }
        case .rest(let idx):
            if let val = Double(trimmed), val >= 0 {
                group.customSegments?[idx].restAfter = val
            }
        }
    }

    private func beginEditDistance(_ idx: Int) {
        editText = ""
        editingField = .distance(idx)
    }

    private func beginEditTime(_ idx: Int) {
        editText = ""
        editingField = .time(idx)
    }

    private func beginEditRest(_ idx: Int) {
        editText = ""
        editingField = .rest(idx)
    }

    private func formatSegTime(_ t: Double) -> String {
        var totalCs = Int((max(0, t) * 100).rounded())
        let m = totalCs / 6000
        totalCs %= 6000
        let s = totalCs / 100
        let cs = totalCs % 100
        if m > 0 {
            return cs > 0 ? "\(m)'\(String(format: "%02d", s)).\(String(format: "%02d", cs))\"" : "\(m)'\(String(format: "%02d", s))\""
        }
        return cs > 0
            ? "\(s).\(String(format: "%02d", cs))\("sec_label".localized)"
            : "\(s)\("sec_label".localized)"
    }

    private func normalizeIntensityInput(_ input: String) -> String {
        TrainingIntensity.sanitizeInput(input)
    }

    private var timeCard: some View {
        EditorCard(title: "total_time".localized, icon: "timer", iconColor: .green) {
            VStack(spacing: 14) {
                // MM : SS . cc  wheel picker
                HStack(spacing: 0) {
                    // Minutes
                    Picker("", selection: $pickerMinutes) {
                        ForEach(0..<60) { m in
                            Text("\(m)").tag(m)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    .clipped()

                    Text("min_label".localized)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 2)

                    // Seconds
                    Picker("", selection: $pickerSeconds) {
                        ForEach(0..<60) { s in
                            Text(String(format: "%02d", s)).tag(s)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    .clipped()

                    Text("sec_label".localized)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 2)

                    // Centiseconds
                    Picker("", selection: $pickerCenti) {
                        ForEach(Array(stride(from: 0, through: 99, by: 1)), id: \.self) { c in
                            Text(String(format: "%02d", c)).tag(c)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    .clipped()

                    Text("cs_label".localized)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 2)
                }
                .frame(height: 140)
                .onChange(of: pickerMinutes) { _, _ in distributeTimeToSegments() }
                .onChange(of: pickerSeconds) { _, _ in distributeTimeToSegments() }
                .onChange(of: pickerCenti)   { _, _ in distributeTimeToSegments() }

                Divider()

                // Live stats row
                HStack(spacing: 0) {
                    liveStatCell(label: speedUnit == 1 ? "pace".localized : "speed".localized,
                                 value: liveFormatPace(), color: .orange)
                        .onTapGesture {
                            speedUnit = (speedUnit + 1) % 3
                            var settings = StorageManager.shared.loadSettings()
                            settings.speedUnit = speedUnit
                            StorageManager.shared.saveSettings(settings)
                        }
                    Divider().frame(height: 36)
                    liveStatCell(
                        label: "segment_time".localized,
                        value: liveSegmentTime(),
                        secondaryValue: hasNonDefaultIntensity ? liveEffectiveSegmentTime() : nil,
                        color: .green
                    )
                    Divider().frame(height: 36)
                    liveStatCell(label: "segment".localized, value: "\(group.segmentCount)", color: DS.Colors.paceRun)
                }
                .padding(.vertical, 4)
                .background(DS.Colors.field)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private var intensityCard: some View {
        EditorCard(title: "model_400_intensity".localized, icon: "dial.high.fill", iconColor: DS.Colors.paceRun) {
            VStack(alignment: .leading, spacing: 10) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                    ForEach(quickIntensityOptions, id: \.self) { option in
                        Button {
                            intensityText = TrainingIntensity.displayText(option)
                        } label: {
                            Text("\(TrainingIntensity.displayText(option))%")
                                .font(.system(size: 13, weight: .medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    TrainingIntensity.isQuickSelected(
                                        currentPercent: parsedIntensityPercent,
                                        option: option
                                    ) ? DS.Colors.field : Color.clear
                                )
                                .foregroundStyle(
                                    TrainingIntensity.isQuickSelected(
                                        currentPercent: parsedIntensityPercent,
                                        option: option
                                    ) ? DS.Colors.textPrimary : DS.Colors.textSecondary
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                                        .stroke(
                                            TrainingIntensity.isQuickSelected(
                                                currentPercent: parsedIntensityPercent,
                                                option: option
                                            ) ? DS.Colors.border : Color.clear,
                                            lineWidth: 1
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack {
                    Text("model_400_intensity_custom".localized)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(DS.Colors.textSecondary)
                    Spacer()
                    HStack(spacing: 4) {
                        FloatingTextInputField(
                            placeholder: "100",
                            title: "model_400_intensity".localized,
                            value: $intensityText,
                            width: 68,
                            keyboardType: .decimalPad,
                            allowEmpty: false,
                            normalize: normalizeIntensityInput
                        )
                        Text("%")
                            .font(.system(size: 14))
                            .foregroundStyle(DS.Colors.textSecondary)
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 12))
                            .foregroundStyle(DS.Colors.textTertiary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(DS.Colors.field)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(DS.Colors.fieldBorder, lineWidth: 1)
                    )
                }

                Text("model_400_intensity_hint".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(
                    String(
                        format: "training_intensity_target_time".localized,
                        formatSegTime(baseTotalTimeAtHundredPercent)
                    )
                )
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

                if let normalizedIntensityPercent, let effectiveTotalTimeForSelectedIntensity {
                    Text(
                        String(
                            format: "training_intensity_effective_total_time".localized,
                            normalizedIntensityPercent,
                            formatSegTime(effectiveTotalTimeForSelectedIntensity)
                        )
                    )
                    .font(.caption.weight(.medium))
                    .foregroundStyle(DS.Colors.paceRun)
                }
            }
        }
    }

    @ViewBuilder
    private func liveStatCell(label: String, value: String, secondaryValue: String? = nil, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            if let secondaryValue {
                Text("-> \(secondaryValue)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private func liveFormatPace() -> String {
        let t = pickerTotalTime
        guard group.totalDistance > 0, t > 0 else { return "--" }
        switch speedUnit {
        case 0: // m/s
            return String(format: "%.2f %@", Double(group.totalDistance) / t, "m_per_s".localized)
        case 2: // km/h
            return String(format: "%.1f %@", Double(group.totalDistance) / t * 3.6, "km_per_h".localized)
        default: // min/km
            let ps = t / Double(group.totalDistance) * 1000
            return String(format: "%d:%02d%@", Int(ps) / 60, Int(ps) % 60, "/km".localized)
        }
    }

    private func liveSegmentTime() -> String {
        let t = pickerTotalTime
        guard group.segmentCount > 0, t > 0 else { return "--" }
        let seg = t / Double(group.segmentCount)
        return formatSegTime(seg)
    }

    private func liveEffectiveSegmentTime() -> String {
        guard group.segmentCount > 0,
              let effectiveTotalTimeForSelectedIntensity else { return "--" }
        let seg = effectiveTotalTimeForSelectedIntensity / Double(group.segmentCount)
        return formatSegTime(seg)
    }

    private var countdownCard: some View {
        EditorCard(title: "run_rest_countdown".localized, icon: "clock.badge.checkmark.fill", iconColor: DS.Colors.rest) {
            VStack(spacing: 10) {
                HStack(spacing: DS.Space.xs) {
                    ForEach([3, 5, 10, 15, 20], id: \.self) { sec in
                        DSPresetTile(
                            title: "\(sec)\("sec_label".localized)",
                            isSelected: group.countdownSeconds == sec
                        ) {
                            group.countdownSeconds = sec
                        }
                    }
                }

                HStack {
                    Text("custom".localized)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(DS.Colors.textSecondary)
                    Spacer()
                    HStack(spacing: 4) {
                        FloatingIntInputField(
                            placeholder: "20",
                            title: "run_rest_countdown".localized,
                            value: $group.countdownSeconds,
                            width: 60,
                            minValue: 1,
                            maxValue: PacePlanLimits.maxCountdown
                        )
                        Text("sec_label".localized)
                            .font(.system(size: 14))
                            .foregroundStyle(DS.Colors.textSecondary)
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 12))
                            .foregroundStyle(DS.Colors.textTertiary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(DS.Colors.field)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(DS.Colors.fieldBorder, lineWidth: 1)
                    )
                }
            }
        }
    }

    private var setCard: some View {
        EditorCard(title: "set_loop".localized, icon: "repeat", iconColor: DS.Colors.paceRun) {
            VStack(spacing: 10) {
                HStack {
                    Text("set_count".localized)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(DS.Colors.textSecondary)
                    Spacer()
                    HStack(spacing: 4) {
                        FloatingIntInputField(
                            placeholder: "1",
                            title: "set_count".localized,
                            value: Binding(
                                get: { group.setCount ?? 1 },
                                set: { group.setCount = min(PacePlanLimits.maxSetCount, max(1, $0)) }
                            ),
                            width: 60,
                            minValue: 1,
                            maxValue: PacePlanLimits.maxSetCount
                        )
                        Text("set_unit".localized)
                            .font(.system(size: 14))
                            .foregroundStyle(DS.Colors.textSecondary)
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 12))
                            .foregroundStyle(DS.Colors.textTertiary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(DS.Colors.field)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(DS.Colors.fieldBorder, lineWidth: 1)
                    )
                }

                HStack {
                    Text("inter_set_rest".localized)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(DS.Colors.textSecondary)
                    Spacer()
                    HStack(spacing: 4) {
                        FloatingDoubleInputField(
                            placeholder: "0.00",
                            title: "inter_set_rest".localized,
                            value: Binding(
                                get: { group.setRestTime ?? 0 },
                                set: { group.setRestTime = min(PacePlanLimits.maxSetRestSeconds, max(0, $0)) }
                            ),
                            width: 70,
                            minValue: 0,
                            maxValue: PacePlanLimits.maxSetRestSeconds,
                            precision: 0...2
                        )
                        Text("sec_label".localized)
                            .font(.system(size: 14))
                            .foregroundStyle(DS.Colors.textSecondary)
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 12))
                            .foregroundStyle(DS.Colors.textTertiary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(DS.Colors.field)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(DS.Colors.fieldBorder, lineWidth: 1)
                    )
                }
            }
        }
    }

    private var colorCard: some View {
        EditorCard(title: "group_color".localized, icon: "paintpalette.fill", iconColor: Color(hex: group.colorHex) ?? .orange) {
            HStack(spacing: 12) {
                ForEach(GroupColor.allCases) { gc in
                    let c = Color(hex: gc.rawValue) ?? .orange
                    let selected = group.colorHex == gc.rawValue
                    Button(action: { group.colorHex = gc.rawValue }) {
                        ZStack {
                            Circle().fill(c)
                            if selected {
                                Circle()
                                    .strokeBorder(.white, lineWidth: 2.5)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(width: 38, height: 38)
                    }
                    .buttonStyle(.plain)
                    .animation(.easeOut(duration: 0.16), value: selected)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var soundCard: some View {
        EditorCard(title: "sound_settings".localized, icon: "speaker.wave.2.fill", iconColor: DS.Colors.paceRun) {
            VStack(spacing: 0) {
                soundRow(label: "start_sound".localized, selection: $group.startSound, identifier: "pace_cue_start_row")
                Divider().padding(.leading, 4)
                soundRow(label: "segment_sound".localized, selection: $group.segmentSound, identifier: "pace_cue_segment_row")
                Divider().padding(.leading, 4)
                soundRow(label: "end_sound".localized, selection: $group.endSound, identifier: "pace_cue_end_row")
            }
        }
    }

    private func soundRow(label: String, selection: Binding<SoundType>, identifier: String) -> some View {
        SoundCueRow(label: label, selection: selection, identifier: identifier)
    }

    private func normalizeGroupForSave(_ input: PaceRunGroup) -> PaceRunGroup {
        var normalized = input
        normalized.name = normalized.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? PaceRunGroup.defaultName : normalized.name
        normalized.countdownSeconds = min(PacePlanLimits.maxCountdown, max(1, normalized.countdownSeconds))
        normalized.setCount = min(PacePlanLimits.maxSetCount, max(1, normalized.setCount ?? 1))
        normalized.setRestTime = min(PacePlanLimits.maxSetRestSeconds, max(0, normalized.setRestTime ?? 0))
        normalized.intensityPercent = TrainingIntensity.clampedPercent(normalized.intensityPercent)

        normalized.totalDistance = min(PacePlanLimits.maxTotalDistance, max(1, normalized.totalDistance))
        normalized.segmentDistance = min(PacePlanLimits.maxSegmentDistance, max(1, normalized.segmentDistance))
        normalized.totalTime = min(PacePlanLimits.maxTotalTimeSeconds, max(PacePlanLimits.minSegmentTimeSeconds, normalized.totalTime))

        if let customSegments = normalized.customSegments, !customSegments.isEmpty {
            let trimmed = Array(customSegments.prefix(PacePlanLimits.maxCustomSegments)).map { segment in
                CustomSegment(
                    id: segment.id,
                    distance: min(PacePlanLimits.maxSegmentDistance, max(1, segment.distance)),
                    time: min(PacePlanLimits.maxTotalTimeSeconds, max(PacePlanLimits.minSegmentTimeSeconds, segment.time)),
                    restAfter: min(PacePlanLimits.maxSetRestSeconds, max(0, segment.restAfter))
                )
            }
            normalized.customSegments = trimmed
            normalized.totalDistance = min(PacePlanLimits.maxTotalDistance, trimmed.reduce(0) { $0 + $1.distance })
            normalized.totalTime = min(PacePlanLimits.maxTotalTimeSeconds, trimmed.reduce(0.0) { $0 + $1.time })
            normalized.segmentDistance = trimmed.first?.distance ?? normalized.segmentDistance
            normalized.segmentTime = normalized.totalTime / Double(max(1, trimmed.count))
        } else {
            normalized.customSegments = nil
            normalized.segmentTime = max(PacePlanLimits.minSegmentTimeSeconds, normalized.totalTime / Double(max(1, normalized.segmentCount)))
        }
        return normalized
    }
}

// MARK: - Editor Card container

struct EditorCard<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.lg) {
            HStack(spacing: DS.Space.sm) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(DS.Colors.textTertiary)

                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(DS.Colors.textPrimary)
            }
            content()
        }
        .dsCard()
    }
}

// MARK: - Saved Plan List View

struct SavedPlanListView: View {
    let trainingType: TrainingType
    let onSelect: (SavedPlan) -> Void
    @State private var plans: [SavedPlan] = []
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                if plans.isEmpty {
                    Section {
                        HStack {
                            Spacer()
                            VStack(spacing: 12) {
                                Image(systemName: "folder.badge.questionmark")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.secondary)
                                Text("no_saved_plans".localized)
                                    .font(.system(size: 15))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 40)
                            Spacer()
                        }
                    }
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(plans) { plan in
                        Button(action: { onSelect(plan) }) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(plan.name)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.primary)
                                Text(plan.updatedAt, style: .date)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                StorageManager.shared.deletePlan(plan)
                                loadPlans()
                            } label: {
                                Label("delete_plan".localized, systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("saved_plans".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("cancel".localized) { dismiss() }
                }
            }
            .onAppear(perform: loadPlans)
        }
    }

    private func loadPlans() {
        plans = StorageManager.shared.loadPlans().filter { $0.trainingType == trainingType }
    }
}

#Preview { NavigationStack { PaceRunSetupView() } }
