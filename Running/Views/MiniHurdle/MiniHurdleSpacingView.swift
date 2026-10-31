import SwiftUI

struct MiniHurdleSpacingView: View {
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
    @State private var isApplyingSavedAthlete = false
    @State private var hasLoadedAthletes = false
    @State private var measurementGuideExpanded = false
    @State private var methodGuideExpanded = false
    @State private var qualityGuideExpanded = false
    @State private var showAthleteList = false
    @State private var toastMessage: String?
    @State private var lastAutoSaveDate: Date?

    private var parsedGreaterTrochanterLength: Double? {
        let sanitized = sanitizeDecimalInput(greaterTrochanterText)
        guard let value = Double(sanitized), value > 0 else { return nil }
        switch measurementUnit {
        case .centimeters:
            return value / 100
        case .meters:
            return value
        }
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

    private var athleteSectionSubtitle: String {
        selectedAthlete == nil
            ? "mini_hurdle_athlete_temporary_subtitle".localized
            : "mini_hurdle_athlete_saved_subtitle".localized
    }

    private var athleteDisplayName: String {
        selectedAthlete?.name ?? "mini_hurdle_athlete_temporary_name".localized
    }

    private var athleteBadgeText: String {
        selectedAthlete == nil
            ? "mini_hurdle_athlete_temporary_badge".localized
            : "mini_hurdle_athlete_saved_badge".localized
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
                    heroSection
                        .id("mini_hurdle_anchor_top")
                    setupSection
                        .id("mini_hurdle_anchor_middle")

                    if let result {
                        resultsSection(result)
                            .id("mini_hurdle_anchor_layout")
                        progressionSection(result)
                    } else {
                        invalidStateSection
                    }

                    athleteSection
                    measurementGuideSection
                        .id("mini_hurdle_anchor_measurement")
                    researchSection
                    qualitySection
                        .id("mini_hurdle_anchor_bottom")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .accessibilityIdentifier("mini_hurdle_scroll")
            .background(TrainingPageBackground())
            .overlay(alignment: .top) {
                if let toastMessage {
                    Text(toastMessage)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule(style: .continuous)
                                .fill(DS.Colors.miniHurdle)
                        )
                        .shadow(color: .black.opacity(0.35), radius: 8, y: 3)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .accessibilityAddTraits(.isStaticText)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: toastMessage)
            .sheet(item: $editorDraft) { draft in
                MiniHurdleAthleteEditorSheet(
                    mode: draft.mode,
                    initialName: draft.name,
                    summaryTitle: "mini_hurdle_athlete_editor_summary_title".localized,
                    summaryText: draft.mode == .create ? currentSetupSummary : athleteConfigSummary,
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
            .sheet(isPresented: $showAthleteList) {
                MiniHurdleAthleteListView(
                    savedAthletes: savedAthletes,
                    selectedAthleteID: selectedAthleteID,
                    summaryText: { athlete in athleteSummary(for: athlete) },
                    onSelect: { athlete in selectAthlete(athlete) },
                    onEdit: { draft in editorDraft = draft },
                    onDelete: { athlete in deleteAthlete(athlete) },
                    onCreateNew: {
                        editorDraft = MiniHurdleAthleteEditorDraft(
                            mode: .create,
                            athleteID: nil,
                            name: "",
                            profile: profile,
                            greaterTrochanterLength: parsedGreaterTrochanterLength ?? 0.86,
                            measurementUnit: measurementUnit,
                            strategyKind: strategyKind,
                            customRatio: activeStoredRatio
                        )
                    }
                )
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            // Audit B4: solid dark bar once content scrolls underneath,
            // so the title no longer floats over passing text.
            .toolbarBackground(DS.Colors.bg, for: .navigationBar)
            .toolbar {
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
            .onChange(of: profile) { _, _ in
                clampClarkRatioToCurrentProfile()
                persistSelectedAthleteIfPossible()
            }
            .onChange(of: measurementUnit) { oldValue, newValue in
                guard oldValue != newValue else { return }
                handleMeasurementUnitChange(from: oldValue, to: newValue)
            }
            .onChange(of: greaterTrochanterText) { _, _ in
                persistSelectedAthleteIfPossible()
            }
            .onChange(of: strategyKind) { _, _ in
                clampClarkRatioToCurrentProfile()
                persistSelectedAthleteIfPossible()
            }
            .onChange(of: clarkRangeRatio) { _, _ in
                persistSelectedAthleteIfPossible()
            }
        }
    }

    private var heroSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "ruler")
                .font(.title3.weight(.semibold))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("mini_hurdle_hero_title".localized)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)

                Text("mini_hurdle_desc".localized)
                    .font(.caption)
                    .opacity(0.92)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [DS.Colors.miniHurdle, DS.Colors.miniHurdle.opacity(0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var athleteSection: some View {
        MiniHurdleSectionCard(
            title: "mini_hurdle_athlete_title".localized,
            subtitle: athleteSectionSubtitle,
            accent: DS.Colors.miniHurdle
        ) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    // Inline athlete selector
                    Menu {
                        Button {
                            // Deselect - switch to temporary input
                            if selectedAthlete != nil {
                                storage.saveSelectedMiniHurdleProfileID(nil)
                                selectedAthleteID = nil
                                savedAthletes = storage.loadMiniHurdleProfiles()
                                restoreTemporaryDefaults()
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
                        HStack(spacing: 8) {
                            Image(systemName: "person.circle.fill")
                                .font(.title3)
                                .foregroundStyle(DS.Colors.miniHurdle)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(athleteDisplayName)
                                    .font(.headline)
                                    .foregroundStyle(DS.Colors.textPrimary)
                                    .accessibilityIdentifier("mini_hurdle_current_athlete_name")

                                Text(athleteConfigSummary)
                                    .font(.caption)
                                    .foregroundStyle(DS.Colors.textSecondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }

                            Spacer(minLength: 4)

                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(DS.Colors.textSecondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(DS.Colors.field)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(DS.Colors.miniHurdle.opacity(0.45), lineWidth: 1)
                        )
                    }
                    .accessibilityIdentifier("mini_hurdle_athlete_switch_button")

                    Text(athleteBadgeText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(selectedAthlete == nil ? DS.Colors.warning : DS.Colors.success)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule(style: .continuous)
                                .fill((selectedAthlete == nil ? DS.Colors.warning : DS.Colors.success).opacity(0.18))
                        )
                }

                HStack(spacing: 8) {
                    MiniHurdleAthleteActionButton(
                        icon: selectedAthlete == nil ? "square.and.arrow.down" : "plus.circle.fill",
                        text: selectedAthlete == nil
                            ? "mini_hurdle_athlete_save_button".localized
                            : "mini_hurdle_athlete_save_as_new_button".localized,
                        tint: DS.Colors.miniHurdle,
                        isDisabled: !canSaveCurrentSetupAsAthlete,
                        accessibilityIdentifier: "mini_hurdle_athlete_save_button"
                    ) {
                        editorDraft = MiniHurdleAthleteEditorDraft(
                            mode: .create,
                            athleteID: nil,
                            name: "",
                            profile: profile,
                            greaterTrochanterLength: parsedGreaterTrochanterLength ?? 0.86,
                            measurementUnit: measurementUnit,
                            strategyKind: strategyKind,
                            customRatio: activeStoredRatio
                        )
                    }

                    if let selectedAthlete {
                        MiniHurdleAthleteActionButton(
                            icon: "square.and.pencil",
                            text: "mini_hurdle_athlete_manage_button".localized,
                            tint: DS.Colors.paceRun,
                            accessibilityIdentifier: "mini_hurdle_athlete_manage_button"
                        ) {
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
                        }
                    }
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

                if !savedAthletes.isEmpty {
                    MiniHurdleAthleteActionButton(
                        icon: "person.2.circle",
                        text: "mini_hurdle_athlete_list_manage_button".localized,
                        tint: DS.Colors.textSecondary,
                        accessibilityIdentifier: "mini_hurdle_athlete_list_button"
                    ) {
                        showAthleteList = true
                    }
                }
            }
        }
    }

    private func setupPickerColumn(
        title: String,
        selection: Binding<MiniHurdleProfile>,
        options: [MiniHurdleProfile]
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))

            Picker(title, selection: selection) {
                ForEach(options) { option in
                    Text(option.displayName).tag(option)
                }
            }
            .pickerStyle(.segmented)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func setupPickerColumn(
        title: String,
        selection: Binding<MiniHurdleMeasurementUnit>,
        options: [MiniHurdleMeasurementUnit]
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))

            Picker(title, selection: selection) {
                ForEach(options) { option in
                    Text(option.displayName).tag(option)
                }
            }
            .pickerStyle(.segmented)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var setupSection: some View {
        MiniHurdleSectionCard(
            title: "mini_hurdle_setup_title".localized,
            subtitle: "mini_hurdle_setup_subtitle".localized,
            accent: DS.Colors.miniHurdle
        ) {
            VStack(alignment: .leading, spacing: 8) {
                setupPickerColumn(
                    title: "mini_hurdle_profile".localized,
                    selection: $profile,
                    options: MiniHurdleProfile.allCases
                )

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 8) {
                        setupPickerColumn(
                            title: "mini_hurdle_measurement_unit".localized,
                            selection: $measurementUnit,
                            options: MiniHurdleMeasurementUnit.allCases
                        )
                        compactGTInputCard
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        setupPickerColumn(
                            title: "mini_hurdle_measurement_unit".localized,
                            selection: $measurementUnit,
                            options: MiniHurdleMeasurementUnit.allCases
                        )
                        compactGTInputCard
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("mini_hurdle_strategy_mode_title".localized)
                        .font(.subheadline.weight(.semibold))

                    Picker("mini_hurdle_strategy_mode_title".localized, selection: strategySelectionBinding) {
                        Text("mini_hurdle_strategy_mann".localized).tag(MiniHurdleStrategyKind.mannRecommended)
                        Text("mini_hurdle_strategy_clark_range".localized).tag(MiniHurdleStrategyKind.clarkRange)
                    }
                    .pickerStyle(.segmented)

                    if activeStrategyDisplayKind == .clarkRange {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline) {
                                Text("mini_hurdle_strategy_clark_slider_title".localized)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(DS.Colors.textSecondary)
                                Spacer()
                                Text(ratioText(clampedClarkRangeRatio))
                                    .font(.system(.footnote, design: .monospaced).weight(.semibold))
                                    .monospacedDigit()
                                    .foregroundStyle(DS.Colors.interval)
                            }

                            Slider(
                                value: $clarkRangeRatio,
                                in: clarkRatioRange,
                                step: 0.01
                            )
                            .tint(DS.Colors.interval)
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
                                .font(.caption)
                                .foregroundStyle(DS.Colors.interval)
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
                                .stroke(DS.Colors.interval.opacity(0.45), lineWidth: 1)
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
            }
        }
    }

    private var compactGTInputCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("mini_hurdle_measurement_gt_title".localized)
                .font(.subheadline.weight(.semibold))

            HStack(spacing: 8) {
                Button {
                    adjustGreaterTrochanter(byDisplayUnits: measurementUnit == .centimeters ? -1 : -0.01)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(DS.Colors.miniHurdle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("mini_hurdle_gt_decrease".localized)
                .accessibilityIdentifier("mini_hurdle_gt_step_down")

                TextField(
                    measurementUnit == .centimeters ? "86" : "0.86",
                    text: Binding(
                        get: { greaterTrochanterText },
                        set: { greaterTrochanterText = sanitizeDecimalInput($0) }
                    )
                )
                .keyboardType(.decimalPad)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .font(.system(.title3, design: .monospaced).weight(.semibold))
                .monospacedDigit()
                .multilineTextAlignment(.center)
                .foregroundStyle(DS.Colors.textPrimary)
                .accessibilityIdentifier("mini_hurdle_gt_input")

                Text(measurementUnit.displayName)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(DS.Colors.textSecondary)

                Button {
                    adjustGreaterTrochanter(byDisplayUnits: measurementUnit == .centimeters ? 1 : 0.01)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(DS.Colors.miniHurdle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("mini_hurdle_gt_increase".localized)
                .accessibilityIdentifier("mini_hurdle_gt_step_up")
            }
            .padding(.horizontal, 12)
            .frame(height: 42)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(DS.Colors.field)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        isGTInputInvalid ? DS.Colors.warning.opacity(0.8) : DS.Colors.miniHurdle.opacity(0.45),
                        lineWidth: 1
                    )
            )

            if isGTInputInvalid {
                Text("mini_hurdle_invalid_gt_hint".localized)
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
                .foregroundStyle(DS.Colors.miniHurdle)
            } else {
                Text("mini_hurdle_measurement_gt_hint".localized)
                    .font(.caption)
                    .foregroundStyle(DS.Colors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var measurementGuideSection: some View {
        MiniHurdleSectionCard(
            title: "mini_hurdle_measurement_title".localized,
            subtitle: "mini_hurdle_measurement_subtitle".localized,
            accent: DS.Colors.miniHurdle
        ) {
            VStack(alignment: .leading, spacing: 14) {
                MiniHurdleIllustration(
                    assetName: measurementGuideAssetName,
                    accent: DS.Colors.miniHurdle
                )
                    .padding(.bottom, 2)
                    .accessibilityIdentifier("mini_hurdle_measurement_illustration")

                Text("mini_hurdle_measurement_source_note".localized)
                    .font(.caption2)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("mini_hurdle_measurement_source_note")

                DisclosureGroup(isExpanded: $measurementGuideExpanded) {
                    VStack(alignment: .leading, spacing: 12) {
                        MiniCalloutCard(
                            title: "mini_hurdle_measurement_definition_title".localized,
                            detail: "mini_hurdle_measurement_definition_body".localized,
                            accent: DS.Colors.miniHurdle
                        )

                        MiniCalloutCard(
                            title: "mini_hurdle_measurement_partner_title".localized,
                            detail: "mini_hurdle_measurement_partner_body".localized,
                            accent: DS.Colors.interval
                        )

                        VStack(alignment: .leading, spacing: 10) {
                            MiniGuideStepRow(index: 1, text: "mini_hurdle_measurement_cue_lateral_body".localized)
                            MiniGuideStepRow(index: 2, text: "mini_hurdle_measurement_cue_rotation_body".localized)
                            MiniGuideStepRow(index: 3, text: "mini_hurdle_measurement_cue_vertical_body".localized)
                            MiniGuideStepRow(index: 4, text: "mini_hurdle_measurement_cue_repeat_body".localized)
                        }

                        MiniCalloutCard(
                            title: "mini_hurdle_measurement_note_title".localized,
                            detail: "mini_hurdle_measurement_note_body".localized,
                            accent: DS.Colors.warning
                        )

                    }
                } label: {
                    Text("mini_hurdle_measurement_definition_title".localized)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DS.Colors.miniHurdle)
                }
                .tint(DS.Colors.miniHurdle)
                .accessibilityIdentifier("mini_hurdle_measurement_detail_toggle")
            }
        }
    }

    private var researchSection: some View {
        MiniHurdleSectionCard(
            title: "mini_hurdle_research_title".localized,
            subtitle: "mini_hurdle_research_subtitle".localized,
            accent: DS.Colors.miniHurdle
        ) {
            DisclosureGroup(isExpanded: $methodGuideExpanded) {
                VStack(spacing: 10) {
                    MiniExpertCard(
                        title: "mini_hurdle_research_clark_title".localized,
                        detail: profile == .women
                            ? "mini_hurdle_research_clark_body_women".localized
                            : "mini_hurdle_research_clark_body_men".localized,
                        accent: DS.Colors.interval
                    )
                    MiniExpertCard(
                        title: "mini_hurdle_research_mann_title".localized,
                        detail: profile == .women
                            ? "mini_hurdle_research_mann_body_women".localized
                            : "mini_hurdle_research_mann_body_men".localized,
                        accent: DS.Colors.paceRun
                    )
                    MiniExpertCard(
                        title: "mini_hurdle_strategy_current_note_title".localized,
                        detail: activeStrategyDisplayKind.currentNote,
                        accent: DS.Colors.miniHurdle
                    )
                }
                .padding(.top, 8)
            } label: {
                Label("mini_hurdle_method_detail_toggle".localized, systemImage: "book.closed")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.Colors.miniHurdle)
            }
            .tint(DS.Colors.miniHurdle)
        }
    }

    private func resultsSection(_ result: MiniHurdleSpacingResult) -> some View {
        MiniHurdleSectionCard(
            title: "mini_hurdle_overview_title".localized,
            subtitle: "mini_hurdle_overview_subtitle".localized,
            accent: DS.Colors.miniHurdle
        ) {
            VStack(spacing: 14) {
                // Compact result summary strip
                HStack(spacing: 10) {
                    Label(
                        String(format: measurementUnit.metricFormat, enteredLengthValue),
                        systemImage: "figure.stand"
                    )
                    .font(.system(.footnote, design: .monospaced).weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.white)

                    Text("·")
                        .foregroundStyle(.white.opacity(0.7))

                    Text(ratioText(result.selectedRatio))
                        .font(.system(.footnote, design: .monospaced).weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.white)

                    Text("·")
                        .foregroundStyle(.white.opacity(0.7))

                    Text("\(distanceText(result.minimumSpacing)) - \(distanceText(result.maximumSpacing))")
                        .font(.system(.footnote, design: .monospaced).weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(DS.Colors.miniHurdle.opacity(0.85))
                )

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    MiniMetricTile(
                        title: "mini_hurdle_overview_metric_gt".localized,
                        value: String(format: measurementUnit.metricFormat, enteredLengthValue),
                        tint: DS.Colors.miniHurdle
                    )
                    MiniMetricTile(
                        title: "mini_hurdle_overview_metric_ratio".localized,
                        value: ratioText(result.selectedRatio),
                        tint: DS.Colors.miniHurdle
                    )
                    MiniMetricTile(
                        title: "mini_hurdle_overview_metric_min".localized,
                        value: distanceText(result.minimumSpacing),
                        tint: DS.Colors.miniHurdle
                    )
                    MiniMetricTile(
                        title: "mini_hurdle_overview_metric_max".localized,
                        value: distanceText(result.maximumSpacing),
                        tint: DS.Colors.miniHurdle
                    )
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

                VStack(spacing: 10) {
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
            VStack(spacing: 10) {
                MiniExpertCard(
                    title: "mini_hurdle_progression_phase_1_title".localized,
                    detail: String(
                        format: "mini_hurdle_progression_phase_1_body".localized,
                        distanceText(hurdleSpacing(for: 12, in: result)),
                        normalizedSpacingText(for: 12, in: result),
                        distanceText(worksheetDistance(for: 12, in: result)),
                        distanceText(placementDistance(for: 12, in: result))
                    ),
                    accent: DS.Colors.success
                )
                MiniExpertCard(
                    title: "mini_hurdle_progression_phase_2_title".localized,
                    detail: String(
                        format: "mini_hurdle_progression_phase_2_body".localized,
                        distanceText(hurdleSpacing(for: 16, in: result)),
                        normalizedSpacingText(for: 16, in: result),
                        distanceText(worksheetDistance(for: 16, in: result)),
                        distanceText(placementDistance(for: 16, in: result))
                    ),
                    accent: DS.Colors.miniHurdle
                )
                MiniExpertCard(
                    title: "mini_hurdle_progression_phase_3_title".localized,
                    detail: String(
                        format: "mini_hurdle_progression_phase_3_body".localized,
                        distanceText(result.maximumSpacing),
                        distanceText(result.lastHurdleCoordinate),
                        distanceText(result.hurdlePlacementDistance),
                        distanceText(result.recommendedRunOutDistance)
                    ),
                    accent: DS.Colors.interval
                )
            }
        }
    }

    private var qualitySection: some View {
        MiniHurdleSectionCard(
            title: "mini_hurdle_quality_title".localized,
            subtitle: "mini_hurdle_quality_subtitle".localized,
            accent: DS.Colors.warning
        ) {
            DisclosureGroup(isExpanded: $qualityGuideExpanded) {
                VStack(alignment: .leading, spacing: 12) {
                    MiniBulletRow(text: "mini_hurdle_quality_1".localized)
                    MiniBulletRow(text: "mini_hurdle_quality_2".localized)
                    MiniBulletRow(text: "mini_hurdle_quality_3".localized)
                    MiniBulletRow(text: "mini_hurdle_quality_4".localized)
                    MiniBulletRow(text: "mini_hurdle_quality_5".localized)
                    MiniBulletRow(text: "mini_hurdle_quality_6".localized)
                }
                .padding(.top, 8)
            } label: {
                Label("mini_hurdle_quality_detail_toggle".localized, systemImage: "eye")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.Colors.warning)
            }
            .tint(DS.Colors.warning)
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

    private func adjustGreaterTrochanter(byDisplayUnits delta: Double) {
        // 以当前显示单位为步进精度（cm 模式 ±1，m 模式 ±0.01），
        // 直接读写显示值，避免中间换算被显示格式（%.0f / %.2f）吞掉步进。
        let fallback = measurementUnit == .centimeters ? 86.0 : 0.86
        let current = Double(sanitizeDecimalInput(greaterTrochanterText)) ?? fallback
        let minimum = measurementUnit == .centimeters ? 1.0 : 0.01
        let adjusted = max(minimum, current + delta)
        greaterTrochanterText = formattedGreaterTrochanterInput(
            measurementUnit == .centimeters ? adjusted / 100 : adjusted,
            unit: measurementUnit
        )
    }

    private var enteredLengthText: String {
        String(format: measurementUnit.metricFormat, enteredLengthValue)
    }

    private var enteredLengthValue: Double {
        Double(sanitizeDecimalInput(greaterTrochanterText)) ?? 0
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
        let greaterTrochanterText = formattedGreaterTrochanterText(
            athlete.greaterTrochanterLength,
            unit: athlete.measurementUnit
        )
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
        isApplyingSavedAthlete = true
        profile = athlete.profile
        measurementUnit = athlete.measurementUnit
        greaterTrochanterText = formattedGreaterTrochanterInput(
            athlete.greaterTrochanterLength,
            unit: athlete.measurementUnit
        )
        switch athlete.strategyKind {
        case .mannRecommended:
            strategyKind = .mannRecommended
            clarkRangeRatio = athlete.profile.mannRecommendedRatio
        case .clarkRange:
            strategyKind = .clarkRange
            clarkRangeRatio = clampStoredClarkRatio(athlete.customRatio, for: athlete.profile)
        }
        DispatchQueue.main.async {
            isApplyingSavedAthlete = false
        }
    }

    private func restoreTemporaryDefaults() {
        isApplyingSavedAthlete = true
        profile = .women
        measurementUnit = .centimeters
        greaterTrochanterText = "86"
        strategyKind = .mannRecommended
        clarkRangeRatio = MiniHurdleProfile.women.mannRecommendedRatio
        DispatchQueue.main.async {
            isApplyingSavedAthlete = false
        }
    }

    private func clampClarkRatioToCurrentProfile() {
        let clamped = clampStoredClarkRatio(clarkRangeRatio, for: profile)
        if abs(clamped - clarkRangeRatio) > 0.0001 {
            clarkRangeRatio = clamped
        }
    }

    private func handleMeasurementUnitChange(
        from oldValue: MiniHurdleMeasurementUnit,
        to newValue: MiniHurdleMeasurementUnit
    ) {
        guard !isApplyingSavedAthlete else { return }
        let sanitized = sanitizeDecimalInput(greaterTrochanterText)
        guard let value = Double(sanitized), value > 0 else {
            persistSelectedAthleteIfPossible()
            return
        }

        let meters = oldValue == .centimeters ? value / 100 : value
        isApplyingSavedAthlete = true
        greaterTrochanterText = formattedGreaterTrochanterInput(meters, unit: newValue)
        DispatchQueue.main.async {
            isApplyingSavedAthlete = false
            persistSelectedAthleteIfPossible()
        }
    }

    private func formattedGreaterTrochanterInput(
        _ greaterTrochanterLength: Double,
        unit: MiniHurdleMeasurementUnit
    ) -> String {
        switch unit {
        case .centimeters:
            return String(format: "%.0f", greaterTrochanterLength * 100)
        case .meters:
            return String(format: "%.2f", greaterTrochanterLength)
        }
    }

    private func formattedGreaterTrochanterText(
        _ greaterTrochanterLength: Double,
        unit: MiniHurdleMeasurementUnit
    ) -> String {
        switch unit {
        case .centimeters:
            return String(format: unit.metricFormat, greaterTrochanterLength * 100)
        case .meters:
            return String(format: unit.metricFormat, greaterTrochanterLength)
        }
    }

    private func persistSelectedAthleteIfPossible() {
        guard !isApplyingSavedAthlete,
              let selectedAthlete else { return }

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

        if draft.mode == .create && !canSaveCurrentSetupAsAthlete {
            return "mini_hurdle_athlete_editor_invalid_setup".localized
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
        case .create:
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
                applyAthlete(athlete)
            }
            presentToast("mini_hurdle_toast_athlete_updated".localized)
            playSuccessHaptic()
        }
    }

    private func selectAthlete(_ athlete: MiniHurdleAthleteProfile) {
        var updatedAthlete = athlete
        updatedAthlete.lastUsedAt = Date()
        storage.upsertMiniHurdleProfile(updatedAthlete)
        storage.saveSelectedMiniHurdleProfileID(updatedAthlete.id)
        savedAthletes = storage.loadMiniHurdleProfiles()
        selectedAthleteID = updatedAthlete.id
        applyAthlete(updatedAthlete)
        presentToast(String(format: "mini_hurdle_toast_athlete_selected".localized, athlete.name))
        playLightHaptic()
    }

    private func deleteAthlete(_ athlete: MiniHurdleAthleteProfile) {
        let wasSelected = athlete.id == selectedAthleteID
        storage.deleteMiniHurdleProfile(athlete.id)
        savedAthletes = storage.loadMiniHurdleProfiles()
        presentToast("mini_hurdle_toast_athlete_deleted".localized)
        playSuccessHaptic()

        guard wasSelected else { return }

        if let fallbackAthlete = savedAthletes.first {
            storage.saveSelectedMiniHurdleProfileID(fallbackAthlete.id)
            selectedAthleteID = fallbackAthlete.id
            applyAthlete(fallbackAthlete)
        } else {
            storage.saveSelectedMiniHurdleProfileID(nil)
            selectedAthleteID = nil
            restoreTemporaryDefaults()
        }
    }
}

private struct MiniHurdleSectionCard<Content: View>: View {
    let title: String
    var subtitle: String?
    var accent: Color?
    let content: Content

    init(
        title: String,
        subtitle: String? = nil,
        accent: Color? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.accent = accent
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.lg) {
            HStack(spacing: 8) {
                if let accent {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(accent)
                        .frame(width: 3, height: 16)
                }
                VStack(alignment: .leading, spacing: DS.Space.xs) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(accent ?? DS.Colors.textPrimary)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(DS.Colors.textSecondary)
                    }
                }
            }
            content
        }
        .dsCard()
    }
}

private enum MiniHurdleAthleteEditorMode {
    case create
    case edit

    var title: String {
        switch self {
        case .create:
            return "mini_hurdle_athlete_editor_create_title".localized
        case .edit:
            return "mini_hurdle_athlete_editor_edit_title".localized
        }
    }

    var saveButtonTitle: String {
        switch self {
        case .create:
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

private struct MiniHurdleAthleteActionButton: View {
    let icon: String
    let text: String
    let tint: Color
    var isDisabled = false
    let accessibilityIdentifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(text, systemImage: icon)
                .font(.footnote.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(tint.opacity(isDisabled ? 0.06 : 0.14))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(tint.opacity(isDisabled ? 0.15 : 0.36), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .foregroundStyle(isDisabled ? DS.Colors.textTertiary : tint)
        .disabled(isDisabled)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
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

    private var parsedGtLength: Double? {
        let val = editorGtText.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard let value = Double(val), value > 0 else { return nil }
        return editorMeasurementUnit == .centimeters ? value / 100 : value
    }

    private var validationMessage: String? {
        validateName(name)
    }

    private var canSave: Bool {
        validationMessage == nil && parsedGtLength != nil
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

        switch draft.measurementUnit {
        case .centimeters:
            _editorGtText = State(initialValue: String(format: "%.0f", draft.greaterTrochanterLength * 100))
        case .meters:
            _editorGtText = State(initialValue: String(format: "%.2f", draft.greaterTrochanterLength))
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("mini_hurdle_athlete_editor_name_section".localized) {
                    TextField("mini_hurdle_athlete_editor_name_placeholder".localized, text: $name)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .accessibilityIdentifier("mini_hurdle_athlete_name_textfield")

                    if let validationMessage {
                        Text(validationMessage)
                            .font(.caption)
                            .foregroundStyle(DS.Colors.warning)
                    }
                }

                Section("mini_hurdle_profile".localized) {
                    Picker("mini_hurdle_profile".localized, selection: $editorProfile) {
                        ForEach(MiniHurdleProfile.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("mini_hurdle_measurement_gt_title".localized) {
                    Picker("mini_hurdle_measurement_unit".localized, selection: $editorMeasurementUnit) {
                        ForEach(MiniHurdleMeasurementUnit.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)

                    HStack {
                        TextField(
                            editorMeasurementUnit == .centimeters ? "86" : "0.86",
                            text: $editorGtText
                        )
                        .keyboardType(.decimalPad)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .font(.system(.title3, design: .monospaced).weight(.semibold))
                        .monospacedDigit()

                        Text(editorMeasurementUnit.displayName)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(DS.Colors.textSecondary)
                    }
                }

                Section("mini_hurdle_strategy_mode_title".localized) {
                    Picker("mini_hurdle_strategy_mode_title".localized, selection: $editorStrategyKind) {
                        Text("mini_hurdle_strategy_mann".localized).tag(MiniHurdleStrategyKind.mannRecommended)
                        Text("mini_hurdle_strategy_clark_range".localized).tag(MiniHurdleStrategyKind.clarkRange)
                    }
                    .pickerStyle(.segmented)

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
                                    .foregroundStyle(DS.Colors.interval)
                            }

                            Slider(value: $editorCustomRatio, in: clarkRange, step: 0.01)
                                .tint(DS.Colors.interval)

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
                            "--"
                        ))
                        .font(.caption)
                        .foregroundStyle(DS.Colors.textSecondary)
                    }
                }

                Section(summaryTitle) {
                    Text(summaryText)
                        .font(.subheadline)
                        .foregroundStyle(DS.Colors.textPrimary)
                    Text(syncNote)
                        .font(.caption)
                        .foregroundStyle(DS.Colors.textSecondary)
                }

                if onDelete != nil {
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Text("mini_hurdle_athlete_delete_button".localized)
                        }
                        .accessibilityIdentifier("mini_hurdle_athlete_delete_button")
                    }
                }
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel".localized) {
                        dismiss()
                    }
                    .accessibilityIdentifier("mini_hurdle_athlete_editor_cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(mode.saveButtonTitle) {
                        let ratio: Double? = editorStrategyKind == .mannRecommended ? nil : clampedCustomRatio
                        onSave(name, editorProfile, parsedGtLength ?? 0.86, editorMeasurementUnit, editorStrategyKind, ratio)
                        dismiss()
                    }
                    .disabled(!canSave)
                    .accessibilityIdentifier("mini_hurdle_athlete_editor_save")
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
                            Button {
                                onSelect(athlete)
                                dismiss()
                            } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: athlete.id == selectedAthleteID ? "checkmark.circle.fill" : "circle")
                                        .font(.title3)
                                        .foregroundStyle(athlete.id == selectedAthleteID ? DS.Colors.miniHurdle : DS.Colors.textTertiary)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(athlete.name)
                                            .font(.body.weight(.semibold))
                                            .foregroundStyle(DS.Colors.textPrimary)

                                        Text(summaryText(athlete))
                                            .font(.caption)
                                            .foregroundStyle(DS.Colors.textSecondary)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.8)
                                    }

                                    Spacer(minLength: 8)

                                    Button {
                                        onEdit(MiniHurdleAthleteEditorDraft(
                                            mode: .edit,
                                            athleteID: athlete.id,
                                            name: athlete.name,
                                            profile: athlete.profile,
                                            greaterTrochanterLength: athlete.greaterTrochanterLength,
                                            measurementUnit: athlete.measurementUnit,
                                            strategyKind: athlete.strategyKind,
                                            customRatio: athlete.customRatio
                                        ))
                                    } label: {
                                        Image(systemName: "square.and.pencil")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundStyle(DS.Colors.miniHurdle)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("mini_hurdle_athlete_manage_button".localized)
                                }
                                .frame(minHeight: 52, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(athlete.id == selectedAthleteID ? .isSelected : [])
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
                }
            }
            .navigationTitle("mini_hurdle_athlete_list_title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel".localized) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        onCreateNew()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                    }
                    .accessibilityLabel("mini_hurdle_athlete_list_add_button".localized)
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
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            RoundedRectangle(cornerRadius: 2)
                .fill(tint)
                .frame(width: 8, height: 8)

            Text(value)
                .font(.system(.title3, design: .monospaced).weight(.bold))
                .monospacedDigit()
                .foregroundStyle(DS.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(title)
                .font(.caption)
                .foregroundStyle(DS.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
        .padding(DS.Space.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .fill(tint.opacity(0.14))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .stroke(tint.opacity(0.45), lineWidth: 1)
        )
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
                .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(DS.Colors.textPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(DS.Colors.field)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(DS.Colors.fieldBorder, lineWidth: 1)
        )
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
                .font(.system(.caption, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(DS.Colors.textSecondary)

            Text(MiniHurdleFormatting.distance(mark.spacing))
                .font(.system(.caption, design: .monospaced).weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(mark.worksheetStepNumber == 0 ? DS.Colors.textSecondary : DS.Colors.textPrimary)
                .accessibilityIdentifier(
                    hurdleNumber.map { "mini_hurdle_spacing_\($0)" }
                        ?? "mini_hurdle_sequence_spacing_\(mark.worksheetStepNumber)"
                )

            Text(MiniHurdleFormatting.value(mark.cumulativePosition))
                .font(.system(.caption, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(DS.Colors.miniHurdle)
                .accessibilityIdentifier(
                    hurdleNumber.map { "mini_hurdle_point_\($0)" }
                        ?? "mini_hurdle_sequence_point_\(mark.worksheetStepNumber)"
                )
        }
    }
}

private struct MiniCalloutCard: View {
    let title: String
    let detail: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(accent)
            Text(detail)
                .font(.caption)
                .foregroundStyle(DS.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(accent.opacity(0.14))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(accent.opacity(0.45), lineWidth: 1)
        )
    }
}

private struct MiniExpertCard: View {
    let title: String
    let detail: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(DS.Colors.textPrimary)
            Text(detail)
                .font(.caption)
                .foregroundStyle(DS.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(DS.Colors.field)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(accent.opacity(0.45), lineWidth: 1)
        )
    }
}

private struct MiniGuideStepRow: View {
    let index: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(index)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(DS.Colors.miniHurdle))
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
                .fill(DS.Colors.warning)
                .frame(width: 6, height: 6)
                .padding(.top, 6)
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
