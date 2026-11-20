import SwiftUI

struct HomeView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var localization = LocalizationManager.shared
    @ObservedObject private var storage = StorageManager.shared
    @State private var selectedTab: HomeTab = .training
    @State private var weekSessions = 0
    @State private var weekSeconds: TimeInterval = 0
    @State private var lastSessionDate: Date?

    private enum HomeTab { case training, history, settings }

    // Dates follow the interface language, not the device region, so an
    // English session does not show a Chinese date line.
    private var displayLocale: Locale { localization.locale }

    var body: some View {
        NavigationStack {
            ZStack {
                DS.Colors.bg.ignoresSafeArea()

                VStack(spacing: 0) {
                    Group {
                        switch selectedTab {
                        case .training: trainingContent
                        case .history:  HistoryView()
                        case .settings: SettingsView()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .id(selectedTab)
                    .transition(.opacity)
                    .animation(reduceMotion ? nil : DS.Motion.curve, value: selectedTab)

                    bottomNav
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear(perform: refreshDashboard)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshDashboard() }
        }
    }

    // MARK: - Training Tab

    private var trainingContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                DSPageHeader(
                    title: "app_name".localized,
                    subtitle: "training_subtitle".localized,
                    dateLine: Date.now.formatted(
                        Date.FormatStyle(date: .abbreviated, time: .omitted).locale(displayLocale)
                    ),
                    tick: DS.Colors.paceRun
                )

                weekBand
                    .padding(.top, DS.Space.xxl)

                DSSectionLabel(text: "training_items".localized)
                    .padding(.top, DS.Space.xxxl)
                    .padding(.bottom, DS.Space.sm)

                entriesPanel
            }
            .padding(.horizontal, DS.Space.page)
            .padding(.top, DS.Space.sm)
            .padding(.bottom, 112)
            .dsReadableColumn()
        }
    }

    // MARK: - This week (the screen's one moment: real figures)

    private var weekBand: some View {
        VStack(alignment: .leading, spacing: DS.Space.md) {
            Text("this_week".localized)
                .font(DS.Typo.meta)
                .foregroundStyle(DS.Colors.textTertiary)

            HStack(alignment: .top, spacing: 0) {
                figureColumn(
                    value: "\(weekSessions)",
                    label: "sessions".localized
                )
                columnDivider
                figureColumn(
                    value: formatDuration(weekSeconds),
                    label: "total_time".localized
                )
                .padding(.leading, DS.Space.md)
                columnDivider
                figureColumn(
                    value: lastSessionDate.map {
                        $0.formatted(.dateTime.month(.defaultDigits).day().locale(displayLocale))
                    } ?? "—",
                    label: "last_session".localized
                )
                .padding(.leading, DS.Space.md)
            }
        }
        .padding(DS.Space.lg)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(DS.Colors.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .stroke(DS.Colors.borderLight, lineWidth: 1)
        )
        .padding(.top, DS.Space.lg)
    }

    private func figureColumn(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.xxs) {
            Text(value)
                .font(DS.Typo.figure)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(DS.Colors.textPrimary)
            Text(label)
                .font(DS.Typo.meta)
                .foregroundStyle(DS.Colors.textTertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.trailing, DS.Space.md)
    }

    private var columnDivider: some View {
        Rectangle()
            .fill(DS.Colors.divider)
            .frame(width: 1, height: 34)
            .padding(.top, DS.Space.xxs)
    }

    // MARK: - Entries

    private var entriesPanel: some View {
        VStack(spacing: 0) {
            entryRow(
                icon: "figure.run",
                title: "pace_run".localized,
                subtitle: "pace_run_desc".localized,
                accent: DS.Colors.paceRun,
                accessibilityID: "pace_manage_button",
                destination: AnyView(PaceRunSetupView())
            )
            rowDivider
            entryRow(
                icon: "repeat",
                title: "interval_training".localized,
                subtitle: "interval_training_desc".localized,
                accent: DS.Colors.interval,
                accessibilityID: "interval_manage_button",
                destination: AnyView(IntervalTrainingSetupView())
            )
            rowDivider
            entryRow(
                icon: "gauge.with.needle",
                title: "model_400_title".localized,
                subtitle: "model_400_home_desc".localized,
                accent: DS.Colors.model400,
                accessibilityID: "model_400_open_button",
                destination: AnyView(FourHundredModelGeneratorView())
            )
            rowDivider
            entryRow(
                icon: "ruler",
                title: "mini_hurdle_title".localized,
                subtitle: "mini_hurdle_home_desc".localized,
                accent: DS.Colors.miniHurdle,
                accessibilityID: "mini_hurdle_open_button",
                destination: AnyView(MiniHurdleSpacingView())
            )
        }
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(DS.Colors.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .stroke(DS.Colors.borderLight, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(DS.Colors.divider)
            .frame(height: 1)
            .padding(.leading, 48)
    }

    private func entryRow(
        icon: String,
        title: String,
        subtitle: String,
        accent: Color,
        accessibilityID: String,
        destination: AnyView
    ) -> some View {
        NavigationLink(destination: destination) {
            HStack(spacing: DS.Space.md) {
                DSLaneTick(color: accent)

                Image(systemName: icon)
                    .font(.system(size: icon == "ruler" ? 15 : 17, weight: .regular))
                    .foregroundStyle(DS.Colors.textSecondary)
                    .frame(width: 22, alignment: .center)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(DS.Typo.rowTitle)
                        .foregroundStyle(DS.Colors.textPrimary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(DS.Typo.rowDetail)
                        .foregroundStyle(DS.Colors.textTertiary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: DS.Space.sm)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DS.Colors.textHint)
            }
            .padding(.horizontal, DS.Space.lg)
            .padding(.vertical, DS.Space.sm + 2)
            .frame(minHeight: 72)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityID)
    }

    // MARK: - Bottom Nav

    private var bottomNav: some View {
        HStack(spacing: 0) {
            tabButton(icon: "figure.run", label: "training".localized, tab: .training, accessibilityID: "home_tab_training")
            tabButton(icon: "clock.arrow.circlepath", label: "history".localized, tab: .history, accessibilityID: "home_tab_history")
            tabButton(icon: "gearshape", label: "settings".localized, tab: .settings, accessibilityID: "home_tab_settings")
        }
        .padding(.horizontal, DS.Space.sm)
        .padding(.top, DS.Space.sm)
        .padding(.bottom, DS.Space.xxs)
        .background(
            DS.Colors.card
                .overlay(alignment: .top) {
                    Rectangle().fill(DS.Colors.divider).frame(height: 1)
                }
        )
    }

    private func tabButton(icon: String, label: String, tab: HomeTab, accessibilityID: String) -> some View {
        let active = selectedTab == tab
        return Button {
            guard selectedTab != tab else { return }
            selectedTab = tab
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .regular))
                    .foregroundStyle(active ? DS.Colors.textPrimary : DS.Colors.textTertiary)
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(active ? DS.Colors.textPrimary : DS.Colors.textTertiary)
                DSLaneRule(color: active ? DS.Colors.paceRun : Color.clear, width: 14)
                    .padding(.top, 1)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, DS.Space.xxs)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(active ? .isSelected : [])
        .accessibilityIdentifier(accessibilityID)
    }

    // MARK: - Data

    private func refreshDashboard() {
        let records = storage.loadTrainingRecords()
        let calendar = Calendar.current
        let week = calendar.dateInterval(of: .weekOfYear, for: Date())
        let inWeek = records.filter { week?.contains($0.startTime) ?? false }
        weekSessions = inWeek.count
        weekSeconds = inWeek.reduce(0) { $0 + max(0, $1.endTime.timeIntervalSince($1.startTime)) }
        lastSessionDate = records.map(\.startTime).max()
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded()))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }
}
