import SwiftUI

struct MiniHurdleSpacingView: View {

    private enum MiniHurdleAthleteSource: String, CaseIterable, Hashable {
        case temporary
        case saved

        var displayName: String {
            switch self {
            case .temporary: return "mini_hurdle_source_temporary".localized
            case .saved: return "mini_hurdle_source_saved".localized
            }
        }
    }
    @ObservedObject private var localization = LocalizationManager.shared
    private let storage = StorageManager.shared

    @State private var profile: MiniHurdleProfile = .women
    @State private var measurementUnit: MiniHurdleMeasurementUnit = .centimeters
    @State private var greaterTrochanterText = "86"
    @State private var strategyKind: MiniHurdleStrategyKind = .mannRecommended
    @State private var clarkRangeRatio = 2.35
    @State private var savedAthletes: [MiniHurdleAthleteProfile] = []
    @State private var selectedAthleteID: UUID?
    @State private var editorDraft: MiniHurdleAthleteEditorDraft?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @FocusState private var isEditingGT: Bool
    @State private var temporarySetup = TemporarySetup()
    @State private var editorAfterList: MiniHurdleAthleteEditorDraft?

    private struct TemporarySetup {
        var profile: MiniHurdleProfile = .women
        var unit: MiniHurdleMeasurementUnit = .centimeters
        var gtText = "86"
        var strategy: MiniHurdleStrategyKind = .mannRecommended
        var ratio = MiniHurdleProfile.women.mannRecommendedRatio
    }
    @State private var hasLoadedAthletes = false
    @State private var measurementGuideExpanded = false
    @State private var measurementIllustrationExpanded = false
    @State private var methodGuideExpanded = false
    @State private var qualityGuideExpanded = false
    @State private var showAthleteList = false
    @State private var comparisonExpanded = false
    @State private var toastMessage: String?
    @State private var lastAutoSaveDate: Date?

    private var parsedGreaterTrochanterLength: Double? {
        measurementUnit.meters(from: greaterTrochanterText)
    }

    private var clarkRatioRange: ClosedRange<Double> {
        profile.clarkLowerRatio...profile.clarkUpperRatio
    }

    private var clampedClarkRangeRatio: Double {
        min(max(clarkRangeRatio, clarkRatioRange.lowerBound), clarkRatioRange.upperBound)
    }

    private var strategy: MiniHurdleStrategy? {
        switch strategyKind {
        case .clarkRange:
            return .custom(ratio: clampedClarkRangeRatio)
        case .mannRecommended:
            return .mannRecommended
        }
    }

    private var result: MiniHurdleSpacingResult? {
        guard let parsedGreaterTrochanterLength, let strategy else { return nil }
        return MiniHurdleSpacingCalculator.calculate(
            greaterTrochanterLength: parsedGreaterTrochanterLength,
            profile: profile,
            strategy: strategy
        )
    }

    private var activeStrategyDisplayKind: MiniHurdleStrategyKind {
        strategyKind == .mannRecommended ? .mannRecommended : .clarkRange
    }

    private var clarkPreviewResult: MiniHurdleSpacingResult? {
        guard let parsedGreaterTrochanterLength else { return nil }
        return MiniHurdleSpacingCalculator.calculate(
            greaterTrochanterLength: parsedGreaterTrochanterLength,
            profile: profile,
            strategy: .custom(ratio: clampedClarkRangeRatio)
        )
    }

    private var strategySelectionBinding: Binding<MiniHurdleStrategyKind> {
        Binding(
            get: { activeStrategyDisplayKind },
            set: { newValue in
                switch newValue {
                case .mannRecommended:
                    strategyKind = .mannRecommended
                default:
                    strategyKind = .clarkRange
                    clampClarkRatioToCurrentProfile()
                }
                persistSelectedAthleteIfPossible()
            }
        )
    }

    private var selectedAthlete: MiniHurdleAthleteProfile? {
        guard let selectedAthleteID else { return nil }
        return savedAthletes.first(where: { $0.id == selectedAthleteID })
    }

    private var canSaveCurrentSetupAsAthlete: Bool {
        parsedGreaterTrochanterLength != nil && strategy != nil
    }

    private func presentCreateEditor() {
        isEditingGT = false
        editorDraft = MiniHurdleAthleteEditorDraft(
            mode: .saveCurrent,
            athleteID: nil,
            name: "",
            profile: profile,
            greaterTrochanterLength: parsedGreaterTrochanterLength ?? 0.86,
            measurementUnit: measurementUnit,
            strategyKind: strategyKind,
            customRatio: activeStoredRatio
        )
    }

    private var athleteDisplayName: String {
        selectedAthlete?.name ?? "mini_hurdle_athlete_temporary_name".localized
    }

    private var athleteConfigSummary: String {
        if let selectedAthlete {
            return athleteSummary(for: selectedAthlete)
        }
        guard canSaveCurrentSetupAsAthlete else {
            return "mini_hurdle_athlete_setup_incomplete".localized
        }
        return currentSetupSummary
    }

    private var measurementGuideAssetName: String {
        LocalizationPreferenceResolver.resolveBundleLanguage(for: localization.currentLanguage) == "en"
            ? "MiniHurdleGTLengthGuideEN"
            : "MiniHurdleGTLengthGuide"
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    setupSection
                        .id("mini_hurdle_anchor_top")

                    if let result {
                        resultsSection(result)
                            .id("mini_hurdle_anchor_layout")
                        progressionSection(result)
                    } else {
                        invalidStateSection
                    }

                    referencesSection
                        .id("mini_hurdle_anchor_measurement")
                    Color.clear
                        .frame(height: 0)
                        .id("mini_hurdle_anchor_bottom")
                }
                .padding(.horizontal, DS.Space.page)
                .padding(.vertical, DS.Space.lg)
                .dsReadableColumn(960)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .accessibilityIdentifier("mini_hurdle_scroll")
            .background(TrainingPageBackground())
            .overlay(alignment: .top) {
                if let toastMessage {
                    Text(toastMessage)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, DS.Space.lg)
                        .padding(.vertical, DS.Space.sm + 2)
                        .background(
                            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                                .fill(DS.Colors.card)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                                .stroke(DS.Colors.border, lineWidth: 1)
                        )
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .accessibilityAddTraits(.isStaticText)
                        .allowsHitTesting(false)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: toastMessage)
            .fullScreenCover(item: $editorDraft) { draft in
                MiniHurdleAthleteEditorSheet(
                    mode: draft.mode,
                    initialName: draft.name,
                    summaryTitle: "mini_hurdle_athlete_editor_summary_title".localized,
                    summaryText: currentSetupSummary,
                    syncNote: "mini_hurdle_athlete_editor_sync_note".localized,
                    draft: draft,
                    validateName: { name in
                        validationMessage(for: draft, name: name)
                    },
                    onSave: { name, profile, gtLength, unit, strategyKind, customRatio in
                        saveAthleteDraft(draft, name: name, profile: profile, gtLength: gtLength, unit: unit, strategyKind: strategyKind, customRatio: customRatio)
                    },
                    onDelete: draft.mode == .edit ? {
                        guard let athleteID = draft.athleteID,
                              let athlete = savedAthletes.first(where: { $0.id == athleteID }) else { return }
                        deleteAthlete(athlete)
                    } : nil
                )
            }
            .fullScreenCover(isPresented: $showAthleteList, onDismiss: {
                if let draft = editorAfterList {
                    editorAfterList = nil
                    editorDraft = draft
                }
            }) {
                MiniHurdleAthleteListView(
                    savedAthletes: savedAthletes,
                    selectedAthleteID: selectedAthleteID,
                    summaryText: { athlete in athleteSummary(for: athlete) },
                    onSelect: { athlete in selectAthlete(athlete) },
                    onEdit: { draft in
                        editorAfterList = draft
                        showAthleteList = false
                    },
                    onDelete: { athlete in deleteAthlete(athlete) },
                    onCreateNew: {
                        editorAfterList = MiniHurdleAthleteEditorDraft(
                            mode: .create,
                            athleteID: nil,
                            name: "",
                            profile: profile,
                            greaterTrochanterLength: parsedGreaterTrochanterLength ?? 0.86,
                            measurementUnit: measurementUnit,
                            strategyKind: strategyKind,
                            customRatio: activeStoredRatio
                        )
                        showAthleteList = false
                    }
                )
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            // Audit B4: solid dark bar once content scrolls underneath,
            // so the title no longer floats over passing text.
            .toolbarBackground(DS.Colors.bg, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("done".localized) { isEditingGT = false }
                        .accessibilityIdentifier("mini_hurdle_gt_done")
                }
                ToolbarItem(placement: .principal) {
                    Text("mini_hurdle_title".localized)
                        .font(.headline)
                        .foregroundStyle(DS.Colors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .accessibilityAddTraits(.isHeader)
                }
            }
            .onAppear {
                loadAthletesIfNeeded()
                scheduleQAScrollIfNeeded(with: proxy)
            }
        }
    }

    private func compactStripButton(
        icon: String,
        text: String,
        isDisabled: Bool,
        accessibilityIdentifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(text, systemImage: icon)
                .font(.footnote.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isDisabled ? Color.white.opacity(0.03) : Color.white.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(isDisabled ? Color.white.opacity(0.08) : Color.white.opacity(0.22), lineWidth: 1)
                )
                .foregroundStyle(isDisabled ? DS.Colors.textTertiary : DS.Colors.textPrimary)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private func setupPickerColumn(
        title: String,
        selection: Binding<MiniHurdleProfile>,
        options: [MiniHurdleProfile]
    ) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DS.Colors.textSecondary)

            miniSegmentedPicker(selection: selection, options: options) { $0.displayName }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func setupPickerColumn(
        title: String,
        selection: Binding<MiniHurdleMeasurementUnit>,
        options: [MiniHurdleMeasurementUnit]
    ) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DS.Colors.textSecondary)

            miniSegmentedPicker(selection: selection, options: options) { $0.displayName }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var setupSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.md) {
            athleteCard
            let layout = horizontalSizeClass == .regular
                ? AnyLayout(HStackLayout(alignment: .top, spacing: DS.Space.md))
                : AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Space.md))
            layout {
                measurementCard
                    .id("mini_hurdle_anchor_middle")
                planCard
            }
        }
    }

    private var athleteCard: some View {
        MiniHurdleSectionCard(
            title: "mini_hurdle_step_athlete_title".localized,
            subtitle: selectedAthlete == nil
                ? "mini_hurdle_step_athlete_subtitle_temporary".localized
                : "mini_hurdle_source_saved_subtitle".localized,
            accent: DS.Colors.miniHurdle,
            stepIndex: "01",
            status: selectedAthlete?.name ?? "mini_hurdle_source_temporary".localized,
            statusTint: selectedAthlete == nil ? DS.Colors.textSecondary : DS.Colors.success
        ) {
            VStack(alignment: .leading, spacing: DS.Space.sm) {
                miniSegmentedPicker(
                    selection: athleteSourceBinding,
                    options: MiniHurdleAthleteSource.allCases
                ) { $0.displayName }

                if let selectedAthlete {
                    HStack(spacing: DS.Space.sm) {
                        athleteIdentityMenu

                        Button {
                            showAthleteList = true
                        } label: {
                            Image(systemName: "person.2")
                                .font(.system(size: 15, weight: .regular))
                                .foregroundStyle(DS.Colors.textSecondary)
                                .frame(width: 44, height: 52)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(DS.Colors.field)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(DS.Colors.border, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("mini_hurdle_athlete_list_manage_button".localized)
                        .accessibilityIdentifier("mini_hurdle_athlete_list_button")
                    }

                    Button {
                        editorDraft = MiniHurdleAthleteEditorDraft(
                            mode: .edit,
                            athleteID: selectedAthlete.id,
                            name: selectedAthlete.name,
                            profile: selectedAthlete.profile,
                            greaterTrochanterLength: selectedAthlete.greaterTrochanterLength,
                            measurementUnit: selectedAthlete.measurementUnit,
                            strategyKind: selectedAthlete.strategyKind,
                            customRatio: selectedAthlete.customRatio
                        )
                    } label: {
                        Label("mini_hurdle_athlete_manage_button".localized, systemImage: "square.and.pencil")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(DS.Colors.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("mini_hurdle_athlete_manage_button")
                } else if savedAthletes.isEmpty {
                    Text("mini_hurdle_no_athletes_hint".localized)
                        .font(.system(size: 12))
                        .foregroundStyle(DS.Colors.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("mini_hurdle_saved_available_hint".localized)
                        .font(.system(size: 12))
                        .foregroundStyle(DS.Colors.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var athleteSourceBinding: Binding<MiniHurdleAthleteSource> {
        Binding(
            get: { selectedAthlete == nil ? .temporary : .saved },
            set: { source in
                switch source {
                case .temporary:
                    guard selectedAthlete != nil else { return }
                    useTemporarySetup()
                    playLightHaptic()
                case .saved:
                    if selectedAthlete == nil {
                        showAthleteList = true
                    }
                }
            }
        )
    }

    private var athleteIdentityMenu: some View {
        Menu {
            Button {
                if selectedAthlete != nil {
                    useTemporarySetup()
                    playLightHaptic()
                }
            } label: {
                Label(
                    "mini_hurdle_athlete_temporary_name".localized,
                    systemImage: selectedAthlete == nil ? "checkmark.circle.fill" : "circle"
                )
            }

            if !savedAthletes.isEmpty {
                Divider()
            }

            ForEach(savedAthletes) { athlete in
                Button {
                    selectAthlete(athlete)
                } label: {
                    HStack {
                        Label(athlete.name, systemImage: athlete.id == selectedAthleteID ? "checkmark.circle.fill" : "circle")
                        Spacer()
                        Text(athleteSummary(for: athlete))
                            .font(.caption2)
                    }
                }
                .accessibilityIdentifier("mini_hurdle_athlete_picker_name_\(athlete.name)")
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(DS.Colors.textSecondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(athleteDisplayName)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(DS.Colors.textPrimary)
                        .accessibilityIdentifier("mini_hurdle_current_athlete_name")

                    Text(athleteConfigSummary)
                        .font(.system(size: 11))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .foregroundStyle(DS.Colors.textTertiary)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DS.Colors.textSecondary)
            }
            .padding(.horizontal, DS.Space.md)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(DS.Colors.field)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(DS.Colors.border, lineWidth: 1)
            )
        }
        .accessibilityIdentifier("mini_hurdle_athlete_switch_button")
    }

    // 02 测量：性别决定比例区间，GT 决定绝对距离，两者是结果唯一的输入源。
    private var measurementCard: some View {
        MiniHurdleSectionCard(
            title: "mini_hurdle_step_measure_title".localized,
            subtitle: "mini_hurdle_step_measure_subtitle".localized,
            accent: DS.Colors.miniHurdle,
            stepIndex: "02",
            status: measurementStatusText,
            statusTint: (isGTInputInvalid || isGTOutOfRange) ? DS.Colors.warning : DS.Colors.textSecondary
        ) {
            VStack(alignment: .leading, spacing: DS.Space.md) {
                HStack(alignment: .top, spacing: DS.Space.md) {
                    setupPickerColumn(
                        title: "mini_hurdle_profile".localized,
                        selection: Binding(get: { profile }, set: {
                            profile = $0
                            clampClarkRatioToCurrentProfile()
                            persistSelectedAthleteIfPossible()
                        }),
                        options: MiniHurdleProfile.allCases
                    )
                    setupPickerColumn(
                        title: "mini_hurdle_measurement_unit".localized,
                        selection: Binding(get: { measurementUnit }, set: changeMeasurementUnit),
                        options: MiniHurdleMeasurementUnit.allCases
                    )
                }

                compactGTInputCard
            }
        }
    }

    private var measurementStatusText: String {
        guard parsedGreaterTrochanterLength != nil,
              !isGTInputInvalid,
              !isGTOutOfRange else {
            return "mini_hurdle_step_status_needed".localized
        }
        return enteredLengthText
    }

    // 03 摆点方案：换算比例决定栏距；比例定完，再把当前数值存成档案。
    private var planCard: some View {
        MiniHurdleSectionCard(
            title: "mini_hurdle_step_plan_title".localized,
            subtitle: "mini_hurdle_step_plan_subtitle".localized,
            accent: DS.Colors.miniHurdle,
            stepIndex: "03",
            status: planStatusText,
            statusTint: DS.Colors.textSecondary
        ) {
            VStack(alignment: .leading, spacing: DS.Space.md) {
                VStack(alignment: .leading, spacing: DS.Space.xs) {
                    miniSegmentedPicker(
                        selection: strategySelectionBinding,
                        options: [MiniHurdleStrategyKind.mannRecommended, .clarkRange]
                    ) { kind in
                        kind == .mannRecommended
                            ? "mini_hurdle_strategy_mann".localized
                            : "mini_hurdle_strategy_clark_range".localized
                    }

                    if activeStrategyDisplayKind == .clarkRange {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline) {
                                Text("mini_hurdle_strategy_clark_slider_title".localized)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(DS.Colors.textSecondary)
                                Spacer()
                                Text(ratioText(clampedClarkRangeRatio))
                                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                                    .monospacedDigit()
                                    .foregroundStyle(DS.Colors.textPrimary)
                            }

                            Slider(
                                value: Binding(get: { clarkRangeRatio }, set: {
                                    clarkRangeRatio = $0
                                    persistSelectedAthleteIfPossible()
                                }),
                                in: clarkRatioRange,
                                step: 0.01
                            )
                            .tint(DS.Colors.miniHurdle)
                            .accessibilityIdentifier("mini_hurdle_clark_ratio_slider")

                            HStack {
                                Text(ratioText(profile.clarkLowerRatio))
                                Spacer()
                                Text(ratioText(profile.mannRecommendedRatio))
                                Spacer()
                                Text(ratioText(profile.clarkUpperRatio))
                            }
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(DS.Colors.textSecondary)

                            if let clarkPreviewResult {
                                Text(
                                    String(
                                        format: "mini_hurdle_strategy_slider_preview".localized,
                                        distanceText(clarkPreviewResult.maximumSpacing),
                                        distanceText(clarkPreviewResult.hurdlePlacementDistance)
                                    )
                                )
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(DS.Colors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(DS.Colors.field)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(DS.Colors.border, lineWidth: 1)
                        )
                    } else if let result {
                        Text(
                            String(
                                format: "mini_hurdle_strategy_mann_inline_note".localized,
                                ratioText(result.selectedRatio),
                                distanceText(result.maximumSpacing)
                            )
                        )
                        .font(.caption)
                        .foregroundStyle(DS.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }

                saveSetupRow
            }
        }
    }

    private var planStatusText: String {
        switch activeStrategyDisplayKind {
        case .mannRecommended:
            return ratioText(result?.selectedRatio ?? profile.mannRecommendedRatio)
        case .clarkRange:
            return ratioText(clampedClarkRangeRatio)
        }
    }

    private var saveSetupRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            compactStripButton(
                icon: selectedAthlete == nil ? "square.and.arrow.down" : "plus.circle",
                text: selectedAthlete == nil
                    ? "mini_hurdle_athlete_save_button".localized
                    : "mini_hurdle_athlete_save_as_new_button".localized,
                isDisabled: !canSaveCurrentSetupAsAthlete,
                accessibilityIdentifier: "mini_hurdle_athlete_save_button"
            ) {
                presentCreateEditor()
            }

            if selectedAthlete != nil, let lastAutoSaveDate {
                Label(
                    String(
                        format: "mini_hurdle_autosave_format".localized,
                        lastAutoSaveDate.formatted(date: .omitted, time: .shortened)
                    ),
                    systemImage: "checkmark.circle.fill"
                )
                .font(.caption)
                .foregroundStyle(DS.Colors.success)
                .accessibilityIdentifier("mini_hurdle_autosave_indicator")
            }
        }
    }

    private var compactGTInputCard: some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            Text("mini_hurdle_measurement_gt_title".localized)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DS.Colors.textSecondary)

            HStack(spacing: DS.Space.sm) {
                Button {
                    adjustGreaterTrochanter(byDisplayUnits: measurementUnit == .centimeters ? -1 : -0.01)
                } label: {
                    Image(systemName: "minus.circle")
                        .font(.system(size: 20))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                        .foregroundStyle(DS.Colors.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("mini_hurdle_gt_decrease".localized)
                .accessibilityIdentifier("mini_hurdle_gt_step_down")

                TextField(
                    measurementUnit == .centimeters ? "86" : "0.86",
                    text: Binding(
                        get: { greaterTrochanterText },
                        set: {
                            greaterTrochanterText = sanitizeDecimalInput($0)
                            persistSelectedAthleteIfPossible()
                        }
                    )
                )
                .keyboardType(.decimalPad)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .font(.system(size: 17, weight: .medium, design: .monospaced))
                .monospacedDigit()
                .multilineTextAlignment(.center)
                .foregroundStyle(DS.Colors.textPrimary)
                .focused($isEditingGT)
                .accessibilityIdentifier("mini_hurdle_gt_input")

                Button {
                    greaterTrochanterText = ""
                    isEditingGT = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(DS.Colors.textSecondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(greaterTrochanterText.isEmpty)
                .accessibilityLabel("mini_hurdle_clear_gt".localized)
                .accessibilityIdentifier("mini_hurdle_clear_gt")

                Text(measurementUnit.displayName)
                    .font(.system(size: 12))
                    .foregroundStyle(DS.Colors.textTertiary)

                Button {
                    adjustGreaterTrochanter(byDisplayUnits: measurementUnit == .centimeters ? 1 : 0.01)
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 20))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                        .foregroundStyle(DS.Colors.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("mini_hurdle_gt_increase".localized)
                .accessibilityIdentifier("mini_hurdle_gt_step_up")
            }
            .padding(.horizontal, DS.Space.md)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .fill(DS.Colors.field)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .stroke(
                        (isGTInputInvalid || isGTOutOfRange) ? DS.Colors.warning.opacity(0.8) : DS.Colors.fieldBorder,
                        lineWidth: 1
                    )
            )

            if isGTInputInvalid {
                Text("mini_hurdle_invalid_gt_hint".localized)
                    .font(.caption)
                    .foregroundStyle(DS.Colors.warning)
                    .fixedSize(horizontal: false, vertical: true)
            } else if isGTOutOfRange {
                Text("mini_hurdle_gt_out_of_range_hint".localized)
                    .font(.caption)
                    .foregroundStyle(DS.Colors.warning)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let parsedGreaterTrochanterLength {
                Text(
                    String(
                        format: "mini_hurdle_measurement_gt_converted".localized,
                        enteredLengthText,
                        parsedGreaterTrochanterLength
                    )
                )
                .font(.caption)
                // Audit MH-8: conversion note is tertiary context, not a highlight.
                .foregroundStyle(DS.Colors.textTertiary)
            } else {
                Text("mini_hurdle_measurement_gt_hint".localized)
                    .font(.caption)
                    .foregroundStyle(DS.Colors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var referencesSection: some View {
        MiniHurdleSectionCard(
            title: "mini_hurdle_references_title".localized,
            subtitle: "mini_hurdle_references_subtitle".localized
        ) {
            VStack(alignment: .leading, spacing: 0) {
                referenceDisclosure(
                    title: "mini_hurdle_measurement_definition_title".localized,
                    isExpanded: $measurementGuideExpanded,
                    identifier: "mini_hurdle_measurement_detail_toggle"
                ) {
                    VStack(alignment: .leading, spacing: DS.Space.md) {
                        MiniCalloutCard(
                            detail: "mini_hurdle_measurement_definition_body".localized,
                            accent: DS.Colors.miniHurdle
                        )

                        MiniCalloutCard(
                            detail: "mini_hurdle_measurement_partner_body".localized,
                            accent: DS.Colors.miniHurdle
                        )

                        VStack(alignment: .leading, spacing: DS.Space.sm) {
                            MiniGuideStepRow(index: 1, text: "mini_hurdle_measurement_cue_lateral_body".localized)
                            MiniGuideStepRow(index: 2, text: "mini_hurdle_measurement_cue_rotation_body".localized)
                            MiniGuideStepRow(index: 3, text: "mini_hurdle_measurement_cue_vertical_body".localized)
                            MiniGuideStepRow(index: 4, text: "mini_hurdle_measurement_cue_repeat_body".localized)
                        }

                        Text("mini_hurdle_measurement_note_body".localized)
                            .font(.system(size: 12))
                            .foregroundStyle(DS.Colors.warning)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Divider()

                referenceDisclosure(
                    title: "mini_hurdle_measurement_illustration_toggle".localized,
                    isExpanded: $measurementIllustrationExpanded,
                    identifier: "mini_hurdle_measurement_illustration_toggle"
                ) {
                    VStack(alignment: .leading, spacing: DS.Space.md) {
                        MiniHurdleIllustration(
                            assetName: measurementGuideAssetName,
                            accent: DS.Colors.miniHurdle
                        )
                        .accessibilityIdentifier("mini_hurdle_measurement_illustration")

                        Text("mini_hurdle_measurement_source_note".localized)
                            .font(.system(size: 11))
                            .foregroundStyle(DS.Colors.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("mini_hurdle_measurement_source_note")
                    }
                }

                Divider()

                referenceDisclosure(
                    title: "mini_hurdle_method_detail_toggle".localized,
                    isExpanded: $methodGuideExpanded,
                    identifier: "mini_hurdle_method_detail_toggle_id"
                ) {
                    VStack(alignment: .leading, spacing: DS.Space.md) {
                        MiniExpertCard(
                            title: "mini_hurdle_research_clark_title".localized,
                            detail: profile == .women
                                ? "mini_hurdle_research_clark_body_women".localized
                                : "mini_hurdle_research_clark_body_men".localized,
                            accent: DS.Colors.miniHurdle
                        )
                        MiniExpertCard(
                            title: "mini_hurdle_research_mann_title".localized,
                            detail: profile == .women
                                ? "mini_hurdle_research_mann_body_women".localized
                                : "mini_hurdle_research_mann_body_men".localized,
                            accent: DS.Colors.miniHurdle
                        )
                        MiniExpertCard(
                            title: "mini_hurdle_strategy_current_note_title".localized,
                            detail: activeStrategyDisplayKind.currentNote,
                            accent: DS.Colors.miniHurdle
                        )
                    }
                }

                Divider()

                referenceDisclosure(
                    title: "mini_hurdle_quality_detail_toggle".localized,
                    isExpanded: $qualityGuideExpanded,
                    identifier: "mini_hurdle_quality_detail_toggle"
                ) {
                    VStack(alignment: .leading, spacing: DS.Space.sm) {
                        MiniBulletRow(text: "mini_hurdle_quality_1".localized)
                        MiniBulletRow(text: "mini_hurdle_quality_2".localized)
                        MiniBulletRow(text: "mini_hurdle_quality_3".localized)
                        MiniBulletRow(text: "mini_hurdle_quality_4".localized)
                        MiniBulletRow(text: "mini_hurdle_quality_5".localized)
                        MiniBulletRow(text: "mini_hurdle_quality_6".localized)
                    }
                }
            }
        }
    }

    private func referenceDisclosure<Content: View>(
        title: String,
        isExpanded: Binding<Bool>,
        identifier: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let inner = content()
        return DisclosureGroup(isExpanded: isExpanded) {
            inner
                .padding(.top, DS.Space.md)
                .padding(.bottom, DS.Space.md)
        } label: {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(DS.Colors.textPrimary)
                Spacer(minLength: DS.Space.sm)
            }
            .padding(.vertical, DS.Space.md)
            .contentShape(Rectangle())
        }
        .tint(DS.Colors.textTertiary)
        .accessibilityIdentifier(identifier)
    }

    private func resultsSection(_ result: MiniHurdleSpacingResult) -> some View {
        MiniHurdleSectionCard(
            title: "mini_hurdle_overview_title".localized,
            subtitle: "mini_hurdle_overview_subtitle".localized,
            accent: DS.Colors.miniHurdle,
            stepIndex: "04",
            status: String(
                format: "mini_hurdle_step_result_status_format".localized,
                result.hurdlePlacements.count
            )
        ) {
            VStack(spacing: 14) {
                // Compact result summary strip — dark tinted card with teal
                // accents instead of a solid saturated block (配色升级).
                HStack(spacing: DS.Space.sm) {
                    Image(systemName: "figure.stand")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(DS.Colors.textTertiary)

                    Text(enteredLengthText)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(DS.Colors.textPrimary)

                    Text("·").foregroundStyle(DS.Colors.textHint)

                    Text(ratioText(result.selectedRatio))
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(DS.Colors.textPrimary)

                    Text("·").foregroundStyle(DS.Colors.textHint)

                    Text("\(distanceText(result.minimumSpacing)) – \(distanceText(result.maximumSpacing))")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(DS.Colors.textPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DS.Space.md)
                .padding(.vertical, DS.Space.sm + 2)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                        .fill(DS.Colors.cardHover)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                        .stroke(DS.Colors.borderLight, lineWidth: 1)
                )

                HStack(alignment: .top, spacing: DS.Space.lg) {
                    MiniMetricTile(
                        title: "mini_hurdle_overview_metric_hurdle_total".localized,
                        value: distanceText(result.firstHurdleCoordinate),
                        tint: DS.Colors.miniHurdle
                    )
                    MiniMetricTile(
                        title: "mini_hurdle_overview_metric_total".localized,
                        value: distanceText(result.lastHurdleCoordinate),
                        tint: DS.Colors.miniHurdle
                    )
                }

                Text(String(format: "mini_hurdle_span_line".localized, distanceText(result.hurdlePlacementDistance)))
                    .font(.system(size: 12, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(DS.Colors.textTertiary)

                DisclosureGroup(isExpanded: $comparisonExpanded) {
                    VStack(spacing: 0) {
                        MiniValueRow(
                            title: "mini_hurdle_overview_clark_range".localized,
                            value: "\(distanceText(result.clarkLowerSpacing)) - \(distanceText(result.clarkUpperSpacing))"
                        )
                        MiniValueRow(
                            title: "mini_hurdle_overview_clark_opening_range".localized,
                            value: "\(distanceText(result.clarkLowerSpacing - 0.41)) - \(distanceText(result.clarkUpperSpacing - 0.41))"
                        )
                        MiniValueRow(
                            title: "mini_hurdle_overview_mann".localized,
                            value: "\(distanceText(result.mannRecommendedSpacing - 0.41)) - \(distanceText(result.mannRecommendedSpacing))"
                        )
                        MiniValueRow(
                            title: "mini_hurdle_overview_12".localized,
                            value: checkpointText(for: 12, in: result)
                        )
                        MiniValueRow(
                            title: "mini_hurdle_overview_16".localized,
                            value: checkpointText(for: 16, in: result)
                        )
                    }
                } label: {
                    HStack {
                        Text("mini_hurdle_overview_compare_toggle".localized)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(DS.Colors.textSecondary)
                        Spacer(minLength: DS.Space.sm)
                    }
                    .padding(.vertical, DS.Space.xs)
                    .contentShape(Rectangle())
                }
                .tint(DS.Colors.textTertiary)

                Divider()
                    .padding(.vertical, 2)

                // Point detail table
                VStack(alignment: .leading, spacing: 10) {
                    Text("mini_hurdle_hurdles_table_title".localized)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DS.Colors.textPrimary)

                    Grid(alignment: .trailing, horizontalSpacing: 10, verticalSpacing: 8) {
                        GridRow {
                            Text("mini_hurdle_chain_mark_header".localized)
                                .gridColumnAlignment(.leading)
                            Text("mini_hurdle_chain_step_header".localized)
                            Text("mini_hurdle_chain_spacing_header".localized)
                            Text("mini_hurdle_chain_total_header".localized)
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DS.Colors.textSecondary)

                        Divider()

                        ForEach(result.worksheetSequence) { mark in
                            MiniWorksheetSequenceRow(mark: mark)
                        }
                    }
                }
                .id("mini_hurdle_anchor_hurdles")
            }
        }
    }

    private func progressionSection(_ result: MiniHurdleSpacingResult) -> some View {
        MiniHurdleSectionCard(
            title: "mini_hurdle_progression_title".localized,
            subtitle: "mini_hurdle_progression_subtitle".localized,
            accent: DS.Colors.success
        ) {
            VStack(alignment: .leading, spacing: DS.Space.lg) {
                MiniStageBlock(
                    title: "mini_hurdle_progression_phase_1_title".localized,
                    data: String(
                        format: "mini_hurdle_stage_data_a".localized,
                        12,
                        distanceText(hurdleSpacing(for: 12, in: result)),
                        normalizedSpacingText(for: 12, in: result)
                    ),
                    data2: String(
                        format: "mini_hurdle_stage_data_b".localized,
                        distanceText(worksheetDistance(for: 12, in: result)),
                        distanceText(placementDistance(for: 12, in: result))
                    ),
                    cue: "mini_hurdle_stage_cue_1".localized
                )

                MiniStageBlock(
                    title: "mini_hurdle_progression_phase_2_title".localized,
                    data: String(
                        format: "mini_hurdle_stage_data_a".localized,
                        16,
                        distanceText(hurdleSpacing(for: 16, in: result)),
                        normalizedSpacingText(for: 16, in: result)
                    ),
                    data2: String(
                        format: "mini_hurdle_stage_data_b".localized,
                        distanceText(worksheetDistance(for: 16, in: result)),
                        distanceText(placementDistance(for: 16, in: result))
                    ),
                    cue: "mini_hurdle_stage_cue_2".localized
                )

                MiniStageBlock(
                    title: "mini_hurdle_progression_phase_3_title".localized,
                    data: String(
                        format: "mini_hurdle_stage_data_final_a".localized,
                        distanceText(result.maximumSpacing),
                        distanceText(result.lastHurdleCoordinate)
                    ),
                    data2: String(
                        format: "mini_hurdle_stage_data_final_b".localized,
                        distanceText(result.hurdlePlacementDistance),
                        distanceText(result.recommendedRunOutDistance)
                    ),
                    cue: "mini_hurdle_stage_cue_3".localized
                )
            }
        }
    }

    private var invalidStateSection: some View {
        MiniHurdleSectionCard(title: "mini_hurdle_overview_title".localized, accent: DS.Colors.warning) {
            VStack(alignment: .leading, spacing: 8) {
                Label("mini_hurdle_invalid_gt".localized, systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.Colors.warning)
                    .fixedSize(horizontal: false, vertical: true)
                Text("mini_hurdle_invalid_gt_hint".localized)
                    .font(.caption)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var isGTInputInvalid: Bool {
        !sanitizeDecimalInput(greaterTrochanterText).isEmpty && parsedGreaterTrochanterLength == nil
    }

    // P3 修复：软警告——超出常见人体范围（50–120 cm）时仍参与计算，
    // 但警示框变橙并提示复核，避免 905 cm 之类录入错误无声产出垃圾表。
    private var isGTOutOfRange: Bool {
        guard let parsedGreaterTrochanterLength else { return false }
        return parsedGreaterTrochanterLength < 0.5 || parsedGreaterTrochanterLength > 1.2
    }

    private func adjustGreaterTrochanter(byDisplayUnits delta: Double) {
        let fallback = measurementUnit == .centimeters ? 86.0 : 0.86
        let current = parsedGreaterTrochanterLength.map { measurementUnit == .centimeters ? $0 * 100 : $0 } ?? fallback
        let minimum = measurementUnit == .centimeters ? 1.0 : 0.01
        let adjusted = max(minimum, current + delta)
        greaterTrochanterText = measurementUnit.inputText(meters: measurementUnit == .centimeters ? adjusted / 100 : adjusted)
        persistSelectedAthleteIfPossible()
    }

    private var enteredLengthText: String {
        parsedGreaterTrochanterLength.map { measurementUnit.lengthText(meters: $0) } ?? "—"
    }

    private func sanitizeDecimalInput(_ input: String) -> String {
        input.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
    }

    private func distanceText(_ value: Double) -> String {
        MiniHurdleFormatting.distance(value)
    }

    private func scheduleQAScrollIfNeeded(with proxy: ScrollViewProxy) {
        guard let target = AppRuntimeConfiguration.miniHurdleScrollTarget() else { return }
        [0.35, 0.9, 1.6].forEach { delay in
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                proxy.scrollTo(target.anchorID, anchor: .top)
            }
        }
    }

    private func ratioText(_ value: Double) -> String {
        String(format: "%.2f×GT", value)
    }

    private func placementDistance(for hurdleCount: Int, in result: MiniHurdleSpacingResult) -> Double {
        guard hurdleCount > 0, result.hurdlePlacements.indices.contains(hurdleCount - 1) else {
            return 0
        }
        return result.hurdlePlacements[hurdleCount - 1].positionFromFirstHurdle
    }

    private func worksheetDistance(for hurdleCount: Int, in result: MiniHurdleSpacingResult) -> Double {
        guard hurdleCount > 0, result.hurdles.indices.contains(hurdleCount - 1) else {
            return 0
        }
        return result.hurdles[hurdleCount - 1].cumulativePosition
    }

    private func hurdleSpacing(for hurdleCount: Int, in result: MiniHurdleSpacingResult) -> Double {
        guard hurdleCount > 0, result.hurdles.indices.contains(hurdleCount - 1) else {
            return 0
        }
        return result.hurdles[hurdleCount - 1].spacing
    }

    private func normalizedSpacingText(for hurdleCount: Int, in result: MiniHurdleSpacingResult) -> String {
        guard hurdleCount > 0, result.hurdles.indices.contains(hurdleCount - 1) else {
            return "--"
        }
        return String(format: "%.0f%%", result.hurdles[hurdleCount - 1].normalizedSpacing * 100)
    }

    private func checkpointText(for hurdleCount: Int, in result: MiniHurdleSpacingResult) -> String {
        guard hurdleCount > 0,
              result.hurdlePlacements.indices.contains(hurdleCount - 1),
              result.hurdles.indices.contains(hurdleCount - 1) else {
            return "--"
        }
        let placement = result.hurdlePlacements[hurdleCount - 1]
        let worksheet = result.hurdles[hurdleCount - 1]
        return String(
            format: "mini_hurdle_checkpoint_format".localized,
            distanceText(worksheet.cumulativePosition),
            distanceText(placement.positionFromFirstHurdle)
        )
    }

    private var currentSetupSummary: String {
        let strategySummary = strategySummaryText(
            strategyKind: strategyKind,
            customRatio: activeStoredRatio,
            profile: profile
        )
        return String(
            format: "mini_hurdle_athlete_summary_format".localized,
            profile.displayName,
            enteredLengthText,
            strategySummary
        )
    }

    private func athleteSummary(for athlete: MiniHurdleAthleteProfile) -> String {
        let greaterTrochanterText = athlete.measurementUnit.lengthText(meters: athlete.greaterTrochanterLength)
        let strategySummary = strategySummaryText(
            strategyKind: athlete.strategyKind,
            customRatio: athlete.customRatio,
            profile: athlete.profile
        )
        return String(
            format: "mini_hurdle_athlete_summary_format".localized,
            athlete.profile.displayName,
            greaterTrochanterText,
            strategySummary
        )
    }

    private func strategySummaryText(
        strategyKind: MiniHurdleStrategyKind,
        customRatio: Double?,
        profile: MiniHurdleProfile
    ) -> String {
        switch strategyKind {
        case .mannRecommended:
            return MiniHurdleStrategyKind.mannRecommended.title
        case .clarkRange:
            let ratio = clampStoredClarkRatio(customRatio, for: profile)
            return String(
                format: "mini_hurdle_athlete_clark_summary_format".localized,
                ratioText(ratio)
            )
        }
    }

    private var activeStoredRatio: Double? {
        strategyKind == .mannRecommended ? nil : clampedClarkRangeRatio
    }

    private func clampStoredClarkRatio(_ ratio: Double?, for profile: MiniHurdleProfile) -> Double {
        let candidate = ratio ?? profile.mannRecommendedRatio
        return min(max(candidate, profile.clarkLowerRatio), profile.clarkUpperRatio)
    }

    private func loadAthletesIfNeeded() {
        guard !hasLoadedAthletes else { return }
        hasLoadedAthletes = true
        savedAthletes = storage.loadMiniHurdleProfiles()
        let storedSelection = storage.loadSelectedMiniHurdleProfileID()
        if let storedSelection,
           let athlete = savedAthletes.first(where: { $0.id == storedSelection }) {
            selectedAthleteID = athlete.id
            applyAthlete(athlete)
        } else {
            selectedAthleteID = nil
            storage.saveSelectedMiniHurdleProfileID(nil)
        }
    }

    private func applyAthlete(_ athlete: MiniHurdleAthleteProfile) {
        profile = athlete.profile
        measurementUnit = athlete.measurementUnit
        greaterTrochanterText = measurementUnit.inputText(meters: athlete.greaterTrochanterLength)
        switch athlete.strategyKind {
        case .mannRecommended:
            strategyKind = .mannRecommended
            clarkRangeRatio = athlete.profile.mannRecommendedRatio
        case .clarkRange:
            strategyKind = .clarkRange
            clarkRangeRatio = clampStoredClarkRatio(athlete.customRatio, for: athlete.profile)
        }
    }

    private func rememberTemporarySetup() {
        guard selectedAthleteID == nil else { return }
        temporarySetup = TemporarySetup(profile: profile, unit: measurementUnit, gtText: greaterTrochanterText,
                                        strategy: strategyKind, ratio: clarkRangeRatio)
    }

    private func useTemporarySetup() {
        storage.saveSelectedMiniHurdleProfileID(nil)
        selectedAthleteID = nil
        lastAutoSaveDate = nil
        profile = temporarySetup.profile
        measurementUnit = temporarySetup.unit
        greaterTrochanterText = temporarySetup.gtText
        strategyKind = temporarySetup.strategy
        clarkRangeRatio = temporarySetup.ratio
    }

    private func clampClarkRatioToCurrentProfile() {
        let clamped = clampStoredClarkRatio(clarkRangeRatio, for: profile)
        if abs(clamped - clarkRangeRatio) > 0.0001 {
            clarkRangeRatio = clamped
        }
    }

    private func changeMeasurementUnit(_ unit: MiniHurdleMeasurementUnit) {
        guard unit != measurementUnit else { return }
        if let meters = parsedGreaterTrochanterLength {
            greaterTrochanterText = unit.inputText(meters: meters)
        }
        measurementUnit = unit
        persistSelectedAthleteIfPossible()
    }

    private func persistSelectedAthleteIfPossible() {
        guard let selectedAthlete else { return }

        guard let updatedAthlete = makeAthleteProfile(
            id: selectedAthlete.id,
            name: selectedAthlete.name,
            timestamp: Date()
        ) else {
            return
        }

        storage.upsertMiniHurdleProfile(updatedAthlete)
        savedAthletes = storage.loadMiniHurdleProfiles()
        lastAutoSaveDate = Date()
    }

    private func presentToast(_ message: String) {
        toastMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            if toastMessage == message {
                toastMessage = nil
            }
        }
    }

    private func playSuccessHaptic() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func playLightHaptic() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func makeAthleteProfile(
        id: UUID,
        name: String,
        timestamp: Date
    ) -> MiniHurdleAthleteProfile? {
        guard let parsedGreaterTrochanterLength else { return nil }

        let persistedStrategyKind: MiniHurdleStrategyKind = strategyKind == .mannRecommended ? .mannRecommended : .clarkRange
        let persistedRatio = persistedStrategyKind == .mannRecommended ? nil : clampedClarkRangeRatio

        return MiniHurdleAthleteProfile(
            id: id,
            name: name,
            profile: profile,
            greaterTrochanterLength: parsedGreaterTrochanterLength,
            measurementUnit: measurementUnit,
            strategyKind: persistedStrategyKind,
            customRatio: persistedRatio,
            updatedAt: timestamp,
            lastUsedAt: timestamp
        )
    }

    private func validationMessage(
        for draft: MiniHurdleAthleteEditorDraft,
        name: String
    ) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "mini_hurdle_athlete_editor_empty_name".localized
        }

        let duplicate = savedAthletes.contains { athlete in
            athlete.id != draft.athleteID
                && athlete.name.compare(trimmed, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
        if duplicate {
            return "mini_hurdle_athlete_editor_duplicate_name".localized
        }

        return nil
    }

    private func saveAthleteDraft(
        _ draft: MiniHurdleAthleteEditorDraft,
        name: String,
        profile: MiniHurdleProfile,
        gtLength: Double,
        unit: MiniHurdleMeasurementUnit,
        strategyKind: MiniHurdleStrategyKind,
        customRatio: Double?
    ) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let now = Date()
        let persistedStrategyKind: MiniHurdleStrategyKind = strategyKind == .mannRecommended ? .mannRecommended : .clarkRange
        let persistedRatio = persistedStrategyKind == .mannRecommended ? nil : customRatio

        switch draft.mode {
        case .saveCurrent, .create:
            rememberTemporarySetup()
            let newAthlete = MiniHurdleAthleteProfile(
                id: UUID(),
                name: trimmed,
                profile: profile,
                greaterTrochanterLength: gtLength,
                measurementUnit: unit,
                strategyKind: persistedStrategyKind,
                customRatio: persistedRatio,
                updatedAt: now,
                lastUsedAt: now
            )

            storage.upsertMiniHurdleProfile(newAthlete)
            storage.saveSelectedMiniHurdleProfileID(newAthlete.id)
            savedAthletes = storage.loadMiniHurdleProfiles()
            selectedAthleteID = newAthlete.id
            // P3 修复：新建档案尚无自动同步，重置指示器避免显示上一档案时间。
            lastAutoSaveDate = nil
            applyAthlete(newAthlete)
            presentToast("mini_hurdle_toast_athlete_saved".localized)
            playSuccessHaptic()

        case .edit:
            guard let athleteID = draft.athleteID else { return }

            var athlete = savedAthletes.first(where: { $0.id == athleteID })
                ?? MiniHurdleAthleteProfile(
                    id: athleteID,
                    name: trimmed,
                    profile: profile,
                    greaterTrochanterLength: gtLength,
                    measurementUnit: unit,
                    strategyKind: persistedStrategyKind,
                    customRatio: persistedRatio,
                    updatedAt: now,
                    lastUsedAt: now
                )

            athlete.name = trimmed
            athlete.profile = profile
            athlete.greaterTrochanterLength = gtLength
            athlete.measurementUnit = unit
            athlete.strategyKind = persistedStrategyKind
            athlete.customRatio = persistedRatio
            athlete.updatedAt = now
            storage.upsertMiniHurdleProfile(athlete)
            savedAthletes = storage.loadMiniHurdleProfiles()

            if selectedAthleteID == athlete.id {
                storage.saveSelectedMiniHurdleProfileID(athlete.id)
                // P3 修复：编辑提交是显式动作而非自动同步，重置指示器。
                lastAutoSaveDate = nil
                applyAthlete(athlete)
            }
            presentToast("mini_hurdle_toast_athlete_updated".localized)
            playSuccessHaptic()
        }
    }

    private func selectAthlete(_ athlete: MiniHurdleAthleteProfile) {
        rememberTemporarySetup()
        var updatedAthlete = athlete
        updatedAthlete.lastUsedAt = Date()
        storage.upsertMiniHurdleProfile(updatedAthlete)
        storage.saveSelectedMiniHurdleProfileID(updatedAthlete.id)
        savedAthletes = storage.loadMiniHurdleProfiles()
        selectedAthleteID = updatedAthlete.id
        // P3 修复：切档后重置指示器，待下一次真实自动同步再显示新时间。
        lastAutoSaveDate = nil
        applyAthlete(updatedAthlete)
        presentToast(String(format: "mini_hurdle_toast_athlete_selected".localized, athlete.name))
        playLightHaptic()
    }

    private func deleteAthlete(_ athlete: MiniHurdleAthleteProfile) {
        let wasSelected = athlete.id == selectedAthleteID
        storage.deleteMiniHurdleProfile(athlete.id)
        savedAthletes = storage.loadMiniHurdleProfiles()
        presentToast("mini_hurdle_toast_athlete_deleted".localized)
        // Audit MH-9: deletion is a cautionary action, not a success celebration.
        playLightHaptic()

        guard wasSelected else { return }

        if let fallbackAthlete = savedAthletes.first {
            storage.saveSelectedMiniHurdleProfileID(fallbackAthlete.id)
            selectedAthleteID = fallbackAthlete.id
            applyAthlete(fallbackAthlete)
        } else {
            useTemporarySetup()
        }
    }
}

/// Audit MH-6: capsule segments in the domain accent — the system segmented
/// style ignores view tint on iOS 26, so the module ships its own two-state
/// capsule picker matching the training editors' chips. File-scope so both
/// the main view and the athlete editor share it.
@ViewBuilder
private func miniSegmentedPicker<T: Hashable>(
    selection: Binding<T>,
    options: [T],
    label: @escaping (T) -> String
) -> some View {
    HStack(spacing: 2) {
        ForEach(options, id: \.self) { option in
            let selected = option == selection.wrappedValue
            Button {
                guard !selected else { return }
                selection.wrappedValue = option
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Text(label(option))
                    .font(.system(size: 14, weight: selected ? .medium : .regular))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                    .foregroundStyle(selected ? DS.Colors.textPrimary : DS.Colors.textTertiary)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                            .fill(selected ? DS.Colors.field : Color.clear)
                    )
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(selected ? DS.Colors.miniHurdle : Color.clear)
                            .frame(height: 2)
                            .padding(.horizontal, 10)
                            .padding(.bottom, 1)
                    }
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(selected ? .isSelected : [])
        }
    }
    .padding(2)
    .background(
        RoundedRectangle(cornerRadius: DS.Radius.md + 2, style: .continuous)
            .fill(DS.Colors.card)
    )
    .overlay(
        RoundedRectangle(cornerRadius: DS.Radius.md + 2, style: .continuous)
            .stroke(DS.Colors.borderLight, lineWidth: 1)
    )
}

private struct MiniHurdleSectionCard<Content: View>: View {
    let title: String
    var subtitle: String?
    var accent: Color?
    var stepIndex: String?
    var status: String?
    var statusTint: Color
    let content: Content

    init(
        title: String,
        subtitle: String? = nil,
        accent: Color? = nil,
        stepIndex: String? = nil,
        status: String? = nil,
        statusTint: Color = DS.Colors.textSecondary,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.accent = accent
        self.stepIndex = stepIndex
        self.status = status
        self.statusTint = statusTint
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.md) {
            VStack(alignment: .leading, spacing: DS.Space.xxs) {
                HStack(alignment: .firstTextBaseline, spacing: DS.Space.sm) {
                    if let stepIndex {
                        Text(stepIndex)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(accent ?? DS.Colors.miniHurdle)
                            .accessibilityHidden(true)
                    }

                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DS.Colors.textPrimary)

                    Spacer(minLength: 8)

                    if let status, !status.isEmpty {
                        Text(status)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(statusTint)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(DS.Colors.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            content
        }
        .dsCard()
    }
}

private enum MiniHurdleAthleteEditorMode {
    case saveCurrent, create, edit

    var title: String {
        switch self {
        case .saveCurrent:
            return "mini_hurdle_athlete_save_button".localized
        case .create:
            return "mini_hurdle_athlete_editor_create_title".localized
        case .edit:
            return "mini_hurdle_athlete_editor_edit_title".localized
        }
    }

    var saveButtonTitle: String {
        switch self {
        case .saveCurrent, .create:
            return "mini_hurdle_athlete_editor_create_confirm".localized
        case .edit:
            return "mini_hurdle_athlete_editor_edit_confirm".localized
        }
    }
}

private struct MiniHurdleAthleteEditorDraft: Identifiable {
    let id = UUID()
    let mode: MiniHurdleAthleteEditorMode
    let athleteID: UUID?
    let name: String
    var profile: MiniHurdleProfile = .women
    var greaterTrochanterLength: Double = 0.86
    var measurementUnit: MiniHurdleMeasurementUnit = .centimeters
    var strategyKind: MiniHurdleStrategyKind = .mannRecommended
    var customRatio: Double? = nil
}

private struct MiniHurdleAthleteEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var showDeleteConfirmation = false
    @State private var editorProfile: MiniHurdleProfile
    @State private var editorMeasurementUnit: MiniHurdleMeasurementUnit
    @State private var editorGtText: String
    @State private var editorStrategyKind: MiniHurdleStrategyKind
    @State private var editorCustomRatio: Double

    let mode: MiniHurdleAthleteEditorMode
    let summaryTitle: String
    let summaryText: String
    let syncNote: String
    let validateName: (String) -> String?
    let onSave: (String, MiniHurdleProfile, Double, MiniHurdleMeasurementUnit, MiniHurdleStrategyKind, Double?) -> Void
    let onDelete: (() -> Void)?

    private var parsedGtLength: Double? { editorMeasurementUnit.meters(from: editorGtText) }

    private var validationMessage: String? {
        validateName(name)
    }

    private var canSave: Bool {
        validationMessage == nil && parsedGtLength != nil
    }

    // P3 修复：编辑器与主页共用同一软警告口径（50–120 cm 之外提示复核）。
    private var isGtOutOfRange: Bool {
        guard let parsedGtLength else { return false }
        return parsedGtLength < 0.5 || parsedGtLength > 1.2
    }

    private var clarkRange: ClosedRange<Double> {
        editorProfile.clarkLowerRatio...editorProfile.clarkUpperRatio
    }

    private var clampedCustomRatio: Double {
        min(max(editorCustomRatio, clarkRange.lowerBound), clarkRange.upperBound)
    }

    init(
        mode: MiniHurdleAthleteEditorMode,
        initialName: String,
        summaryTitle: String,
        summaryText: String,
        syncNote: String,
        draft: MiniHurdleAthleteEditorDraft,
        validateName: @escaping (String) -> String?,
        onSave: @escaping (String, MiniHurdleProfile, Double, MiniHurdleMeasurementUnit, MiniHurdleStrategyKind, Double?) -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.mode = mode
        self.summaryTitle = summaryTitle
        self.summaryText = summaryText
        self.syncNote = syncNote
        self.validateName = validateName
        self.onSave = onSave
        self.onDelete = onDelete
        _name = State(initialValue: initialName)
        _editorProfile = State(initialValue: draft.profile)
        _editorMeasurementUnit = State(initialValue: draft.measurementUnit)
        _editorStrategyKind = State(initialValue: draft.strategyKind)
        _editorCustomRatio = State(initialValue: draft.customRatio ?? draft.profile.mannRecommendedRatio)

        _editorGtText = State(initialValue: draft.measurementUnit.inputText(meters: draft.greaterTrochanterLength))
    }

    var body: some View {
        NavigationStack {
            // Audit MH-4: module-native cards replace the system Form so the
            // editor shares the dark-card / teal design language of the page.
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                MiniHurdleSectionCard(
                    title: "mini_hurdle_athlete_editor_name_section".localized,
                    accent: DS.Colors.miniHurdle
                ) {
                    TextField("mini_hurdle_athlete_editor_name_placeholder".localized, text: $name)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .font(.body.weight(.semibold))
                        .padding(.horizontal, 12)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(DS.Colors.field)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(DS.Colors.fieldBorder, lineWidth: 1)
                        )
                        .accessibilityIdentifier("mini_hurdle_athlete_name_textfield")

                    if !name.isEmpty, let validationMessage {
                        Text(validationMessage)
                            .font(.caption)
                            .foregroundStyle(DS.Colors.warning)
                    }
                }

                if mode == .saveCurrent {
                    MiniHurdleSectionCard(
                        title: summaryTitle,
                        accent: DS.Colors.miniHurdle
                    ) {
                        Text(summaryText)
                            .font(.subheadline)
                            .foregroundStyle(DS.Colors.textPrimary)
                        Text(syncNote)
                            .font(.caption)
                            .foregroundStyle(DS.Colors.textSecondary)
                    }
                } else {
                    MiniHurdleSectionCard(
                        title: "mini_hurdle_profile".localized,
                        accent: DS.Colors.miniHurdle
                    ) {
                        miniSegmentedPicker(
                            selection: $editorProfile,
                            options: MiniHurdleProfile.allCases
                        ) { $0.displayName }
                    }

                    MiniHurdleSectionCard(
                        title: "mini_hurdle_measurement_gt_title".localized,
                        accent: DS.Colors.miniHurdle
                    ) {
                        miniSegmentedPicker(
                            selection: Binding(get: { editorMeasurementUnit }, set: { unit in
                                if let meters = parsedGtLength { editorGtText = unit.inputText(meters: meters) }
                                editorMeasurementUnit = unit
                            }),
                            options: MiniHurdleMeasurementUnit.allCases
                        ) { $0.displayName }

                        HStack {
                            TextField(
                                editorMeasurementUnit == .centimeters ? "86" : "0.86",
                                text: $editorGtText
                            )
                            .accessibilityIdentifier("mini_hurdle_editor_gt_input")
                            .keyboardType(.decimalPad)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .font(.system(.body, design: .monospaced).weight(.semibold))
                            .monospacedDigit()

                            Spacer()

                            Text(editorMeasurementUnit.displayName)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(DS.Colors.textSecondary)
                        }
                        .padding(.horizontal, 12)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(DS.Colors.field)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(
                                    isGtOutOfRange ? DS.Colors.warning.opacity(0.8) : DS.Colors.fieldBorder,
                                    lineWidth: 1
                                )
                        )

                        if isGtOutOfRange {
                            Text("mini_hurdle_gt_out_of_range_hint".localized)
                                .font(.caption)
                                .foregroundStyle(DS.Colors.warning)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    MiniHurdleSectionCard(
                        title: "mini_hurdle_strategy_mode_title".localized,
                        accent: DS.Colors.miniHurdle
                    ) {
                        miniSegmentedPicker(
                            selection: $editorStrategyKind,
                            options: [MiniHurdleStrategyKind.mannRecommended, .clarkRange]
                        ) { kind in
                            kind == .mannRecommended
                                ? "mini_hurdle_strategy_mann".localized
                                : "mini_hurdle_strategy_clark_range".localized
                        }

                        if editorStrategyKind == .clarkRange {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("mini_hurdle_strategy_clark_slider_title".localized)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(DS.Colors.textSecondary)
                                    Spacer()
                                    Text(String(format: "%.2f×GT", clampedCustomRatio))
                                        .font(.system(.footnote, design: .monospaced).weight(.semibold))
                                        .monospacedDigit()
                                        .foregroundStyle(DS.Colors.miniHurdle)
                                }

                                Slider(value: $editorCustomRatio, in: clarkRange, step: 0.01)
                                    .tint(DS.Colors.miniHurdle)

                                HStack {
                                    Text(String(format: "%.2f", editorProfile.clarkLowerRatio))
                                    Spacer()
                                    Text(String(format: "%.2f", editorProfile.mannRecommendedRatio))
                                    Spacer()
                                    Text(String(format: "%.2f", editorProfile.clarkUpperRatio))
                                }
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(DS.Colors.textSecondary)
                            }
                        } else {
                            Text(String(
                                format: "mini_hurdle_strategy_mann_inline_note".localized,
                                String(format: "%.2f", editorProfile.mannRecommendedRatio),
                                parsedGtLength.map {
                                    MiniHurdleFormatting.distance($0 * editorProfile.mannRecommendedRatio)
                                } ?? "--"
                            ))
                            .font(.caption)
                            .foregroundStyle(DS.Colors.textSecondary)
                        }
                    }
                }

                if onDelete != nil {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("mini_hurdle_athlete_delete_button".localized, systemImage: "trash")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(DS.Colors.error)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(DS.Colors.card)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(DS.Colors.error.opacity(0.40), lineWidth: 1)
                            )
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityIdentifier("mini_hurdle_athlete_delete_button")
                }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
                .dsReadableColumn(640)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(TrainingPageBackground())
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                DSModalHeader(
                    title: mode.title,
                    leadingTitle: "cancel".localized,
                    leadingIdentifier: "mini_hurdle_athlete_editor_cancel",
                    trailingTitle: mode.saveButtonTitle,
                    trailingIdentifier: "mini_hurdle_athlete_editor_save",
                    trailingDisabled: !canSave
                ) {
                    dismiss()
                } trailingAction: {
                    guard let gt = parsedGtLength else { return }
                    let ratio: Double? = editorStrategyKind == .mannRecommended ? nil : clampedCustomRatio
                    onSave(name, editorProfile, gt, editorMeasurementUnit, editorStrategyKind, ratio)
                    dismiss()
                }
            }
            .confirmationDialog(
                "mini_hurdle_athlete_delete_title".localized,
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("mini_hurdle_athlete_delete_confirm".localized, role: .destructive) {
                    onDelete?()
                    dismiss()
                }
                .accessibilityIdentifier("mini_hurdle_athlete_delete_confirm")

                Button("cancel".localized, role: .cancel) {}
            } message: {
                Text("mini_hurdle_athlete_delete_message".localized)
            }
        }
        .presentationDetents([.large])
    }
}

private struct MiniHurdleAthleteListView: View {
    @Environment(\.dismiss) private var dismiss

    let savedAthletes: [MiniHurdleAthleteProfile]
    let selectedAthleteID: UUID?
    let summaryText: (MiniHurdleAthleteProfile) -> String
    let onSelect: (MiniHurdleAthleteProfile) -> Void
    let onEdit: (MiniHurdleAthleteEditorDraft) -> Void
    let onDelete: (MiniHurdleAthleteProfile) -> Void
    let onCreateNew: () -> Void

    @State private var athleteToDelete: MiniHurdleAthleteProfile?
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            Group {
                if savedAthletes.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.2.circle")
                            .font(.system(size: 48))
                            .foregroundStyle(DS.Colors.textTertiary)
                        Text("mini_hurdle_athlete_list_empty".localized)
                            .font(.headline)
                            .foregroundStyle(DS.Colors.textSecondary)
                        Text("mini_hurdle_athlete_list_empty_hint".localized)
                            .font(.subheadline)
                            .foregroundStyle(DS.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(savedAthletes) { athlete in
                            HStack(spacing: DS.Space.sm) {
                                Button {
                                    onSelect(athlete)
                                    dismiss()
                                } label: {
                                    HStack(spacing: DS.Space.sm) {
                                        if athlete.id == selectedAthleteID {
                                            Image(systemName: "checkmark")
                                                .foregroundStyle(DS.Colors.miniHurdle)
                                        }
                                        VStack(alignment: .leading, spacing: DS.Space.xxs) {
                                            Text(athlete.name)
                                                .font(.body.weight(.medium))
                                                .foregroundStyle(DS.Colors.textPrimary)
                                            Text(summaryText(athlete))
                                                .font(.caption)
                                                .foregroundStyle(DS.Colors.textSecondary)
                                        }
                                        Spacer(minLength: 0)
                                    }
                                    .frame(minHeight: 44)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(athlete.id == selectedAthleteID ? .isSelected : [])
                                .accessibilityIdentifier("mini_hurdle_list_select_\(athlete.name)")

                                Button {
                                    onEdit(MiniHurdleAthleteEditorDraft(
                                        mode: .edit, athleteID: athlete.id, name: athlete.name,
                                        profile: athlete.profile, greaterTrochanterLength: athlete.greaterTrochanterLength,
                                        measurementUnit: athlete.measurementUnit, strategyKind: athlete.strategyKind,
                                        customRatio: athlete.customRatio
                                    ))
                                } label: {
                                    Image(systemName: "square.and.pencil")
                                        .foregroundStyle(DS.Colors.textSecondary)
                                        .frame(width: 44, height: 44)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("mini_hurdle_athlete_manage_button".localized)
                                .accessibilityIdentifier("mini_hurdle_list_edit_\(athlete.name)")
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(DS.Colors.card, in: RoundedRectangle(cornerRadius: 14))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    athleteToDelete = athlete
                                    showDeleteConfirmation = true
                                } label: {
                                    Label("mini_hurdle_athlete_delete_button".localized, systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(DS.Colors.bg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                DSModalHeader(
                    title: "mini_hurdle_athlete_list_title".localized,
                    leadingTitle: "cancel".localized,
                    trailingTitle: "mini_hurdle_athlete_new_short".localized,
                    trailingIdentifier: "mini_hurdle_athlete_list_add_button"
                ) {
                    dismiss()
                } trailingAction: {
                    onCreateNew()
                }
            }
            .confirmationDialog(
                "mini_hurdle_athlete_delete_title".localized,
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("mini_hurdle_athlete_delete_confirm".localized, role: .destructive) {
                    if let athleteToDelete {
                        onDelete(athleteToDelete)
                        self.athleteToDelete = nil
                    }
                }
                Button("cancel".localized, role: .cancel) {
                    athleteToDelete = nil
                }
            } message: {
                Text("mini_hurdle_athlete_delete_message".localized)
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct MiniMetricTile: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.xxs) {
            Text(title)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(DS.Colors.textTertiary)
                .fixedSize(horizontal: false, vertical: true)

            Text(value)
                .font(.system(size: 22, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(DS.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
    }
}

private struct MiniValueRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(DS.Colors.textSecondary)
            Spacer()
            Text(value)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(DS.Colors.textPrimary)
        }
        .padding(.vertical, DS.Space.sm)
        .overlay(alignment: .bottom) {
            Rectangle().fill(DS.Colors.divider).frame(height: 1)
        }
    }
}

private struct MiniWorksheetSequenceRow: View {
    let mark: MiniHurdleMark

    private var hurdleNumber: Int? {
        guard mark.worksheetStepNumber >= 8 else { return nil }
        return mark.worksheetStepNumber - 7
    }

    private var title: String {
        if mark.worksheetStepNumber == 0 {
            return "mini_hurdle_mark_start".localized
        }
        if mark.worksheetStepNumber <= 7 {
            return String(format: "mini_hurdle_main_acc_mark".localized, mark.stepNumber)
        }
        return String(format: "mini_hurdle_main_hurdle_mark".localized, mark.stepNumber)
    }

    var body: some View {
        GridRow {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(DS.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .gridColumnAlignment(.leading)

            Text("\(mark.worksheetStepNumber)")
                .font(.system(.caption, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(DS.Colors.textSecondary)

            Text(MiniHurdleFormatting.distance(mark.spacing))
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(mark.worksheetStepNumber == 0 ? DS.Colors.textSecondary : DS.Colors.textPrimary)
                .accessibilityIdentifier(
                    hurdleNumber.map { "mini_hurdle_spacing_\($0)" }
                        ?? "mini_hurdle_sequence_spacing_\(mark.worksheetStepNumber)"
                )

            Text(MiniHurdleFormatting.value(mark.cumulativePosition))
                .font(.system(.caption, design: .monospaced).weight(.medium))
                .monospacedDigit()
                .foregroundStyle(DS.Colors.textSecondary)
                .accessibilityIdentifier(
                    hurdleNumber.map { "mini_hurdle_point_\($0)" }
                        ?? "mini_hurdle_sequence_point_\(mark.worksheetStepNumber)"
                )
        }
    }
}

private struct MiniCalloutCard: View {
    var title: String = ""
    let detail: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.xxs) {
            if !title.isEmpty {
                HStack(alignment: .firstTextBaseline, spacing: DS.Space.sm) {
                    DSLaneTick(length: 12, color: accent)
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(accent == DS.Colors.warning ? DS.Colors.warning : DS.Colors.textPrimary)
                }
            }
            Text(detail)
                .font(.system(size: 12))
                .foregroundStyle(DS.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, title.isEmpty ? 0 : 12 + DS.Space.sm)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MiniStageBlock: View {
    var index: String = ""
    let title: String
    let data: String
    var data2: String = ""
    let cue: String

    var body: some View {
        HStack(alignment: .top, spacing: DS.Space.md) {
            if !index.isEmpty {
                Text(index)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(DS.Colors.textTertiary)
                    .padding(.top, 2)
            }

            VStack(alignment: .leading, spacing: DS.Space.xxs) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(DS.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(data)
                    .font(.system(size: 12, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(DS.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if !data2.isEmpty {
                    Text(data2)
                        .font(.system(size: 12, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(DS.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(cue)
                    .font(.system(size: 12))
                    .foregroundStyle(DS.Colors.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MiniExpertCard: View {
    let title: String
    let detail: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.xxs) {
            HStack(alignment: .firstTextBaseline, spacing: DS.Space.sm) {
                DSLaneTick(length: 12, color: accent)
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(DS.Colors.textPrimary)
            }
            Text(detail)
                .font(.system(size: 12))
                .foregroundStyle(DS.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 12 + DS.Space.sm)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MiniGuideStepRow: View {
    let index: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(index)")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(DS.Colors.textSecondary)
                .frame(width: 20, height: 20)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                        .fill(DS.Colors.field)
                )
            Text(text)
                .font(.caption)
                .foregroundStyle(DS.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct MiniBulletRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(DS.Colors.textHint)
                .frame(width: 4, height: 4)
                .padding(.top, 8)
            Text(text)
                .font(.caption)
                .foregroundStyle(DS.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct MiniHurdleIllustration: View {
    let assetName: String
    let accent: Color

    var body: some View {
        MiniGTMeasurementDiagram(assetName: assetName, accent: accent)
            .id("mini_hurdle_anchor_measurement_vertical")
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .accessibilityLabel("mini_hurdle_measurement_illustration_a11y".localized)
        .accessibilityIdentifier("mini_hurdle_gt_measurement_diagram")
    }
}

private struct MiniGTMeasurementDiagram: View {
    let assetName: String
    let accent: Color

    /// 锚点位置以图片尺寸的相对比例定义，随渲染尺寸缩放，避免硬编码像素漂移。
    /// 坐标基于 941×1672 原图测算：大转子红点 (0.40, 0.21)、垂直量尺 (0.19, 0.20~0.38)、
    /// 髂嵴错误点 (0.40, 0.19)、斜量错误线 (0.41, 0.23)。
    private struct AnchorSpec {
        let identifier: String
        let label: String
        let x: CGFloat
        let y: CGFloat
        let width: CGFloat
        let height: CGFloat
    }

    private var anchors: [AnchorSpec] {
        [
            AnchorSpec(
                identifier: "mini_hurdle_gt_marker",
                label: "mini_hurdle_measurement_gt_label".localized,
                x: 0.35, y: 0.175, width: 0.10, height: 0.056
            ),
            AnchorSpec(
                identifier: "mini_hurdle_vertical_measure_line",
                label: "mini_hurdle_measurement_vertical_to_floor".localized,
                x: 0.13, y: 0.20, width: 0.12, height: 0.18
            ),
            AnchorSpec(
                identifier: "mini_hurdle_wrong_iliac",
                label: "mini_hurdle_measurement_wrong_iliac_title".localized,
                x: 0.33, y: 0.148, width: 0.09, height: 0.050
            ),
            AnchorSpec(
                identifier: "mini_hurdle_wrong_diagonal",
                label: "mini_hurdle_measurement_wrong_diagonal_title".localized,
                x: 0.385, y: 0.228, width: 0.075, height: 0.042
            )
        ]
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                Image(assetName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                            .stroke(accent.opacity(0.4), lineWidth: 1)
                    )
                    .accessibilityIdentifier("mini_hurdle_measurement_full_image")
                    .accessibilityLabel("mini_hurdle_measurement_illustration_a11y".localized)

                ForEach(anchors, id: \.identifier) { anchor in
                    measurementAnchor(identifier: anchor.identifier, label: anchor.label)
                        .frame(
                            width: geometry.size.width * anchor.width,
                            height: geometry.size.height * anchor.height
                        )
                        .offset(
                            x: geometry.size.width * anchor.x,
                            y: geometry.size.height * anchor.y
                        )
                }
            }
        }
        .aspectRatio(941 / 1672, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }

    private func measurementAnchor(identifier: String, label: String) -> some View {
        Color.clear
            .contentShape(Rectangle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityIdentifier(identifier)
    }
}

private enum MiniHurdleFormatting {
    static func distance(_ measurement: Double) -> String {
        "\(value(measurement)) \("unit_meter_short".localized)"
    }

    static func value(_ measurement: Double) -> String {
        let threeDecimalText = String(format: "%.3f", measurement)
        if threeDecimalText.hasSuffix("0") {
            return String(format: "%.2f", measurement)
        }
        return threeDecimalText
    }
}

#Preview {
    NavigationStack {
        MiniHurdleSpacingView()
    }
}
