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

    func testFrozenClockKeepsTheSystemCountdownFormatAcrossMinutesAndHours() {
        for (seconds, expected) in [(0, "0:00"), (9, "0:09"), (60, "1:00"),
                                    (599, "9:59"), (600, "10:00"), (3_600, "1:00:00")] {
            let clock = TrainingSessionClock(countdown: seconds, at: start)
            let paused = clock.preparationActivity(kind: "", title: "", accentHex: "", paused: true)
            XCTAssertEqual(paused.remainingText, expected)
        }
    }

    func testTickingSecondsDoNotRepublishAnUnchangedActivity() {
        var clock = TrainingSessionClock(countdown: 62, at: start)
        let first = clock.preparationActivity(kind: "Pace", title: "Track", accentHex: "123456", paused: false)
        for tick in 1...610 {
            _ = clock.advance(to: start.addingTimeInterval(Double(tick) / 10), paused: false)
            let state = clock.preparationActivity(kind: "Pace", title: "Track", accentHex: "123456", paused: false)
            XCTAssertFalse(state.needsUpdate(after: first))
        }
    }

    func testPaceSegmentDistanceMatchesTheTrackWhenTheLastSegmentIsShorter() {
        let group = PaceRunGroup(totalDistance: 450, segmentDistance: 100, setCount: 2)
        let distances = (0..<group.segmentCount).map { Int(group.distanceForSegment($0)) }
        XCTAssertEqual(distances, [100, 100, 100, 100, 50])
        XCTAssertEqual(distances, group.segmentDistanceValues())
        XCTAssertEqual(group.plannedRunningDistance, 900)

        let custom = PaceRunGroup(setCount: 3, customSegments: [CustomSegment(distance: 80), CustomSegment(distance: 50)])
        XCTAssertEqual(custom.plannedRunningDistance, 390)
        XCTAssertEqual(custom.distanceForSegment(1), 50)
    }
}
