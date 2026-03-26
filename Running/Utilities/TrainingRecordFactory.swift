import Foundation

enum TrainingRecordFactory {
    static func makeRecord(
        for training: PaceRunTraining,
        userId: String,
        sessionStartedAt: Date?,
        endAt: Date = Date(),
        completed: Bool
    ) throws -> TrainingRecord {
        let snapshot = try JSONEncoder().encode(training)
        return TrainingRecord(
            userId: userId,
            trainingType: .paceRun,
            configId: training.id,
            configSnapshot: String(data: snapshot, encoding: .utf8) ?? "",
            startTime: sessionStartedAt ?? endAt.addingTimeInterval(-training.plannedSessionDuration()),
            endTime: endAt,
            completed: completed
        )
    }

    static func makeRecord(
        for training: IntervalTraining,
        userId: String,
        sessionStartedAt: Date?,
        endAt: Date = Date(),
        completed: Bool
    ) throws -> TrainingRecord {
        let snapshot = try JSONEncoder().encode(training)
        return TrainingRecord(
            userId: userId,
            trainingType: .intervalTraining,
            configId: training.id,
            configSnapshot: String(data: snapshot, encoding: .utf8) ?? "",
            startTime: sessionStartedAt ?? endAt.addingTimeInterval(-training.plannedSessionDuration()),
            endTime: endAt,
            completed: completed
        )
    }
}
