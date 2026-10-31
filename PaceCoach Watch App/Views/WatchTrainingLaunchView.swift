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
                    // Notify iPhone that this plan was used
                    WatchConnectivityManager.shared.notifyPlanUsed(planId: plan.id)
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
            // Audit W4: runners care most about total duration before starting.
            // Review pass: include inter-set rest so multi-set estimates match
            // what the timer will actually run.
            let totalTime = training.groups.reduce(0.0) { acc, group in
                let sets = max(1, group.effectiveSetCount)
                let setRest = max(0, group.setRestTime ?? 0)
                return acc + group.totalTime * Double(sets) + Double(sets - 1) * setRest
            }
            return "\(groups) \("groups_count".localized) | \(totalDist)m | \(totalTimeText(totalTime))"
        } else {
            guard let training = try? JSONDecoder().decode(IntervalTraining.self, from: plan.configData) else { return nil }
            let groups = training.groups.count
            let totalReps = training.groups.map(\.effectiveRepetitions).reduce(0, +)
            let totalTime = training.groups.reduce(0.0) { acc, group in
                let reps = group.effectiveRepetitions
                let runSum = (0..<reps).map { group.runTimeForRep($0) }.reduce(0.0, +)
                let restSum = reps > 1 ? (0..<(reps - 1)).map { group.restTimeForRep($0) }.reduce(0.0, +) : 0
                let sets = max(1, group.effectiveSetCount)
                let perSet = runSum + restSum
                return acc + Double(sets) * perSet + Double(sets - 1) * group.effectiveSetRest
            }
            return "\(groups) \("groups_count".localized) | \(totalReps) \("reps_short".localized) | \(totalTimeText(totalTime))"
        }
    }

    private func totalTimeText(_ seconds: Double) -> String {
        let t = Int(seconds.rounded())
        if t >= 3600 {
            return String(format: "%d:%02d:%02d", t / 3600, (t % 3600) / 60, t % 60)
        }
        return String(format: "%d:%02d", t / 60, t % 60)
    }
}
