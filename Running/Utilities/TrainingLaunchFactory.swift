import Foundation

struct PaceRunLaunchPlan: Identifiable {
    let id: UUID
    let title: String
    let training: PaceRunTraining
}

struct PaceRunLaunchSession: Identifiable {
    let id = UUID()
    let plans: [PaceRunLaunchPlan]
}

struct IntervalLaunchPlan: Identifiable {
    let id: UUID
    let title: String
    let training: IntervalTraining
}

struct IntervalLaunchSession: Identifiable {
    let id = UUID()
    let plans: [IntervalLaunchPlan]
}

enum TrainingLaunchFactory {
    static func makePaceHistoryLaunchPlans(
        from plans: [SavedPlan],
        runtimeCountdownSeconds: Int,
        decode: (SavedPlan) -> PaceRunTraining?,
        fallbackTitle: (PaceRunTraining, SavedPlan) -> String
    ) -> [PaceRunLaunchPlan] {
        let countdown = max(1, runtimeCountdownSeconds)
        return plans.compactMap { plan in
            guard var training = decode(plan) else { return nil }
            training.countdownSeconds = countdown
            return PaceRunLaunchPlan(
                id: plan.id,
                title: fallbackTitle(training, plan),
                training: training
            )
        }
    }

    static func makeIntervalHistoryLaunchPlans(
        from plans: [SavedPlan],
        runtimeCountdownSeconds: Int,
        decode: (SavedPlan) -> IntervalTraining?,
        fallbackTitle: (IntervalTraining, SavedPlan) -> String
    ) -> [IntervalLaunchPlan] {
        let countdown = max(1, runtimeCountdownSeconds)
        return plans.compactMap { plan in
            guard var training = decode(plan) else { return nil }
            training.countdownSeconds = countdown
            return IntervalLaunchPlan(
                id: plan.id,
                title: fallbackTitle(training, plan),
                training: training
            )
        }
    }
}
