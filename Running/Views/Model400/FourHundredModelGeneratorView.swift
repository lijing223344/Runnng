import SwiftUI

struct FourHundredModelGeneratorView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var localization = LocalizationManager.shared

    @State private var profile: FourHundredModelProfile = .women
    @State private var granularity: FourHundredSplitGranularity = ._50
    @State private var targetTimeText = "57.00"
    @State private var intensityText = "100"
    @State private var draftTraining: PaceRunTraining?
    @State private var navigateToDraftEditor = false
    @State private var showGeneratedBanner = false
    private let quickIntensityOptions: [Double] = [80, 85, 90, 95, 100]

    private var parsedTargetTime: Double? {
        let sanitized = sanitizeDecimalInput(targetTimeText)
        guard let value = Double(sanitized), value > 0 else { return nil }
        return value
    }

    private var parsedIntensityPercent: Double? {
        let sanitized = sanitizeDecimalInput(intensityText)
        guard let value = Double(sanitized), value > 0 else { return nil }
        return value
    }

    private var trainingTimeForSelectedIntensity: Double? {
        guard let parsedTargetTime, let parsedIntensityPercent else { return nil }
        return FourHundredModelCalculator.adjustedFinalTime(
            targetTimeAtHundredPercent: parsedTargetTime,
            intensityPercent: parsedIntensityPercent
        )
    }

    private var result: FourHundredModelResult? {
        guard let trainingTimeForSelectedIntensity else { return nil }
        return FourHundredModelCalculator.calculate(profile: profile, finalTime: trainingTimeForSelectedIntensity)
    }

    private var invalidStateMessageKey: String {
        parsedTargetTime == nil ? "model_400_invalid_time" : "model_400_invalid_intensity"
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                heroSection
                controlsSection

                if let result {
                    summarySection(result)
                    splitsSection(result)
                    cumulativeSection(result)
                    metricsSection(result)
                } else {
                    invalidStateSection
                }
            }
            .padding(.horizontal, DS.Space.page)
            .padding(.vertical, DS.Space.lg)
        }
        .background(TrainingPageBackground())
        .overlay(alignment: .bottom) { generatedBanner }
        // Review pass: reserve room for the banner so the "生成计划" CTA stays
        // reachable while the confirmation is on screen.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: showGeneratedBanner ? 84 : 0)
                .animation(.easeInOut(duration: 0.18), value: showGeneratedBanner)
        }
        .navigationTitle("model_400_title".localized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(DS.Colors.bg, for: .navigationBar)
        .navigationDestination(isPresented: $navigateToDraftEditor) {
            if let draftTraining {
                PaceRunSetupView(seedTraining: draftTraining)
            }
        }
        .onChange(of: profile) { oldValue, newValue in
            let oldDefault = String(format: "%.2f", oldValue.suggestedTargetTime)
            if targetTimeText.isEmpty || targetTimeText == oldDefault {
                targetTimeText = String(format: "%.2f", newValue.suggestedTargetTime)
            }
        }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            DSLaneRule(color: DS.Colors.model400, width: 26)

            Text("model_400_desc".localized)
                .font(.system(size: 14))
                .foregroundStyle(DS.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, DS.Space.xxs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var controlsSection: some View {
        ModelSectionCard(title: "model_400_controls".localized, subtitle: "model_400_controls_hint".localized, accent: DS.Colors.model400) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("model_400_profile".localized)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(DS.Colors.textTertiary)
                    DSSegmentedPicker(
                        selection: $profile,
                        options: FourHundredModelProfile.allCases,
                        accent: DS.Colors.model400
                    ) { $0.displayName }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("model_400_granularity".localized)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(DS.Colors.textTertiary)
                    DSSegmentedPicker(
                        selection: $granularity,
                        options: FourHundredSplitGranularity.allCases,
                        accent: DS.Colors.model400
                    ) { $0.displayName }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("model_400_target_time".localized)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(DS.Colors.textTertiary)

                    FloatingTextInputField(
                        placeholder: "57.00",
                        title: "model_400_target_time".localized,
                        value: $targetTimeText,
                        keyboardType: .decimalPad,
                        allowEmpty: false,
                        normalize: normalizeTargetTimeInput,
                        accessibilityIdentifier: "model_400_target_time_field"
                    )
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(DS.Colors.field)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(DS.Colors.fieldBorder, lineWidth: 1)
                    )

                    Text("model_400_target_time_hint".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("model_400_intensity".localized)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(DS.Colors.textTertiary)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                        ForEach(quickIntensityOptions, id: \.self) { option in
                            Button {
                                intensityText = intensityDisplayText(option)
                            } label: {
                                Text("\(intensityDisplayText(option))%")
                                    .font(.system(size: 13, weight: isQuickIntensitySelected(option) ? .medium : .regular))
                                    .monospacedDigit()
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 38)
                                    .background(
                                        RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                                            .fill(isQuickIntensitySelected(option) ? DS.Colors.field : DS.Colors.card)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                                            .stroke(
                                                isQuickIntensitySelected(option) ? DS.Colors.border : DS.Colors.borderLight,
                                                lineWidth: 1
                                            )
                                    )
                                    .foregroundStyle(isQuickIntensitySelected(option) ? DS.Colors.textPrimary : DS.Colors.textSecondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("model_400_intensity_preset_\(Int(option))")
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
                                normalize: normalizeIntensityInput,
                                accessibilityIdentifier: "model_400_intensity_field"
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

                    if let parsedIntensityPercent, let trainingTimeForSelectedIntensity {
                        Text(
                            String(
                                format: "model_400_intensity_effective_time".localized,
                                parsedIntensityPercent,
                                timeText(trainingTimeForSelectedIntensity)
                            )
                        )
                        .font(.system(size: 12, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(DS.Colors.textSecondary)
                    }
                }

                Button(action: generateDraftPlan) {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                        Text("model_400_generate".localized)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(result != nil ? DS.Colors.bg : DS.Colors.textTertiary)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .trainingPrimaryActionSurface(isEnabled: result != nil, colors: [DS.Colors.model400])
                }
                .disabled(result == nil)
                .accessibilityIdentifier("model_400_generate_button")

                Text("model_400_generation_note".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func summarySection(_ result: FourHundredModelResult) -> some View {
        ModelSectionCard(title: "model_400_summary".localized, accent: DS.Colors.model400) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MetricTile(title: "model_400_metric_target".localized, value: timeText(result.finalTime), tint: DS.Colors.model400, isPrimary: true)
                MetricTile(title: "model_400_metric_estimated_200".localized, value: timeText(result.metrics.estimated200PB), tint: DS.Colors.model400)
                MetricTile(title: "model_400_metric_first_200".localized, value: timeText(result.metrics.first200), tint: DS.Colors.model400)
                MetricTile(title: "model_400_metric_last_200".localized, value: timeText(result.metrics.last200), tint: DS.Colors.model400)
            }
        }
    }

    private func splitsSection(_ result: FourHundredModelResult) -> some View {
        ModelSectionCard(
            title: String(format: "model_400_splits_title".localized, granularity.rawValue),
            subtitle: "model_400_splits_subtitle".localized,
            accent: DS.Colors.model400
        ) {
            VStack(spacing: 10) {
                ForEach(result.splits(for: granularity)) { split in
                    rowCard(
                        title: String(format: "model_400_split_range_format".localized, split.startDistance, split.endDistance),
                        value: timeText(split.time)
                    )
                }
            }
        }
    }

    private func cumulativeSection(_ result: FourHundredModelResult) -> some View {
        ModelSectionCard(title: "model_400_cumulative_title".localized, accent: DS.Colors.model400) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(result.cumulative) { checkpoint in
                    checkpointTile(
                        title: String(format: "model_400_checkpoint_format".localized, checkpoint.distance),
                        value: timeText(checkpoint.time)
                    )
                }
            }
        }
    }

    private func metricsSection(_ result: FourHundredModelResult) -> some View {
        ModelSectionCard(title: "model_400_metrics_title".localized, accent: DS.Colors.model400) {
            VStack(spacing: 10) {
                rowCard(
                    title: "model_400_metric_delta".localized,
                    value: signedTimeText(result.metrics.last200Delta)
                )
                rowCard(
                    title: "model_400_metric_last200_ratio".localized,
                    value: ratioText(result.metrics.last200OverFirst200)
                )
                rowCard(
                    title: "model_400_metric_300_200_ratio".localized,
                    value: ratioText(result.metrics.threeHundredOverTwoHundred)
                )
                rowCard(
                    title: "model_400_metric_400_300_ratio".localized,
                    value: ratioText(result.metrics.fourHundredOverThreeHundred)
                )
                rowCard(
                    title: "model_400_metric_200_share".localized,
                    value: percentText(result.metrics.estimated200PBShareOf400)
                )
            }
        }
    }

    private var invalidStateSection: some View {
        ModelSectionCard(title: "model_400_summary".localized) {
            Text(invalidStateMessageKey.localized)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func rowCard(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Space.md) {
            Text(title)
                .font(.system(size: 14))
                .foregroundStyle(DS.Colors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.9)
            Spacer(minLength: DS.Space.md)
            timeBadge(text: value, tint: DS.Colors.textPrimary)
        }
        .padding(.vertical, DS.Space.sm + 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            Rectangle().fill(DS.Colors.divider).frame(height: 1)
        }
    }

    private func checkpointTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.xxs) {
            Text(title)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(DS.Colors.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.9)

            timeBadge(text: value, tint: DS.Colors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, DS.Space.xs)
    }

    @ViewBuilder
    private func timeBadge(text: String, tint: Color = DS.Colors.textPrimary) -> some View {
        Text(text)
            .font(.system(size: 15, weight: .medium, design: .monospaced))
            .monospacedDigit()
            .foregroundStyle(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .fixedSize(horizontal: true, vertical: false)
            .layoutPriority(1)
    }

    private func generateDraftPlan() {
        guard let parsedTargetTime,
              let parsedIntensityPercent,
              let training = FourHundredModelCalculator.makeDraftTraining(
                profile: profile,
                finalTime: parsedTargetTime,
                granularity: granularity,
                intensityPercent: parsedIntensityPercent
              ) else {
            return
        }

        // Audit A3: stay on page, confirm with a banner; navigation only on
        // user tap. Review pass: the banner stays until dismissed (×) or a
        // new generation replaces it — a 5s auto-hide raced with busy-device
        // event delivery, hiding the "View" action before it could be used.
        draftTraining = training
        if reduceMotion {
            showGeneratedBanner = true
        } else {
            withAnimation(.easeInOut(duration: 0.18)) {
                showGeneratedBanner = true
            }
        }
    }

    @ViewBuilder
    private var generatedBanner: some View {
        if showGeneratedBanner, let draftTraining {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(DS.Colors.model400)
                Text(String(
                    format: "model_400_generated_banner".localized,
                    draftTraining.name
                ))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DS.Colors.textPrimary)
                .lineLimit(2)
                Spacer(minLength: 8)
                Button {
                    if reduceMotion {
                        showGeneratedBanner = false
                    } else {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showGeneratedBanner = false
                        }
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(DS.Colors.textTertiary)
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel("cancel".localized)
                .accessibilityIdentifier("model_400_banner_dismiss_button")
                Button {
                    if reduceMotion {
                        navigateToDraftEditor = true
                    } else {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            navigateToDraftEditor = true
                        }
                    }
                    showGeneratedBanner = false
                } label: {
                    Text("model_400_view_plan".localized)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DS.Colors.model400)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            Capsule().fill(DS.Colors.model400.opacity(DS.Opacity.subtle))
                        )
                        .overlay(
                            Capsule().stroke(DS.Colors.model400.opacity(DS.Opacity.regular), lineWidth: 1)
                        )
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityIdentifier("model_400_view_plan_button")
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .fill(DS.Colors.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .stroke(DS.Colors.border, lineWidth: 1)
            )
            .padding(.horizontal, DS.Space.page)
            .padding(.bottom, DS.Space.md)
        }
    }

    private func normalizeTargetTimeInput(_ input: String) -> String {
        sanitizeDecimalInput(input)
    }

    private func normalizeIntensityInput(_ input: String) -> String {
        sanitizeDecimalInput(input)
    }

    private func sanitizeDecimalInput(_ input: String) -> String {
        input.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
    }

    private func intensityDisplayText(_ value: Double) -> String {
        let rounded = value.rounded()
        if abs(value - rounded) < 0.0001 {
            return String(format: "%.0f", rounded)
        }
        return String(format: "%.1f", value)
    }

    private func isQuickIntensitySelected(_ option: Double) -> Bool {
        guard let parsedIntensityPercent else { return false }
        return abs(parsedIntensityPercent - option) < 0.0001
    }

    private func timeText(_ value: Double) -> String {
        String(format: "%.2f%@", value, "sec_label".localized)
    }

    private func signedTimeText(_ value: Double) -> String {
        String(format: "%@%.2f%@", value >= 0 ? "+" : "", value, "sec_label".localized)
    }

    private func ratioText(_ value: Double) -> String {
        String(format: "%.3f", value)
    }

    private func percentText(_ value: Double) -> String {
        String(format: "%.1f%%", value * 100)
    }
}

private struct ModelSectionCard<Content: View>: View {
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
        VStack(alignment: .leading, spacing: DS.Space.md) {
            VStack(alignment: .leading, spacing: DS.Space.xxs) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DS.Colors.textPrimary)
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

private struct MetricTile: View {
    let title: String
    let value: String
    let tint: Color
    var isPrimary: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.xxs) {
            Text(title)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(DS.Colors.textTertiary)
                .fixedSize(horizontal: false, vertical: true)

            Text(value)
                .font(.system(size: isPrimary ? 26 : 22, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(isPrimary ? tint : DS.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
    }
}

#Preview {
    NavigationStack {
        FourHundredModelGeneratorView()
    }
}
