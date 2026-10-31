import SwiftUI

/// Watch home screen — shows synced training plans.
struct WatchHomeView: View {
    @EnvironmentObject var connectivity: WatchConnectivityManager
    @EnvironmentObject var storage: WatchStorageManager

    var body: some View {
        NavigationStack {
            Group {
                if connectivity.receivedPlans.isEmpty {
                    emptyState
                } else {
                    planList
                }
            }
            .navigationTitle("PaceCoach")
            // Audit W7: tinted large titles follow the target AccentColor on
            // watchOS — kept as the platform-idiomatic brand treatment after
            // evaluating a white-title override (cost: global tint side effects).
        }
        .onAppear {
            connectivity.requestPlansSync()
        }
    }

    // MARK: - Plan List

    private var planList: some View {
        List {
            ForEach(sortedPlans) { plan in
                NavigationLink(value: plan.id) {
                    PlanRowView(plan: plan)
                }
            }
        }
        .refreshable {
            connectivity.requestPlansSync()
        }
        .navigationDestination(for: UUID.self) { planId in
            if let plan = connectivity.receivedPlans.first(where: { $0.id == planId }) {
                WatchTrainingLaunchView(plan: plan)
            }
        }
    }

    private var sortedPlans: [SavedPlan] {
        connectivity.receivedPlans.sorted { $0.lastUsedAt > $1.lastUsedAt }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: WDS.Space.lg) {
            Image(systemName: "iphone.and.arrow.forward")
                .font(.system(size: 28))
                .foregroundColor(WDS.Colors.textTertiary)

            Text("watch_no_plans".localized)
                .font(WDS.Typo.cardTitle)
                .foregroundColor(WDS.Colors.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                connectivity.requestPlansSync()
            } label: {
                Label("watch_sync".localized, systemImage: "arrow.triangle.2.circlepath")
                    .font(WDS.Typo.caption)
            }
            .tint(WDS.Colors.paceRun)
        }
        .padding()
    }
}

// MARK: - Plan Row

struct PlanRowView: View {
    let plan: SavedPlan

    var body: some View {
        HStack(spacing: WDS.Space.md) {
            Circle()
                .fill(accentColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(plan.name.isEmpty ? defaultName : plan.name)
                    .font(WDS.Typo.cardTitle)
                    .foregroundColor(WDS.Colors.textPrimary)
                    .lineLimit(1)

                Text(typeLabel)
                    .font(WDS.Typo.caption)
                    .foregroundColor(WDS.Colors.textTertiary)
            }
        }
    }

    private var accentColor: Color {
        plan.trainingType == .paceRun ? WDS.Colors.paceRun : WDS.Colors.interval
    }

    private var typeLabel: String {
        plan.trainingType == .paceRun ? "pace_run".localized : "interval_training".localized
    }

    private var defaultName: String {
        plan.trainingType == .paceRun ? "pace_run".localized : "interval_training".localized
    }
}
