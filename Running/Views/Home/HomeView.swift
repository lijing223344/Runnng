import SwiftUI

struct HomeView: View {
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var localization = LocalizationManager.shared
    @State private var selectedTab: HomeTab = .training

    private enum HomeTab { case training, history, settings }

    var body: some View {
        NavigationStack {
            ZStack {
                DS.Colors.bg.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Content
                    Group {
                        switch selectedTab {
                        case .training: trainingContent
                        case .history:  HistoryView()
                        case .settings: SettingsView()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

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
            VStack(alignment: .leading, spacing: 28) {
                header
                cardsSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 100)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(Date.now.formatted(date: .abbreviated, time: .omitted))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DS.Colors.textTertiary)
                .padding(.bottom, 2)

            Text("app_name".localized)
                .font(.system(size: 32, weight: .bold))
                .tracking(-1)
                .foregroundStyle(.white)

            Text("training_subtitle".localized)
                .font(.system(size: 15))
                .foregroundStyle(DS.Colors.textSecondary)
        }
    }

    private var cardsSection: some View {
        VStack(spacing: 14) {
            HomeEntryCard(
                icon: "figure.run",
                title: "pace_run".localized,
                subtitle: "pace_run_desc".localized,
                accent: DS.Colors.paceRun,
                accessibilityID: "pace_manage_button",
                destination: AnyView(PaceRunSetupView())
            )
            HomeEntryCard(
                icon: "repeat",
                title: "interval_training".localized,
                subtitle: "interval_training_desc".localized,
                accent: DS.Colors.interval,
                accessibilityID: "interval_manage_button",
                destination: AnyView(IntervalTrainingSetupView())
            )
            HomeEntryCard(
                icon: "gauge.with.needle",
                title: "model_400_title".localized,
                subtitle: "model_400_home_desc".localized,
                accent: DS.Colors.model400,
                accessibilityID: "model_400_open_button",
                destination: AnyView(FourHundredModelGeneratorView())
            )
            HomeEntryCard(
                icon: "ruler",
                title: "mini_hurdle_title".localized,
                subtitle: "mini_hurdle_home_desc".localized,
                accent: DS.Colors.miniHurdle,
                accessibilityID: "mini_hurdle_open_button",
                destination: AnyView(MiniHurdleSpacingView())
            )
        }
    }

    // MARK: - Bottom Nav

    private var bottomNav: some View {
        HStack(spacing: 0) {
            tabButton(icon: "figure.run", label: "training".localized, tab: .training, accessibilityID: "home_tab_training")
            tabButton(icon: "clock.arrow.circlepath", label: "history".localized, tab: .history, accessibilityID: "home_tab_history")
            tabButton(icon: "gearshape", label: "settings".localized, tab: .settings, accessibilityID: "home_tab_settings")
        }
        .padding(.horizontal, 8)
        .padding(.top, 10)
        .padding(.bottom, 2)
        .background(
            DS.Colors.card
                .overlay(alignment: .top) {
                    Rectangle().fill(DS.Colors.border).frame(height: 1)
                }
        )
    }

    private func tabButton(icon: String, label: String, tab: HomeTab, accessibilityID: String) -> some View {
        let active = selectedTab == tab
        return Button { selectedTab = tab } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: active ? .semibold : .regular))
                    .foregroundStyle(active ? .white : DS.Colors.textTertiary)
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(active ? .white : DS.Colors.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityID)
    }

    private func refreshDashboard() {}
}

// MARK: - Entry Card

private struct HomeEntryCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let accent: Color
    let accessibilityID: String
    let destination: AnyView

    var body: some View {
        NavigationLink(destination: destination) {
            ZStack {
                // Background — subtle single-tone shading
                LinearGradient(
                    colors: [accent, accent.opacity(0.85)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Decorative dot grid (top-right area)
                Canvas { context, size in
                    let dotSize: CGFloat = 2.0
                    let spacing: CGFloat = 12.0
                    let cols = 5
                    let rows = 4
                    let originX = size.width - CGFloat(cols) * spacing - 16
                    let originY: CGFloat = 14
                    for row in 0..<rows {
                        for col in 0..<cols {
                            let x = originX + CGFloat(col) * spacing
                            let y = originY + CGFloat(row) * spacing
                            let rect = CGRect(x: x, y: y, width: dotSize, height: dotSize)
                            context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.18)))
                        }
                    }
                }
                .allowsHitTesting(false)

                // Watermark Icon — large, offset bottom-right
                Image(systemName: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 90, height: 90)
                    .foregroundStyle(Color.white.opacity(0.08))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .offset(x: 10, y: 10)

                // Content
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        // Icon + Title row
                        HStack(spacing: 10) {
                            Image(systemName: icon)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 34, height: 34)
                                .background(Circle().fill(Color.white.opacity(0.18)))

                            Text(title)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(.white)
                        }

                        // Subtitle
                        Text(subtitle)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.white.opacity(0.7))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)

                    // Arrow
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.white.opacity(0.18)))
                }
                .padding(20)
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityIdentifier(accessibilityID)
        .frame(height: 140)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: accent.opacity(0.20), radius: 12, x: 0, y: 6)
    }
}
