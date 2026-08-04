import SwiftUI

private enum IntervalPlanLimits {
    static let maxCountdown = 60
    static let maxSetCount = 200
    static let maxRepetitions = 300
    static let maxCustomRepeats = 300
    static let maxRunDistance = 100_000
    static let maxRunTimeSeconds = 24 * 60 * 60
    static let maxRestTimeSeconds = 24 * 60 * 60
    static let maxSetRestSeconds: Double = 3_600
}

// MARK: - Setup View

struct IntervalTrainingSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var localization = LocalizationManager.shared
    let isQuickStart: Bool
    @State private var training = IntervalTraining()
    @State private var editingGroup: IntervalGroup?
    @State private var trainingToStart: IntervalTraining?
    @State private var historyLaunchSession: IntervalLaunchSession?
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
    init(isQuickStart: Bool = false) {
        self.isQuickStart = isQuickStart
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
        .background(TrainingPageBackground())
        .navigationTitle("interval_training".localized)
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
                    .accessibilityIdentifier("interval_add_plan_toolbar_button")
                }
            }
        }
        .sheet(item: $editingGroup) { group in
            IntervalGroupEditorView(group: group) { saved in
                if let idx = training.groups.firstIndex(where: { $0.id == saved.id }) {
                    training.groups[idx] = saved
                } else {
                    training.groups.append(saved)
                    selectedGroupIDs.insert(saved.id)
                }
                persistTraining()
                syncSelectedGroups()
            }
        }
        .fullScreenCover(item: $trainingToStart, onDismiss: handleTrainingDismiss) { launchTraining in
            IntervalTrainingView(training: launchTraining)
        }
        .fullScreenCover(item: $historyLaunchSession, onDismiss: handleTrainingDismiss) { launchSession in
            IntervalBatchTrainingView(session: launchSession)
        }
        .onAppear {
            guard !didLoad else { return }
            didLoad = true
            if !isQuickStart, let saved = StorageManager.shared.loadIntervalTrainingSingle() {
                training = normalizedTraining(saved)
            }
            if isQuickStart, training.groups.isEmpty {
                initializeQuickStartTrainingIfNeeded()
            }
            syncSelectedGroups(autoSelectAllIfEmpty: true)
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
        VStack(spacing: 16) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.08))
                    .frame(width: 100, height: 100)
                Image(systemName: "repeat.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.orange.opacity(0.6))
            }
            Text("add_plan".localized)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.primary)
            Text("interval_training_desc".localized)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 48)
            if !isHistoryTab {
                Button(action: createNewPlan) {
                    Label("add_plan".localized, systemImage: "plus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(minWidth: 160, minHeight: 46)
                        .background(Color.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("interval_add_plan_empty_button")
            }
            Spacer()
        }
    }

    private var isHistoryTab: Bool {
        !isQuickStart && activeTab == .history
    }

    private var tabSwitcher: some View {
        Picker("", selection: $activeTab) {
            Text("plan_create_tab".localized)
                .tag(SetupTab.create)
            Text("plan_history_tab".localized)
                .tag(SetupTab.history)
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("interval_setup_tab_picker")
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
                            .tint(.orange)
                            .accessibilityIdentifier("interval_history_edit_button")

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
        let decoded = decodeIntervalPlan(plan)
        let groupCount = decoded?.groups.count ?? 0
        let totalReps = decoded?.groups.reduce(0) { $0 + max(1, $1.effectiveRepetitions) } ?? 0
        let plannedDuration = decoded?.plannedSessionDuration() ?? 0
        let accentColor = Color(hex: decoded?.groups.first?.colorHex ?? "") ?? .orange
        let title = decoded.map { inferredPlanName(groups: $0.groups) } ?? plan.name
        return Button {
            if isSelected {
                selectedHistoryPlanIDs.remove(plan.id)
            } else {
                selectedHistoryPlanIDs.insert(plan.id)
            }
        } label: {
            HStack(alignment: .center, spacing: 14) {
                TrainingSelectionIndicator(isSelected: isSelected, accent: DS.Colors.interval)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Circle()
                            .fill(accentColor)
                            .frame(width: 10, height: 10)

                        Text(title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)

                        Spacer(minLength: 8)

                        Text(formattedDateTime(plan.lastUsedAt))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    HStack(spacing: 10) {
                        StatChip(icon: "repeat", value: "\(totalReps)\("repetitions".localized)")
                        StatChip(icon: "clock", value: formatDuration(plannedDuration))
                        StatChip(icon: "square.stack.3d.up", value: "\(groupCount)\("groups".localized)")
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .trainingSelectableCardContainer(
                accent: DS.Colors.interval,
                isSelected: isSelected,
                cornerRadius: 16
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Groups List
    private var groupsList: some View {
        List {
            ForEach(training.groups) { group in
                IntervalGroupCard(group: group, isSelected: selectedGroupIDs.contains(group.id)) {
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
        return VStack(spacing: 10) {
            Button(action: isHistoryTab ? startSelectedHistoryPlan : startSelectedTraining) {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text(buttonTitle)
                        .font(.system(size: 17, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .foregroundStyle(canStart ? Color.white : DS.Colors.textTertiary)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .trainingPrimaryActionSurface(
                    isEnabled: canStart,
                    colors: [DS.Colors.interval]
                )
            }
            .disabled(!canStart)
            .accessibilityIdentifier("interval_start_training_button")
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 28)
        .background(
            DS.Colors.card
                .overlay(alignment: .top) { Rectangle().fill(DS.Colors.border).frame(height: 1) }
        )
    }

    private func addGroup() {
        var g = IntervalGroup()
        g.sortOrder = training.groups.count
        g.colorHex = GroupColor.allCases[training.groups.count % GroupColor.allCases.count].rawValue
        let sound = SoundType.allCases[training.groups.count % SoundType.allCases.count]
        g.startSound = sound
        g.restSound = sound
        g.endSound = sound
        editingGroup = g
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

        let launchPlans = TrainingLaunchFactory.makeIntervalHistoryLaunchPlans(
            from: plansToStart,
            runtimeCountdownSeconds: runtimeCountdown,
            decode: decodeIntervalPlan(_:),
            fallbackTitle: { training, savedPlan in
                savedPlan.name.isEmpty ? inferredPlanName(groups: training.groups) : savedPlan.name
            }
        )
        guard !launchPlans.isEmpty else { return }
        if launchPlans.count == 1, let first = launchPlans.first {
            trainingToStart = first.training
        } else {
            historyLaunchSession = IntervalLaunchSession(plans: launchPlans)
        }
        refreshHistoryPlans(selectFirstIfNeeded: false)
    }

    private func applyHistoryPlan(_ plan: SavedPlan) {
        guard let decoded = decodeIntervalPlan(plan) else { return }
        training = normalizedTraining(decoded)
        copiedHistoryPlanSourceID = nil
        persistTraining()
        syncSelectedGroups(autoSelectAllIfEmpty: true)
        selectedHistoryPlanIDs = [plan.id]
        activeTab = .create
    }

    private func editHistoryPlanAsCopy(_ plan: SavedPlan) {
        guard let decoded = decodeIntervalPlan(plan) else { return }
        training = normalizedTraining(decoded)
        copiedHistoryPlanSourceID = plan.id
        persistTraining()
        syncSelectedGroups(autoSelectAllIfEmpty: true)
        selectedHistoryPlanIDs = [plan.id]
        activeTab = .create
    }

    private func rememberPlanUsage(for planTraining: IntervalTraining) {
        guard let data = try? JSONEncoder().encode(planTraining) else { return }
        let name = inferredPlanName(groups: planTraining.groups)

        if copiedHistoryPlanSourceID != nil {
            let createdAt = Date()
            let newPlan = SavedPlan(
                name: name,
                trainingType: .intervalTraining,
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
            trainingType: .intervalTraining,
            configData: data,
            lastUsedAt: Date()
        )
        selectedHistoryPlanIDs = [updated.id]
        refreshHistoryPlans(selectFirstIfNeeded: true)
    }

    private func refreshHistoryPlans(selectFirstIfNeeded: Bool = false) {
        historyPlans = StorageManager.shared.loadPlans().filter { $0.trainingType == .intervalTraining }
        selectedHistoryPlanIDs = selectedHistoryPlanIDs.intersection(Set(historyPlans.map(\.id)))
        if selectFirstIfNeeded && selectedHistoryPlanIDs.isEmpty, let first = historyPlans.first {
            selectedHistoryPlanIDs = [first.id]
        }
    }

    private func inferredPlanName(groups: [IntervalGroup]) -> String {
        if groups.isEmpty { return "interval_training".localized }
        if groups.count == 1 { return groups[0].name }
        return "\(groups[0].name) +\(groups.count - 1)"
    }

    private func formattedDateTime(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    private func decodeIntervalPlan(_ plan: SavedPlan) -> IntervalTraining? {
        guard let decoded = try? JSONDecoder().decode(IntervalTraining.self, from: plan.configData) else { return nil }
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

    private func duplicateGroup(_ group: IntervalGroup) {
        var copied = group
        copied.id = UUID()
        copied.name = "\(group.name) \("group_copy_suffix".localized)"
        copied.sortOrder = training.groups.count
        training.groups.append(copied)
        selectedGroupIDs.insert(copied.id)
        persistTraining()
    }

    private func deleteGroup(_ group: IntervalGroup) {
        training.groups.removeAll { $0.id == group.id }
        selectedGroupIDs.remove(group.id)
        persistTraining()
        syncSelectedGroups()
    }

    private func persistTraining() {
        guard !isQuickStart else { return }
        StorageManager.shared.saveIntervalTrainingSingle(training)
    }

    private func initializeQuickStartTrainingIfNeeded() {
        guard isQuickStart, training.groups.isEmpty else { return }
        var defaultGroup = IntervalGroup()
        defaultGroup.sortOrder = 0
        defaultGroup.colorHex = GroupColor.allCases[0].rawValue
        let sound = SoundType.allCases[0]
        defaultGroup.startSound = sound
        defaultGroup.restSound = sound
        defaultGroup.endSound = sound
        training = IntervalTraining(
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

    private func syncSelectedGroups(autoSelectAllIfEmpty: Bool = false) {
        let existing = Set(training.groups.map { $0.id })
        selectedGroupIDs = selectedGroupIDs.intersection(existing)
        if autoSelectAllIfEmpty && selectedGroupIDs.isEmpty {
            selectedGroupIDs = existing
        }
    }

    private func normalizedTraining(_ value: IntervalTraining) -> IntervalTraining {
        var fixed = value
        fixed.countdownSeconds = min(IntervalPlanLimits.maxCountdown, max(1, fixed.countdownSeconds))
        for idx in fixed.groups.indices {
            fixed.groups[idx].countdownSeconds = min(IntervalPlanLimits.maxCountdown, max(1, fixed.groups[idx].countdownSeconds ?? 3))
            fixed.groups[idx].setCount = min(IntervalPlanLimits.maxSetCount, max(1, fixed.groups[idx].setCount ?? 1))
            fixed.groups[idx].setRestTime = min(IntervalPlanLimits.maxSetRestSeconds, max(0, fixed.groups[idx].setRestTime ?? 0))
            fixed.groups[idx].intensityPercent = TrainingIntensity.clampedPercent(fixed.groups[idx].intensityPercent)
            fixed.groups[idx].runDistance = min(IntervalPlanLimits.maxRunDistance, max(1, fixed.groups[idx].runDistance))
            fixed.groups[idx].runTime = min(IntervalPlanLimits.maxRunTimeSeconds, max(1, fixed.groups[idx].runTime))
            fixed.groups[idx].restTime = min(IntervalPlanLimits.maxRestTimeSeconds, max(0, fixed.groups[idx].restTime))
            fixed.groups[idx].repetitions = min(IntervalPlanLimits.maxRepetitions, max(1, fixed.groups[idx].repetitions))
            if let customRepeats = fixed.groups[idx].customRepeats, !customRepeats.isEmpty {
                fixed.groups[idx].customRepeats = Array(customRepeats.prefix(IntervalPlanLimits.maxCustomRepeats)).map {
                    IntervalRepeatConfig(
                        id: $0.id,
                        runTime: min(Double(IntervalPlanLimits.maxRunTimeSeconds), max(1, $0.runTime)),
                        restTime: min(Double(IntervalPlanLimits.maxRestTimeSeconds), max(0, $0.restTime))
                    )
                }
                fixed.groups[idx].repetitions = fixed.groups[idx].customRepeats?.count ?? fixed.groups[idx].repetitions
            }
        }
        return fixed
    }

    private var startCountdownCard: some View {
        EditorCard(title: "countdown".localized, icon: "clock.badge.checkmark.fill", iconColor: .cyan) {
            HStack(spacing: 8) {
                ForEach([3, 5, 10, 15, 20], id: \.self) { sec in
                    Button(action: { training.countdownSeconds = sec }) {
                        Text("\(sec)\("sec_label".localized)")
                            .font(.system(size: 14, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(training.countdownSeconds == sec ? Color.cyan : DS.Colors.cardHover)
                            .foregroundStyle(training.countdownSeconds == sec ? .white : .primary)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Group Card

struct IntervalGroupCard: View {
    let group: IntervalGroup
    let isSelected: Bool
    let onEdit: () -> Void
    let onToggleSelect: () -> Void
    let onDuplicate: () -> Void

    private var groupColor: Color { Color(hex: group.colorHex) ?? .orange }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Button(action: onToggleSelect) {
                TrainingSelectionIndicator(isSelected: isSelected, accent: DS.Colors.interval)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isSelected ? "a11y_deselect_group".localized : "a11y_select_group".localized)
            .accessibilityIdentifier("interval_group_select_\(group.id.uuidString)")

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Circle()
                        .fill(groupColor)
                        .frame(width: 10, height: 10)

                    Text(group.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Spacer(minLength: 8)

                    Text("\(group.effectiveRepetitions) \("repetitions".localized)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        StatChip(icon: "figure.run", value: "\(group.runDistance)\("unit_meter_short".localized)")
                        StatChip(icon: "clock", value: "\(group.runTime)\("sec_label".localized)/\(group.restTime)\("sec_label".localized)")
                        StatChip(icon: "speedometer", value: paceString)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            StatChip(icon: "figure.run", value: "\(group.runDistance)\("unit_meter_short".localized)")
                            StatChip(icon: "clock", value: "\(group.runTime)\("sec_label".localized)/\(group.restTime)\("sec_label".localized)")
                        }
                        StatChip(icon: "speedometer", value: paceString)
                    }
                }
            }

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                Button(action: onDuplicate) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.indigo)
                        .frame(width: 36, height: 36)
                        .background(Color.indigo.opacity(DS.Opacity.light))
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                }
                .accessibilityLabel("a11y_duplicate_group".localized)
                .accessibilityIdentifier("interval_group_duplicate_\(group.id.uuidString)")
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.orange)
                        .frame(width: 36, height: 36)
                        .background(Color.orange.opacity(DS.Opacity.light))
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                }
                .accessibilityLabel("a11y_edit_group".localized)
                .accessibilityIdentifier("interval_group_edit_\(group.id.uuidString)")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .trainingSelectableCardContainer(
            accent: DS.Colors.interval,
            isSelected: isSelected,
            cornerRadius: 16
        )
        .accessibilityIdentifier("interval_group_card_\(group.id.uuidString)")
    }

    private var paceString: String {
        guard group.runDistance > 0, group.runTime > 0 else { return "--" }
        let paceSeconds = Double(group.runTime) / Double(group.runDistance) * 1000
        return String(format: "%d:%02d/km", Int(paceSeconds) / 60, Int(paceSeconds) % 60)
    }
}

// MARK: - Group Editor

struct IntervalGroupEditorView: View {
    @Environment(\.dismiss) var dismiss
    @State var group: IntervalGroup
    let onSave: (IntervalGroup) -> Void
    let isNew: Bool

    @State private var runMin: Int = 0
    @State private var runSec: Int = 15
    @State private var restMin: Int = 0
    @State private var restSec: Int = 45
    @State private var speedUnit: Int = 0  // 0=m/s, 1=min/km, 2=km/h
    @State private var useCustomRepeats: Bool = false
    @State private var customRepeats: [IntervalRepeatConfig] = []
    @State private var editingRepeatField: RepeatEditField? = nil
    @State private var repeatEditText: String = ""
    @FocusState private var repeatEditorFocused: Bool
    private let customRepeatsActionAnchorID = "interval-custom-repeats-actions-anchor"
    @State private var intensityText = TrainingIntensity.displayText(TrainingIntensity.fullPercent)
    private let quickIntensityOptions = TrainingIntensity.quickOptions

    init(group: IntervalGroup, onSave: @escaping (IntervalGroup) -> Void) {
        self._group = State(initialValue: group)
        self.onSave = onSave
        self.isNew = group.name == IntervalGroup.defaultName
        let existing = group.customRepeats ?? []
        self._useCustomRepeats = State(initialValue: !existing.isEmpty)
        self._customRepeats = State(initialValue: existing)
    }

    enum RepeatEditField: Identifiable {
        case run(Int)
        case rest(Int)

        var id: String {
            switch self {
            case .run(let idx): return "run-\(idx)"
            case .rest(let idx): return "rest-\(idx)"
            }
        }

        var isRun: Bool {
            if case .run = self { return true }
            return false
        }

        var index: Int {
            switch self {
            case .run(let idx), .rest(let idx):
                return idx
            }
        }
    }

    private var runTotalSecs: Int { max(1, runMin * 60 + runSec) }
    private var restTotalSecs: Int { max(0, restMin * 60 + restSec) }
    private var customRepeatsValid: Bool {
        !customRepeats.isEmpty && customRepeats.allSatisfy { $0.runTime > 0 && $0.restTime >= 0 }
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

    private var baseRunTimeAtHundredPercent: Double {
        if useCustomRepeats, !customRepeats.isEmpty {
            return customRepeats.map { max(0, $0.runTime) }.reduce(0, +) / Double(customRepeats.count)
        }
        return Double(max(1, runTotalSecs))
    }

    private func adjustedRunTimeForSelectedIntensity(_ baseRunTimeAtHundredPercent: Double) -> Double? {
        guard let normalizedIntensityPercent else { return nil }
        return TrainingIntensity.adjustedTime(
            baseTimeAtHundredPercent: baseRunTimeAtHundredPercent,
            intensityPercent: normalizedIntensityPercent
        )
    }

    private var effectiveRunTimeForSelectedIntensity: Double? {
        adjustedRunTimeForSelectedIntensity(baseRunTimeAtHundredPercent)
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(spacing: 16) {
                        nameCard
                        distanceCard
                        modeCard
                        if useCustomRepeats {
                            customRepeatsCard(scrollProxy: scrollProxy)
                        } else {
                            runTimeCard
                            restTimeCard
                            repetitionsCard
                        }
                        intensityCard
                        countdownCard
                        setCard
                        livePaceRow
                        colorCard
                        soundCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
                .background(TrainingPageBackground())
                .navigationTitle(isNew ? "add_plan".localized : "edit_group".localized)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("cancel".localized) { dismiss() }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("save".localized) {
                            normalizeAndSave()
                        }
                        .fontWeight(.semibold)
                        .disabled((useCustomRepeats ? !customRepeatsValid : runTotalSecs <= 0) || normalizedIntensityPercent == nil)
                    }
                }
                .onAppear {
                    group = prepareGroupForEditor(group)
                    customRepeats = Array((group.customRepeats ?? []).prefix(IntervalPlanLimits.maxCustomRepeats))
                    syncPickersFromGroup()
                    intensityText = TrainingIntensity.displayText(group.intensityPercent)
                    speedUnit = StorageManager.shared.loadSettings().speedUnit
                    if useCustomRepeats && customRepeats.isEmpty {
                        customRepeats = defaultCustomRepeats()
                    }
                }
                .onChange(of: useCustomRepeats) { _, enabled in
                    if enabled, customRepeats.isEmpty {
                        customRepeats = defaultCustomRepeats()
                    }
                }
                .sheet(item: $editingRepeatField, onDismiss: {
                    repeatEditorFocused = false
                    repeatEditText = ""
                }) { _ in
                    repeatValueEditorSheet
                }
            }
        }
    }

    private var nameCard: some View {
        EditorCard(title: "plan_name".localized, icon: "tag.fill", iconColor: .orange) {
            HStack {
                FloatingTextInputField(
                    placeholder: "plan_name_placeholder".localized,
                    title: "plan_name".localized,
                    value: $group.name
                )
                Spacer()
            }
        }
    }

    private var distanceCard: some View {
        EditorCard(title: "run_distance".localized, icon: "arrow.right.circle.fill", iconColor: .orange) {
            VStack(spacing: 10) {
                let presets = [50, 100, 150, 200, 300, 400]
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(presets, id: \.self) { m in
                        Button(action: { group.runDistance = m }) {
                            Text("\(m)\("unit_meter_short".localized)")
                                .font(.system(size: 14, weight: .medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(group.runDistance == m ? Color.orange : DS.Colors.cardHover)
                                .foregroundStyle(group.runDistance == m ? .white : .primary)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
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
                            placeholder: "100",
                            title: "run_distance".localized,
                            value: $group.runDistance,
                            width: 72,
                            minValue: 1,
                            maxValue: IntervalPlanLimits.maxRunDistance
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

    private var modeCard: some View {
        EditorCard(title: "reps_label".localized, icon: "list.number", iconColor: .purple) {
            Toggle(isOn: $useCustomRepeats) {
                Text("custom_repeats_mode".localized)
                    .font(.system(size: 15, weight: .medium))
            }
            .toggleStyle(.switch)
        }
    }

    private var runTimeCard: some View {
        EditorCard(title: "run_time".localized, icon: "figure.run", iconColor: .green) {
            VStack(alignment: .leading, spacing: 10) {
                durationEditor(min: $runMin, sec: $runSec, presets: [10, 12, 15, 20, 25, 30, 40], tint: .green)
                Text(
                    String(
                        format: "training_intensity_target_time".localized,
                        formatRepeatTime(baseRunTimeAtHundredPercent)
                    )
                )
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                if let normalizedIntensityPercent, let effectiveRunTimeForSelectedIntensity {
                    Text(
                        String(
                            format: "training_intensity_effective_run_time".localized,
                            normalizedIntensityPercent,
                            formatRepeatTime(effectiveRunTimeForSelectedIntensity)
                        )
                    )
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.indigo)
                }
            }
        }
    }

    private var restTimeCard: some View {
        EditorCard(title: "rest_time".localized, icon: "pause.circle.fill", iconColor: .gray) {
            durationEditor(min: $restMin, sec: $restSec, presets: [0, 15, 20, 30, 45, 60, 90], tint: .gray)
        }
    }

    private var repetitionsCard: some View {
        EditorCard(title: "reps_label".localized, icon: "repeat", iconColor: .purple) {
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    ForEach([4, 6, 8, 10, 12, 15], id: \.self) { value in
                        Button(action: { group.repetitions = value }) {
                            Text("×\(value)")
                                .font(.system(size: 14, weight: .medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(group.repetitions == value ? Color.purple : DS.Colors.cardHover)
                                .foregroundStyle(group.repetitions == value ? .white : .primary)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
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
                            placeholder: "10",
                            title: "reps_label".localized,
                            value: $group.repetitions,
                            width: 60,
                            minValue: 1,
                            maxValue: IntervalPlanLimits.maxRepetitions,
                            accessibilityIdentifier: "interval_quick_reps_field"
                        )
                        Text("repetitions".localized)
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

    private var intensityCard: some View {
        EditorCard(title: "model_400_intensity".localized, icon: "dial.high.fill", iconColor: .indigo) {
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
                                    ) ? Color.indigo : DS.Colors.cardHover
                                )
                                .foregroundStyle(
                                    TrainingIntensity.isQuickSelected(
                                        currentPercent: parsedIntensityPercent,
                                        option: option
                                    ) ? .white : .primary
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 10))
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
                        formatRepeatTime(baseRunTimeAtHundredPercent)
                    )
                )
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

                if let normalizedIntensityPercent, let effectiveRunTimeForSelectedIntensity {
                    Text(
                        String(
                            format: "training_intensity_effective_run_time".localized,
                            normalizedIntensityPercent,
                            formatRepeatTime(effectiveRunTimeForSelectedIntensity)
                        )
                    )
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.indigo)
                }
            }
        }
    }

    private func customRepeatsCard(scrollProxy: ScrollViewProxy) -> some View {
        EditorCard(title: "custom_repeats_mode".localized, icon: "slider.horizontal.3", iconColor: .indigo) {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Text("repeat".localized)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 30, alignment: .center)
                    Text("run_time".localized)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.clear)
                        .frame(width: 14)
                    Text("rest_time".localized)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 8)

                ForEach(Array(customRepeats.enumerated()), id: \.element.id) { idx, rep in
                    customRepeatRow(index: idx, repeatConfig: rep)
                }

                if let normalizedIntensityPercent,
                   let effectiveRunTimeForSelectedIntensity {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(
                            String(
                                format: "training_intensity_target_time".localized,
                                formatRepeatTime(baseRunTimeAtHundredPercent)
                            )
                        )
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        Text(
                            String(
                                format: "training_intensity_effective_run_time".localized,
                                normalizedIntensityPercent,
                                formatRepeatTime(effectiveRunTimeForSelectedIntensity)
                            )
                        )
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.indigo)
                        .opacity(hasNonDefaultIntensity ? 1 : 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                }

                HStack(spacing: 8) {
                    let canAddRepeat = customRepeats.count < IntervalPlanLimits.maxCustomRepeats
                    Button {
                        guard canAddRepeat else { return }
                        let inherited = customRepeats.last
                        let inheritedRun = inherited?.runTime ?? Double(max(1, runTotalSecs))
                        let inheritedRest = inherited?.restTime ?? Double(max(0, restTotalSecs))
                        customRepeats.append(
                            IntervalRepeatConfig(
                                runTime: min(Double(IntervalPlanLimits.maxRunTimeSeconds), max(0.1, inheritedRun)),
                                restTime: min(Double(IntervalPlanLimits.maxRestTimeSeconds), max(0, inheritedRest))
                            )
                        )
                        keepActionAnchorVisible(scrollProxy: scrollProxy, anchorID: customRepeatsActionAnchorID)
                    } label: {
                        Label("repeat_add".localized, systemImage: "plus")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.indigo.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canAddRepeat)

                    if customRepeats.count > 1 {
                        Button {
                            customRepeats.removeLast()
                            keepActionAnchorVisible(scrollProxy: scrollProxy, anchorID: customRepeatsActionAnchorID)
                        } label: {
                            Label("repeat_remove".localized, systemImage: "minus")
                                .font(.system(size: 14, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.red.opacity(0.1))
                                .foregroundStyle(.red)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .id(customRepeatsActionAnchorID)
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
    private func customRepeatRow(index: Int, repeatConfig: IntervalRepeatConfig) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.indigo.opacity(0.15))
                    .frame(width: 28, height: 28)
                Text("\(index + 1)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.indigo)
            }
            .frame(width: 30)

            Button {
                beginEditRun(index)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "figure.run")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(formatRepeatTime(repeatConfig.runTime))
                            .font(.system(size: 15, weight: .semibold))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                            .allowsTightening(true)
                        if let adjustedRunTime = adjustedRunTimeForSelectedIntensity(repeatConfig.runTime) {
                            Text("-> \(formatRepeatTime(adjustedRunTime))")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .opacity(hasNonDefaultIntensity ? 1 : 0)
                        }
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

            Image(systemName: "arrow.right")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)
                .frame(width: 14)

            if index < customRepeats.count - 1 {
                Button {
                    beginEditRest(index)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text(formatRepeatTime(max(0, repeatConfig.restTime)))
                            .font(.system(size: 15, weight: .semibold))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                            .allowsTightening(true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
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
                    .padding(.horizontal, 12)
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

    @ViewBuilder
    private var repeatValueEditorSheet: some View {
        if let field = editingRepeatField {
            let idx = field.index
            VStack(spacing: 12) {
                HStack {
                    Button("cancel".localized) {
                        editingRepeatField = nil
                        repeatEditText = ""
                    }
                    Spacer()
                    Text(field.isRun ? "run_time".localized : "rest_time".localized)
                        .font(.system(size: 15, weight: .semibold))
                    Spacer()
                    Button("confirm".localized) {
                        applyRepeatEdit(field)
                        editingRepeatField = nil
                        repeatEditText = ""
                    }
                    .fontWeight(.semibold)
                    .disabled(repeatEditText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                HStack {
                    Text("current_value".localized)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if idx >= 0, idx < customRepeats.count {
                        let current = field.isRun ? customRepeats[idx].runTime : customRepeats[idx].restTime
                        Text(formatRepeatTime(current))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 20)

                HStack(spacing: 8) {
                    TextField(field.isRun ? "enter_seconds".localized : "enter_rest_seconds".localized, text: $repeatEditText)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 20, weight: .semibold))
                        .focused($repeatEditorFocused)

                    if !repeatEditText.isEmpty {
                        Button {
                            repeatEditText = ""
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
                    repeatEditText = ""
                    DispatchQueue.main.async {
                        repeatEditorFocused = true
                    }
                }

                Text("time_input_hint".localized)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
            }
            .padding(.bottom, 8)
            .presentationDetents([.height(220)])
            .interactiveDismissDisabled(!repeatEditText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("done".localized) {
                        repeatEditorFocused = false
                    }
                }
            }
        }
    }

    private var countdownCard: some View {
        EditorCard(title: "run_rest_countdown".localized, icon: "clock.badge.checkmark.fill", iconColor: .cyan) {
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    ForEach([3, 5, 10, 15, 20], id: \.self) { sec in
                        Button(action: { group.countdownSeconds = sec }) {
                            Text("\(sec)\("sec_label".localized)")
                                .font(.system(size: 14, weight: .medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background((group.countdownSeconds ?? 3) == sec ? Color.cyan : DS.Colors.cardHover)
                                .foregroundStyle((group.countdownSeconds ?? 3) == sec ? .white : .primary)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
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
                            value: Binding(
                                get: { group.countdownSeconds ?? 3 },
                                set: { group.countdownSeconds = min(IntervalPlanLimits.maxCountdown, max(1, $0)) }
                            ),
                            width: 60,
                            minValue: 1,
                            maxValue: IntervalPlanLimits.maxCountdown
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
        EditorCard(title: "set_loop".localized, icon: "square.stack.3d.up.fill", iconColor: .mint) {
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
                                set: { group.setCount = min(IntervalPlanLimits.maxSetCount, max(1, $0)) }
                            ),
                            width: 60,
                            minValue: 1,
                            maxValue: IntervalPlanLimits.maxSetCount
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
                                set: { group.setRestTime = min(IntervalPlanLimits.maxSetRestSeconds, max(0, $0)) }
                            ),
                            width: 70,
                            minValue: 0,
                            maxValue: IntervalPlanLimits.maxSetRestSeconds,
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

    private var livePaceRow: some View {
        EditorCard(title: "speed".localized, icon: "speedometer", iconColor: .orange) {
            HStack(spacing: 0) {
                liveCell(label: speedUnit == 1 ? "pace".localized : "speed".localized, value: livePace(), color: .orange)
                    .onTapGesture {
                        speedUnit = (speedUnit + 1) % 3
                        var settings = StorageManager.shared.loadSettings()
                        settings.speedUnit = speedUnit
                        StorageManager.shared.saveSettings(settings)
                    }
                Divider().frame(height: 36)
                liveCell(label: "run_time".localized, value: "\(useCustomRepeats ? customRepeats.count : group.repetitions) \("repetitions".localized)", color: .purple)
                Divider().frame(height: 36)
                liveCell(label: "rest_time".localized, value: "\(effectiveRestSeconds)\("sec_label".localized)", color: .gray)
            }
            .background(DS.Colors.field)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private var colorCard: some View {
        EditorCard(title: "group_color".localized, icon: "paintpalette.fill", iconColor: .pink) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(GroupColor.allCases) { c in
                    Button(action: { group.colorHex = c.rawValue }) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color(hex: c.rawValue) ?? .gray)
                                .frame(width: 12, height: 12)
                            Text(c.displayName)
                                .font(.system(size: 13, weight: .medium))
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(group.colorHex == c.rawValue ? Color(hex: c.rawValue)?.opacity(0.18) ?? DS.Colors.cardHover : DS.Colors.cardHover)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var soundCard: some View {
        EditorCard(title: "sound_settings".localized, icon: "speaker.wave.2.fill", iconColor: .blue) {
            VStack(spacing: 0) {
                soundSettingRow(label: "run_start_sound".localized, selection: $group.startSound)
                Divider().padding(.leading, 4)
                soundSettingRow(label: "rest_start_sound".localized, selection: $group.restSound)
                Divider().padding(.leading, 4)
                soundSettingRow(label: "end_sound".localized, selection: $group.endSound)
            }
        }
    }

    @ViewBuilder
    private func soundSettingRow(label: String, selection: Binding<SoundType>) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 15))
                .foregroundStyle(.primary)
            Spacer()
            Picker("", selection: selection) {
                ForEach(SoundType.allCases) { sound in
                    Text(sound.displayNameKey.localized).tag(sound)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(DS.Colors.field)
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .onChange(of: selection.wrappedValue) { _, v in
                SoundManager.shared.playSound(v)
            }
        }
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func durationEditor(min: Binding<Int>, sec: Binding<Int>, presets: [Int], tint: Color) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Text("a11y_minutes".localized)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 64, alignment: .leading)
                Text("a11y_seconds".localized)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 64, alignment: .leading)
                Spacer()
            }

            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    FloatingIntInputField(
                        placeholder: "0",
                        title: "a11y_minutes".localized,
                        value: Binding(
                            get: { min.wrappedValue },
                            set: { min.wrappedValue = Swift.min(59, Swift.max(0, $0)) }
                        ),
                        width: 40,
                        minValue: 0,
                        maxValue: 59
                    )
                    Text("min_label".localized)
                        .font(.system(size: 13))
                        .foregroundStyle(DS.Colors.textSecondary)
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 12))
                        .foregroundStyle(DS.Colors.textTertiary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(DS.Colors.field)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(DS.Colors.fieldBorder, lineWidth: 1)
                )

                HStack(spacing: 4) {
                    FloatingIntInputField(
                        placeholder: "00",
                        title: "a11y_seconds".localized,
                        value: Binding(
                            get: { sec.wrappedValue },
                            set: { sec.wrappedValue = Swift.min(59, Swift.max(0, $0)) }
                        ),
                        width: 40,
                        minValue: 0,
                        maxValue: 59
                    )
                    Text("sec_label".localized)
                        .font(.system(size: 13))
                        .foregroundStyle(DS.Colors.textSecondary)
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 12))
                        .foregroundStyle(DS.Colors.textTertiary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(DS.Colors.field)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(DS.Colors.fieldBorder, lineWidth: 1)
                )
                Spacer()
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(presets, id: \.self) { value in
                    let current = max(0, min.wrappedValue) * 60 + max(0, sec.wrappedValue)
                    Button(action: {
                        min.wrappedValue = max(0, value / 60)
                        sec.wrappedValue = max(0, value % 60)
                    }) {
                        Text("\(value)\("sec_label".localized)")
                            .font(.system(size: 13, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background(current == value ? tint : DS.Colors.cardHover)
                            .foregroundStyle(current == value ? .white : .primary)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func livePace() -> String {
        let runTime: Double
        if useCustomRepeats, !customRepeats.isEmpty {
            runTime = customRepeats.map { max(0, $0.runTime) }.reduce(0, +) / Double(customRepeats.count)
        } else {
            runTime = Double(max(1, runTotalSecs))
        }
        let runDistance = Double(max(1, group.runDistance))
        guard runTime > 0, runDistance > 0 else { return "--" }

        switch speedUnit {
        case 0:
            return String(format: "%.2f %@", runDistance / runTime, "m_per_s".localized)
        case 2:
            return String(format: "%.1f %@", runDistance / runTime * 3.6, "km_per_h".localized)
        default:
            let paceSeconds = runTime / runDistance * 1000
            return String(format: "%d:%02d%@", Int(paceSeconds) / 60, Int(paceSeconds) % 60, "/km".localized)
        }
    }

    @ViewBuilder
    private func liveCell(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var effectiveRestSeconds: Int {
        if useCustomRepeats, !customRepeats.isEmpty {
            return Int((customRepeats.map { max(0, $0.restTime) }.reduce(0, +) / Double(customRepeats.count)).rounded())
        }
        return restTotalSecs
    }

    private func defaultCustomRepeats() -> [IntervalRepeatConfig] {
        let count = min(IntervalPlanLimits.maxCustomRepeats, max(1, group.repetitions))
        let run = Double(max(1, group.runTime))
        let rest = Double(max(0, group.restTime))
        return (0..<count).map { _ in
            IntervalRepeatConfig(runTime: run, restTime: rest)
        }
    }

    private func prepareGroupForEditor(_ input: IntervalGroup) -> IntervalGroup {
        var prepared = normalizedGroupLimits(input)
        prepared.intensityPercent = TrainingIntensity.clampedPercent(prepared.intensityPercent)
        let storedIntensity = prepared.intensityPercent

        guard abs(storedIntensity - TrainingIntensity.fullPercent) > 0.0001 else {
            return prepared
        }

        if let customRepeats = prepared.customRepeats, !customRepeats.isEmpty {
            prepared.customRepeats = customRepeats.map { repeatConfig in
                var baseline = repeatConfig
                let source = min(Double(IntervalPlanLimits.maxRunTimeSeconds), max(1, repeatConfig.runTime))
                let converted = TrainingIntensity.baselineTime(
                    trainingTimeAtSelectedIntensity: source,
                    intensityPercent: storedIntensity
                ) ?? source
                baseline.runTime = min(Double(IntervalPlanLimits.maxRunTimeSeconds), max(1, converted))
                return baseline
            }
        }

        let sourceRun = min(Double(IntervalPlanLimits.maxRunTimeSeconds), max(1, Double(prepared.runTime)))
        let baselineRun = TrainingIntensity.baselineTime(
            trainingTimeAtSelectedIntensity: sourceRun,
            intensityPercent: storedIntensity
        ) ?? sourceRun
        prepared.runTime = min(IntervalPlanLimits.maxRunTimeSeconds, max(1, Int(baselineRun.rounded())))
        return prepared
    }

    private func setCustomRepeat(index: Int, runTime: Double?, restTime: Double?) {
        guard index >= 0, index < customRepeats.count else { return }
        var updated = customRepeats[index]
        if let runTime {
            updated.runTime = max(0.1, runTime)
        }
        if let restTime {
            updated.restTime = max(0, restTime)
        }
        customRepeats[index] = updated
    }

    private func beginEditRun(_ index: Int) {
        repeatEditText = ""
        editingRepeatField = .run(index)
    }

    private func beginEditRest(_ index: Int) {
        repeatEditText = ""
        editingRepeatField = .rest(index)
    }

    private func applyRepeatEdit(_ field: RepeatEditField) {
        let trimmed = repeatEditText.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard !trimmed.isEmpty, let value = Double(trimmed) else { return }

        switch field {
        case .run(let idx):
            setCustomRepeat(index: idx, runTime: max(0.1, value), restTime: nil)
        case .rest(let idx):
            setCustomRepeat(index: idx, runTime: nil, restTime: max(0, value))
        }
    }

    private func formatRepeatTime(_ seconds: Double) -> String {
        var totalCs = Int((max(0, seconds) * 100).rounded())
        let m = totalCs / 6000
        totalCs %= 6000
        let s = totalCs / 100
        let cs = totalCs % 100
        if m > 0 {
            return cs > 0
                ? "\(m)'\(String(format: "%02d", s)).\(String(format: "%02d", cs))\""
                : "\(m)'\(String(format: "%02d", s))\""
        }
        return cs > 0
            ? "\(s).\(String(format: "%02d", cs))\("sec_label".localized)"
            : "\(s)\("sec_label".localized)"
    }

    private func normalizeIntensityInput(_ input: String) -> String {
        TrainingIntensity.sanitizeInput(input)
    }

    private func syncPickersFromGroup() {
        let run = max(1, group.runTime)
        runMin = run / 60
        runSec = run % 60

        let rest = max(0, group.restTime)
        restMin = rest / 60
        restSec = rest % 60
    }

    private func normalizeAndSave() {
        guard let selectedIntensity = normalizedIntensityPercent else { return }
        group.name = group.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? IntervalGroup.defaultName : group.name
        group.intensityPercent = selectedIntensity
        group.runDistance = min(IntervalPlanLimits.maxRunDistance, max(1, group.runDistance))
        let baseRunFromPicker = min(Double(IntervalPlanLimits.maxRunTimeSeconds), max(1, Double(runTotalSecs)))
        let adjustedRunFromPicker = TrainingIntensity.adjustedTime(
            baseTimeAtHundredPercent: baseRunFromPicker,
            intensityPercent: selectedIntensity
        ) ?? baseRunFromPicker
        group.runTime = min(IntervalPlanLimits.maxRunTimeSeconds, max(1, Int(adjustedRunFromPicker.rounded())))
        group.restTime = min(IntervalPlanLimits.maxRestTimeSeconds, max(0, restTotalSecs))
        group.repetitions = min(IntervalPlanLimits.maxRepetitions, max(1, group.repetitions))
        group.countdownSeconds = min(IntervalPlanLimits.maxCountdown, max(1, group.countdownSeconds ?? 3))
        group.setCount = min(IntervalPlanLimits.maxSetCount, max(1, group.setCount ?? 1))
        group.setRestTime = min(IntervalPlanLimits.maxSetRestSeconds, max(0, group.setRestTime ?? 0))

        if useCustomRepeats {
            let normalized: [IntervalRepeatConfig] = Array(customRepeats.prefix(IntervalPlanLimits.maxCustomRepeats)).map { repeatConfig in
                let baseRun = min(Double(IntervalPlanLimits.maxRunTimeSeconds), max(1, repeatConfig.runTime))
                let adjustedRun = TrainingIntensity.adjustedTime(
                    baseTimeAtHundredPercent: baseRun,
                    intensityPercent: selectedIntensity
                ) ?? baseRun
                return IntervalRepeatConfig(
                    id: repeatConfig.id,
                    runTime: min(Double(IntervalPlanLimits.maxRunTimeSeconds), max(1, adjustedRun)),
                    restTime: min(Double(IntervalPlanLimits.maxRestTimeSeconds), max(0, repeatConfig.restTime))
                )
            }
            group.customRepeats = normalized.isEmpty ? defaultCustomRepeats() : normalized
            group.repetitions = group.customRepeats?.count ?? group.repetitions
            if let repeats = group.customRepeats, !repeats.isEmpty {
                let averageRun = repeats.map { max(1, $0.runTime) }.reduce(0, +) / Double(repeats.count)
                group.runTime = min(IntervalPlanLimits.maxRunTimeSeconds, max(1, Int(averageRun.rounded())))
            }
        } else {
            group.customRepeats = nil
        }

        onSave(normalizedGroupLimits(group))
        dismiss()
    }

    private func normalizedGroupLimits(_ value: IntervalGroup) -> IntervalGroup {
        var normalized = value
        normalized.intensityPercent = TrainingIntensity.clampedPercent(normalized.intensityPercent)
        normalized.runDistance = min(IntervalPlanLimits.maxRunDistance, max(1, normalized.runDistance))
        normalized.runTime = min(IntervalPlanLimits.maxRunTimeSeconds, max(1, normalized.runTime))
        normalized.restTime = min(IntervalPlanLimits.maxRestTimeSeconds, max(0, normalized.restTime))
        normalized.repetitions = min(IntervalPlanLimits.maxRepetitions, max(1, normalized.repetitions))
        normalized.countdownSeconds = min(IntervalPlanLimits.maxCountdown, max(1, normalized.countdownSeconds ?? 3))
        normalized.setCount = min(IntervalPlanLimits.maxSetCount, max(1, normalized.setCount ?? 1))
        normalized.setRestTime = min(IntervalPlanLimits.maxSetRestSeconds, max(0, normalized.setRestTime ?? 0))
        if let customRepeats = normalized.customRepeats, !customRepeats.isEmpty {
            normalized.customRepeats = Array(customRepeats.prefix(IntervalPlanLimits.maxCustomRepeats)).map {
                IntervalRepeatConfig(
                    id: $0.id,
                    runTime: min(Double(IntervalPlanLimits.maxRunTimeSeconds), max(1, $0.runTime)),
                    restTime: min(Double(IntervalPlanLimits.maxRestTimeSeconds), max(0, $0.restTime))
                )
            }
            normalized.repetitions = normalized.customRepeats?.count ?? normalized.repetitions
        }
        return normalized
    }
}
