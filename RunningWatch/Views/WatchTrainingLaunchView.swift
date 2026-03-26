import SwiftUI

/// Pre-training launch screen — shows plan summary and start button.
struct WatchTrainingLaunchView: View {
    let plan: SavedPlan
    @State private var isTraining = false

    var body: some View {
        ScrollView {
            VStack(spacing: WDS.Space.lg) {
                // Plan info
                planSummary

                // Start button
                Button {
                    isTraining = true
                } label: {
                    Label("watch_start".localized, systemImage: "play.fill")
                        .font(WDS.Typo.cardTitle)
                        .frame(maxWidth: .infinity)
                }
                .tint(accentColor)
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, WDS.Space.md)
        }
        .navigationTitle(plan.name.isEmpty ? typeLabel : plan.name)
        .fullScreenCover(isPresented: $isTraining) {
            if plan.trainingType == .paceRun {
                WatchPaceRunView(plan: plan, isPresented: $isTraining)
            } else {
                WatchIntervalView(plan: plan, isPresented: $isTraining)
            }
        }
    }

    // MARK: - Plan Summary

    private var planSummary: some View {
        VStack(alignment: .leading, spacing: WDS.Space.sm) {
            Label(typeLabel, systemImage: plan.trainingType == .paceRun ? "metronome" : "repeat")
                .font(WDS.Typo.cardTitle)
                .foregroundColor(accentColor)

            if let info = decodedInfo {
                Text(info)
                    .font(WDS.Typo.caption)
                    .foregroundColor(WDS.Colors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(WDS.Space.lg)
        .background(WDS.Colors.card)
        .cornerRadius(WDS.Radius.md)
    }

    private var accentColor: Color {
        plan.trainingType == .paceRun ? WDS.Colors.paceRun : WDS.Colors.interval
    }

    private var typeLabel: String {
        plan.trainingType == .paceRun ? "pace_run".localized : "interval_training".localized
    }

    private var decodedInfo: String? {
        if plan.trainingType == .paceRun {
            guard let training = try? JSONDecoder().decode(PaceRunTraining.self, from: plan.configData) else { return nil }
            let groups = training.groups.count
            let totalDist = training.groups.map(\.totalDistance).reduce(0, +)
            return "\(groups) \("groups_count".localized) | \(totalDist)m"
        } else {
            guard let training = try? JSONDecoder().decode(IntervalTraining.self, from: plan.configData) else { return nil }
            let groups = training.groups.count
            let totalReps = training.groups.map(\.effectiveRepetitions).reduce(0, +)
            return "\(groups) \("groups_count".localized) | \(totalReps) \("reps_short".localized)"
        }
    }
}
