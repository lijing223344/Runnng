import XCTest
@testable import Running

final class TrainingSessionClockTests: XCTestCase {
    private let start = Date(timeIntervalSinceReferenceDate: 1_000)

    func testMissedTicksConsumePreparationAndCarryTheWholeGapIntoTraining() {
        var clock = TrainingSessionClock(countdown: 3, at: start)
        XCTAssertEqual(clock.advance(to: start.addingTimeInterval(22), paused: false), .start(19))
        XCTAssertEqual(clock.advance(to: start.addingTimeInterval(22), paused: false), .idle)
        XCTAssertEqual(clock.advance(to: start.addingTimeInterval(40), paused: false), .training(18))
    }

    func testPausedPreparationPreservesFractionalTimeAcrossSuspension() {
        var clock = TrainingSessionClock(countdown: 3, at: start)
        XCTAssertEqual(clock.advance(to: start.addingTimeInterval(1.25), paused: false), .countdown(2))
        XCTAssertEqual(clock.advance(to: start.addingTimeInterval(80), paused: true), .idle)
        XCTAssertEqual(clock.countdownRemaining, 1.75)
        XCTAssertEqual(clock.advance(to: start.addingTimeInterval(81.75), paused: false), .start(0))
        XCTAssertEqual(clock.advance(to: start.addingTimeInterval(90), paused: true), .idle)
        XCTAssertEqual(clock.advance(to: start.addingTimeInterval(90.5), paused: false), .training(0.5))
    }

    func testIslandUpdatesForPauseResumeAndNewDeadlineBetweenProgressSteps() {
        var clock = TrainingSessionClock(countdown: 10, at: start)
        let first = clock.preparationActivity(kind: "Pace", title: "Track", accentHex: "123456", paused: false)
        _ = clock.advance(to: start.addingTimeInterval(0.125), paused: false)
        let running = clock.preparationActivity(kind: "Pace", title: "Track", accentHex: "123456", paused: false)
        XCTAssertFalse(running.needsUpdate(after: first))
        let paused = clock.preparationActivity(kind: "Pace", title: "Track", accentHex: "123456", paused: true)
        XCTAssertTrue(paused.needsUpdate(after: running))
        XCTAssertNil(paused.endDate)
        _ = clock.advance(to: start.addingTimeInterval(4.125), paused: true)
        let resumed = clock.preparationActivity(kind: "Pace", title: "Track", accentHex: "123456", paused: false)
        XCTAssertTrue(resumed.needsUpdate(after: paused))
        XCTAssertTrue(resumed.needsUpdate(after: running))
        XCTAssertEqual(resumed.endDate, start.addingTimeInterval(14))
    }

    func testRestStillCountsTheFinishedStepInBothDisciplines() {
        let pace = PaceRunGroup(totalTime: 240)
        var paceState = PaceRunGroupState(phase: .resting)
        XCTAssertEqual(paceState.completedSteps(in: pace), 1)
        paceState.currentSegment = 2
        paceState.phase = .running
        paceState.remainingTime = pace.timeForSegment(1)
        XCTAssertEqual(paceState.completedSteps(in: pace), 1)

        let interval = IntervalGroup(repetitions: 4, setCount: 2)
        var intervalState = GroupTrainingState(phase: .resting)
        intervalState.currentRepetition = 4
        intervalState.isSetRest = true
        XCTAssertEqual(intervalState.completedSteps(in: interval), 4)
    }
}
