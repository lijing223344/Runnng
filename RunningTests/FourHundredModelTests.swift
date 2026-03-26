import XCTest
@testable import Running

final class FourHundredModelTests: XCTestCase {
    private func assertTimesEqual(
        _ actual: [Double],
        _ expected: [Double],
        accuracy: Double = 0.0001,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(actual.count, expected.count, file: file, line: line)
        for (actualValue, expectedValue) in zip(actual, expected) {
            XCTAssertEqual(actualValue, expectedValue, accuracy: accuracy, file: file, line: line)
        }
    }

    func testCalculateWomenModelReturnsExpectedCheckpointsAndMetrics() throws {
        let result = try XCTUnwrap(
            FourHundredModelCalculator.calculate(profile: .women, finalTime: 57.0)
        )

        XCTAssertEqual(result.cumulative.count, 8)
        XCTAssertEqual(result.cumulative[3].distance, 200)
        XCTAssertEqual(result.cumulative[3].time, 27.1605, accuracy: 0.0001)
        XCTAssertEqual(result.split200.count, 2)
        XCTAssertEqual(result.split200[1].time, 29.8395, accuracy: 0.0001)
        XCTAssertEqual(result.metrics.estimated200PB, 25.8671428571, accuracy: 0.0001)
        XCTAssertEqual(result.metrics.last200Delta, 2.6790, accuracy: 0.0001)
    }

    func testCalculateMenModelReturnsExpectedCheckpointsAndSplits() throws {
        let result = try XCTUnwrap(
            FourHundredModelCalculator.calculate(profile: .men, finalTime: 47.75)
        )

        XCTAssertEqual(result.cumulative.count, 8)
        XCTAssertEqual(result.cumulative[1].distance, 100)
        XCTAssertEqual(result.cumulative[1].time, 11.88975, accuracy: 0.0001)
        XCTAssertEqual(result.cumulative[3].time, 22.83405, accuracy: 0.0001)
        XCTAssertEqual(result.split200[0].time, 22.83405, accuracy: 0.0001)
        XCTAssertEqual(result.split200[1].time, 24.91595, accuracy: 0.0001)
    }

    func testCalculateRejectsNonPositiveTargetTime() {
        XCTAssertNil(FourHundredModelCalculator.calculate(profile: .women, finalTime: 0))
        XCTAssertNil(FourHundredModelCalculator.calculate(profile: .men, finalTime: -1))
    }

    func testAdjustedFinalTimeScalesWithIntensityPercent() throws {
        let adjusted = try XCTUnwrap(
            FourHundredModelCalculator.adjustedFinalTime(
                targetTimeAtHundredPercent: 50,
                intensityPercent: 80
            )
        )
        XCTAssertEqual(adjusted, 62.5, accuracy: 0.0001)
    }

    func testAdjustedFinalTimeRejectsInvalidInputs() {
        XCTAssertNil(
            FourHundredModelCalculator.adjustedFinalTime(
                targetTimeAtHundredPercent: 50,
                intensityPercent: 0
            )
        )
        XCTAssertNil(
            FourHundredModelCalculator.adjustedFinalTime(
                targetTimeAtHundredPercent: 0,
                intensityPercent: 90
            )
        )
    }

    func testDraftTrainingFor50MetersCreatesEightCustomSegmentsWithoutRest() throws {
        let training = try XCTUnwrap(
            FourHundredModelCalculator.makeDraftTraining(
                profile: .women,
                finalTime: 57.0,
                granularity: ._50
            )
        )

        XCTAssertEqual(training.groups.count, 1)
        XCTAssertEqual(training.countdownSeconds, 3)

        let group = try XCTUnwrap(training.groups.first)
        let segments = try XCTUnwrap(group.customSegments)

        XCTAssertEqual(group.totalDistance, 400)
        XCTAssertEqual(group.segmentDistance, 50)
        XCTAssertEqual(group.totalTime, 57.0, accuracy: 0.0001)
        XCTAssertEqual(segments.count, 8)
        XCTAssertEqual(segments.reduce(0) { $0 + $1.distance }, 400)
        XCTAssertEqual(segments.map(\.distance), Array(repeating: 50, count: 8))
        XCTAssertTrue(segments.allSatisfy { $0.restAfter == 0 })
    }

    func testDraftTrainingFor100MetersCreatesFourCustomSegments() throws {
        let training = try XCTUnwrap(
            FourHundredModelCalculator.makeDraftTraining(
                profile: .women,
                finalTime: 57.0,
                granularity: ._100
            )
        )

        let group = try XCTUnwrap(training.groups.first)
        let segments = try XCTUnwrap(group.customSegments)

        XCTAssertEqual(group.segmentDistance, 100)
        XCTAssertEqual(segments.count, 4)
        XCTAssertEqual(segments.map(\.distance), [100, 100, 100, 100])
        XCTAssertTrue(segments.allSatisfy { $0.restAfter == 0 })
    }

    func testDraftTrainingFor200MetersCreatesTwoCustomSegments() throws {
        let training = try XCTUnwrap(
            FourHundredModelCalculator.makeDraftTraining(
                profile: .men,
                finalTime: 47.75,
                granularity: ._200
            )
        )

        let group = try XCTUnwrap(training.groups.first)
        let segments = try XCTUnwrap(group.customSegments)

        XCTAssertEqual(group.segmentDistance, 200)
        XCTAssertEqual(segments.count, 2)
        XCTAssertEqual(segments.map(\.distance), [200, 200])
        XCTAssertTrue(segments.allSatisfy { $0.restAfter == 0 })
        assertTimesEqual(segments.map(\.time), [22.83405, 24.91595])
    }

    func testDraftTrainingUsesIntensityToStretchSplitTimes() throws {
        let training = try XCTUnwrap(
            FourHundredModelCalculator.makeDraftTraining(
                profile: .women,
                finalTime: 57.0,
                granularity: ._200,
                intensityPercent: 80
            )
        )

        let group = try XCTUnwrap(training.groups.first)
        let segments = try XCTUnwrap(group.customSegments)

        XCTAssertEqual(group.totalTime, 71.25, accuracy: 0.0001)
        assertTimesEqual(segments.map(\.time), [33.950625, 37.299375])
    }
}
