import XCTest
@testable import Running

final class MiniHurdleSpacingTests: XCTestCase {
    func testGTUnitSwitchPreservesFractionalMeasurements() throws {
        let cm = MiniHurdleMeasurementUnit.centimeters
        let m = MiniHurdleMeasurementUnit.meters
        let measured = try XCTUnwrap(cm.meters(from: "86,75"))
        XCTAssertEqual(m.inputText(meters: measured), "0.8675")
        XCTAssertEqual(cm.inputText(meters: try XCTUnwrap(m.meters(from: "0.8675"))), "86.75")
        XCTAssertNil(m.meters(from: "inf"))
        XCTAssertNil(cm.meters(from: ""))
    }
    func testRecommendedFemaleConfigurationMatchesWorkbookFormulaChain() throws {
        let result = try XCTUnwrap(
            MiniHurdleSpacingCalculator.calculate(
                greaterTrochanterLength: 0.86,
                profile: .women,
                strategy: .mannRecommended
            )
        )

        XCTAssertEqual(result.maximumSpacing, 2.02, accuracy: 0.0001)
        XCTAssertEqual(result.accelerationMarks.count, 7)
        XCTAssertEqual(result.hurdles.count, 21)
        XCTAssertEqual(result.hurdles.first?.stepNumber, 1)
        XCTAssertEqual(result.hurdles.last?.stepNumber, 21)
        XCTAssertEqual(try XCTUnwrap(result.hurdles.first).spacing, 1.61, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(result.hurdles.first).cumulativePosition, 10.155, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(result.hurdles.first).pureCumulativePosition, 1.61, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(result.hurdles.last).spacing, 2.02, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(result.hurdles.last).cumulativePosition, 47.905, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(result.hurdles.last).pureCumulativePosition, 39.36, accuracy: 0.0001)
        XCTAssertEqual(result.totalLayoutDistance, 47.905, accuracy: 0.0001)
        XCTAssertEqual(result.pureLayoutDistance, 39.36, accuracy: 0.0001)
    }

    func testRecommendedRunOutDistanceRemainsSeparateFromWorkbookLayoutDistance() throws {
        let result = try XCTUnwrap(
            MiniHurdleSpacingCalculator.calculate(
                greaterTrochanterLength: 0.86,
                profile: .women,
                strategy: .mannRecommended
            )
        )

        XCTAssertEqual(result.totalLayoutDistance, 47.905, accuracy: 0.0001)
        XCTAssertEqual(result.pureLayoutDistance, 39.36, accuracy: 0.0001)
        XCTAssertEqual(result.recommendedRunOutDistance, 20, accuracy: 0.0001)
    }

    func testRecommendedFemaleConfigurationMatchesCompleteExcelAccelerationAndHurdleSequence() throws {
        let result = try XCTUnwrap(
            MiniHurdleSpacingCalculator.calculate(
                greaterTrochanterLength: 0.86,
                profile: .women,
                strategy: .mannRecommended
            )
        )

        assertAccelerationMarks(
            result.accelerationMarks,
            expectedSteps: Array(1...7),
            expectedSpacings: [0.565, 1.13, 1.21, 1.29, 1.37, 1.45, 1.53],
            expectedCumulativePositions: [0.565, 1.695, 2.905, 4.195, 5.565, 7.015, 8.545],
            maximumSpacing: result.maximumSpacing
        )

        assertMarks(
            result.hurdles,
            expectedSteps: Array(1...21),
            expectedWorksheetSteps: Array(8...28),
            expectedSpacings: [
                1.61, 1.61,
                1.69, 1.69,
                1.77, 1.77,
                1.84, 1.84, 1.84,
                1.92, 1.92, 1.92,
                1.97, 1.97, 1.97,
                1.99, 1.99, 1.99,
                2.02, 2.02, 2.02
            ],
            expectedCumulativePositions: [
                10.155, 11.765,
                13.455, 15.145,
                16.915, 18.685,
                20.525, 22.365, 24.205,
                26.125, 28.045, 29.965,
                31.935, 33.905, 35.875,
                37.865, 39.855, 41.845,
                43.865, 45.885, 47.905
            ],
            expectedPureCumulativePositions: [
                1.61, 3.22,
                4.91, 6.60,
                8.37, 10.14,
                11.98, 13.82, 15.66,
                17.58, 19.50, 21.42,
                23.39, 25.36, 27.33,
                29.32, 31.31, 33.30,
                35.32, 37.34, 39.36
            ],
            maximumSpacing: result.maximumSpacing
        )
    }

    func testRecommendedMaleConfigurationMatchesCompleteWorkbookTemplate() throws {
        let result = try XCTUnwrap(
            MiniHurdleSpacingCalculator.calculate(
                greaterTrochanterLength: 0.86,
                profile: .men,
                strategy: .mannRecommended
            )
        )

        XCTAssertEqual(result.maximumSpacing, 2.09, accuracy: 0.0001)
        XCTAssertEqual(result.firstHurdleCoordinate, 10.680, accuracy: 0.0001)
        XCTAssertEqual(result.lastHurdleCoordinate, 49.830, accuracy: 0.0001)
        XCTAssertEqual(result.hurdlePlacementDistance, 39.15, accuracy: 0.0001)

        assertAccelerationMarks(
            result.accelerationMarks,
            expectedSteps: Array(1...7),
            expectedSpacings: [0.600, 1.20, 1.28, 1.36, 1.44, 1.52, 1.60],
            expectedCumulativePositions: [0.600, 1.800, 3.080, 4.440, 5.880, 7.400, 9.000],
            maximumSpacing: result.maximumSpacing
        )

        assertMarks(
            result.hurdles,
            expectedSteps: Array(1...21),
            expectedWorksheetSteps: Array(8...28),
            expectedSpacings: [
                1.68, 1.68,
                1.76, 1.76,
                1.84, 1.84,
                1.91, 1.91, 1.91,
                1.99, 1.99, 1.99,
                2.04, 2.04, 2.04,
                2.06, 2.06, 2.06,
                2.09, 2.09, 2.09
            ],
            expectedCumulativePositions: [
                10.680, 12.360,
                14.120, 15.880,
                17.720, 19.560,
                21.470, 23.380, 25.290,
                27.280, 29.270, 31.260,
                33.300, 35.340, 37.380,
                39.440, 41.500, 43.560,
                45.650, 47.740, 49.830
            ],
            expectedPureCumulativePositions: [
                1.68, 3.36,
                5.12, 6.88,
                8.72, 10.56,
                12.47, 14.38, 16.29,
                18.28, 20.27, 22.26,
                24.30, 26.34, 28.38,
                30.44, 32.50, 34.56,
                36.65, 38.74, 40.83
            ],
            maximumSpacing: result.maximumSpacing
        )
    }

    func testRecommendedFemaleConfigurationAlsoProducesPracticalHurdlePlacementPointsFromFirstHurdle() throws {
        let result = try XCTUnwrap(
            MiniHurdleSpacingCalculator.calculate(
                greaterTrochanterLength: 0.86,
                profile: .women,
                strategy: .mannRecommended
            )
        )

        XCTAssertEqual(result.leadInDistanceToFirstHurdle, 1.61, accuracy: 0.0001)
        XCTAssertEqual(result.hurdlePlacements.count, 21)
        XCTAssertEqual(result.hurdlePlacementDistance, 37.75, accuracy: 0.0001)
        XCTAssertEqual(result.firstHurdleCoordinate, 10.155, accuracy: 0.0001)
        XCTAssertEqual(result.lastHurdleCoordinate, 47.905, accuracy: 0.0001)

        let first = try XCTUnwrap(result.hurdlePlacements.first)
        XCTAssertEqual(first.hurdleNumber, 1)
        XCTAssertEqual(first.spacing, 1.61, accuracy: 0.0001)
        XCTAssertEqual(first.positionFromStart, 10.155, accuracy: 0.0001)
        XCTAssertEqual(first.positionFromFirstHurdle, 0, accuracy: 0.0001)
        XCTAssertEqual(first.worksheetCoordinate, 10.155, accuracy: 0.0001)

        let second = try XCTUnwrap(result.hurdlePlacements.dropFirst().first)
        XCTAssertEqual(second.hurdleNumber, 2)
        XCTAssertEqual(second.spacing, 1.61, accuracy: 0.0001)
        XCTAssertEqual(second.positionFromStart, 11.765, accuracy: 0.0001)
        XCTAssertEqual(second.positionFromFirstHurdle, 1.61, accuracy: 0.0001)
        XCTAssertEqual(second.worksheetCoordinate, 11.765, accuracy: 0.0001)

        let third = try XCTUnwrap(result.hurdlePlacements.dropFirst(2).first)
        XCTAssertEqual(third.hurdleNumber, 3)
        XCTAssertEqual(third.spacing, 1.69, accuracy: 0.0001)
        XCTAssertEqual(third.positionFromStart, 13.455, accuracy: 0.0001)
        XCTAssertEqual(third.positionFromFirstHurdle, 3.30, accuracy: 0.0001)

        let last = try XCTUnwrap(result.hurdlePlacements.last)
        XCTAssertEqual(last.hurdleNumber, 21)
        XCTAssertEqual(last.spacing, 2.02, accuracy: 0.0001)
        XCTAssertEqual(last.positionFromStart, 47.905, accuracy: 0.0001)
        XCTAssertEqual(last.positionFromFirstHurdle, 37.75, accuracy: 0.0001)
        XCTAssertEqual(last.worksheetCoordinate, 47.905, accuracy: 0.0001)
    }

    func testClarkSliderBoundariesKeepWorkbookOffsetTemplateIntact() throws {
        let conservative = try XCTUnwrap(
            MiniHurdleSpacingCalculator.calculate(
                greaterTrochanterLength: 0.86,
                profile: .women,
                strategy: .custom(ratio: 2.25)
            )
        )
        let advanced = try XCTUnwrap(
            MiniHurdleSpacingCalculator.calculate(
                greaterTrochanterLength: 0.86,
                profile: .women,
                strategy: .custom(ratio: 2.45)
            )
        )

        assertDistanceValues(
            conservative.hurdles.map(\.spacing),
            expected: [
                1.53, 1.53,
                1.61, 1.61,
                1.69, 1.69,
                1.76, 1.76, 1.76,
                1.84, 1.84, 1.84,
                1.89, 1.89, 1.89,
                1.91, 1.91, 1.91,
                1.94, 1.94, 1.94
            ]
        )
        assertDistanceValues(
            advanced.hurdles.map(\.spacing),
            expected: [
                1.70, 1.70,
                1.78, 1.78,
                1.86, 1.86,
                1.93, 1.93, 1.93,
                2.01, 2.01, 2.01,
                2.06, 2.06, 2.06,
                2.08, 2.08, 2.08,
                2.11, 2.11, 2.11
            ]
        )

        XCTAssertEqual(conservative.firstHurdleCoordinate, 9.555, accuracy: 0.0001)
        XCTAssertEqual(conservative.lastHurdleCoordinate, 45.705, accuracy: 0.0001)
        XCTAssertEqual(advanced.firstHurdleCoordinate, 10.830, accuracy: 0.0001)
        XCTAssertEqual(advanced.lastHurdleCoordinate, 50.380, accuracy: 0.0001)
    }

    func testClarkBoundsStillBracketRecommendedMaximumSpacing() throws {
        let conservative = try XCTUnwrap(
            MiniHurdleSpacingCalculator.calculate(
                greaterTrochanterLength: 0.86,
                profile: .women,
                strategy: .clarkLowerBound
            )
        )
        let recommended = try XCTUnwrap(
            MiniHurdleSpacingCalculator.calculate(
                greaterTrochanterLength: 0.86,
                profile: .women,
                strategy: .mannRecommended
            )
        )
        let advanced = try XCTUnwrap(
            MiniHurdleSpacingCalculator.calculate(
                greaterTrochanterLength: 0.86,
                profile: .women,
                strategy: .clarkUpperBound
            )
        )

        XCTAssertEqual(conservative.maximumSpacing, 1.94, accuracy: 0.0001)
        XCTAssertEqual(recommended.maximumSpacing, 2.02, accuracy: 0.0001)
        XCTAssertEqual(advanced.maximumSpacing, 2.11, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(conservative.hurdles.first).spacing, 1.53, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(advanced.hurdles.first).spacing, 1.70, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(conservative.hurdles.first).cumulativePosition, 9.555, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(advanced.hurdles.first).cumulativePosition, 10.83, accuracy: 0.0001)
        XCTAssertLessThan(conservative.maximumSpacing, recommended.maximumSpacing)
        XCTAssertLessThan(recommended.maximumSpacing, advanced.maximumSpacing)
    }

    func testCustomSpacingRatioUsesProvidedMultiplierWithSameWorkbookTemplate() throws {
        let result = try XCTUnwrap(
            MiniHurdleSpacingCalculator.calculate(
                greaterTrochanterLength: 0.9,
                profile: .men,
                strategy: .custom(ratio: 2.4)
            )
        )

        XCTAssertEqual(result.maximumSpacing, 2.16, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(result.hurdles.first).spacing, 1.75, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(result.hurdles.last).spacing, 2.16, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(result.hurdles.last).pureCumulativePosition, 42.30, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(result.hurdles.last).cumulativePosition, 51.755, accuracy: 0.0001)
    }

    func testRoundedMaximumSpacingDrivesWorkbookTemplateAfterHalfUpRounding() throws {
        let result = try XCTUnwrap(
            MiniHurdleSpacingCalculator.calculate(
                greaterTrochanterLength: 0.863,
                profile: .women,
                strategy: .mannRecommended
            )
        )

        XCTAssertEqual(result.maximumSpacing, 2.03, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(result.hurdles.first).spacing, 1.62, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(result.hurdles.last).spacing, 2.03, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(result.hurdles.last).pureCumulativePosition, 39.57, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(result.hurdles.last).cumulativePosition, 48.18, accuracy: 0.0001)
    }

    func testWorksheetSequenceKeepsStartAccelerationAndHurdlesInOneContinuousExcelChain() throws {
        let result = try XCTUnwrap(
            MiniHurdleSpacingCalculator.calculate(
                greaterTrochanterLength: 0.86,
                profile: .women,
                strategy: .mannRecommended
            )
        )

        let sequence = result.worksheetSequence

        XCTAssertEqual(sequence.count, 29)
        XCTAssertEqual(sequence.map(\.worksheetStepNumber), Array(0...28))

        XCTAssertEqual(sequence[0].spacing, 0, accuracy: 0.0001)
        XCTAssertEqual(sequence[0].cumulativePosition, 0, accuracy: 0.0001)

        XCTAssertEqual(sequence[1].spacing, 0.565, accuracy: 0.0001)
        XCTAssertEqual(sequence[1].cumulativePosition, 0.565, accuracy: 0.0001)

        XCTAssertEqual(sequence[7].spacing, 1.53, accuracy: 0.0001)
        XCTAssertEqual(sequence[7].cumulativePosition, 8.545, accuracy: 0.0001)

        XCTAssertEqual(sequence[8].spacing, 1.61, accuracy: 0.0001)
        XCTAssertEqual(sequence[8].cumulativePosition, 10.155, accuracy: 0.0001)

        XCTAssertEqual(sequence[28].spacing, 2.02, accuracy: 0.0001)
        XCTAssertEqual(sequence[28].cumulativePosition, 47.905, accuracy: 0.0001)

        for index in 1..<sequence.count {
            XCTAssertEqual(
                sequence[index].cumulativePosition,
                sequence[index - 1].cumulativePosition + sequence[index].spacing,
                accuracy: 0.0001
            )
        }
    }

    func testRejectsNonPositiveGreaterTrochanterLength() {
        XCTAssertNil(
            MiniHurdleSpacingCalculator.calculate(
                greaterTrochanterLength: 0,
                profile: .women,
                strategy: .mannRecommended
            )
        )
    }

    func testRejectsConfigurationsWithNonPositiveFirstHurdleSpacing() {
        XCTAssertNil(
            MiniHurdleSpacingCalculator.calculate(
                greaterTrochanterLength: 0.1,
                profile: .women,
                strategy: .mannRecommended
            )
        )
    }

    private func assertMarks(
        _ marks: [MiniHurdleMark],
        expectedSteps: [Int],
        expectedWorksheetSteps: [Int],
        expectedSpacings: [Double],
        expectedCumulativePositions: [Double],
        expectedPureCumulativePositions: [Double],
        maximumSpacing: Double,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(marks.count, expectedSteps.count, file: file, line: line)
        XCTAssertEqual(marks.count, expectedWorksheetSteps.count, file: file, line: line)
        XCTAssertEqual(marks.count, expectedSpacings.count, file: file, line: line)
        XCTAssertEqual(marks.count, expectedCumulativePositions.count, file: file, line: line)
        XCTAssertEqual(marks.count, expectedPureCumulativePositions.count, file: file, line: line)

        for index in marks.indices {
            XCTAssertEqual(marks[index].stepNumber, expectedSteps[index], file: file, line: line)
            XCTAssertEqual(marks[index].worksheetStepNumber, expectedWorksheetSteps[index], file: file, line: line)
            XCTAssertEqual(marks[index].spacing, expectedSpacings[index], accuracy: 0.0001, file: file, line: line)
            XCTAssertEqual(
                marks[index].cumulativePosition,
                expectedCumulativePositions[index],
                accuracy: 0.0001,
                file: file,
                line: line
            )
            XCTAssertEqual(
                marks[index].pureCumulativePosition,
                expectedPureCumulativePositions[index],
                accuracy: 0.0001,
                file: file,
                line: line
            )
            XCTAssertEqual(
                marks[index].normalizedSpacing,
                expectedSpacings[index] / maximumSpacing,
                accuracy: 0.0001,
                file: file,
                line: line
            )
        }
    }

    private func assertAccelerationMarks(
        _ marks: [MiniHurdleAccelerationMark],
        expectedSteps: [Int],
        expectedSpacings: [Double],
        expectedCumulativePositions: [Double],
        maximumSpacing: Double,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(marks.count, expectedSteps.count, file: file, line: line)
        XCTAssertEqual(marks.count, expectedSpacings.count, file: file, line: line)
        XCTAssertEqual(marks.count, expectedCumulativePositions.count, file: file, line: line)

        for index in marks.indices {
            XCTAssertEqual(marks[index].stepNumber, expectedSteps[index], file: file, line: line)
            XCTAssertEqual(marks[index].spacing, expectedSpacings[index], accuracy: 0.0001, file: file, line: line)
            XCTAssertEqual(
                marks[index].cumulativePosition,
                expectedCumulativePositions[index],
                accuracy: 0.0001,
                file: file,
                line: line
            )
            XCTAssertEqual(
                marks[index].normalizedSpacing,
                expectedSpacings[index] / maximumSpacing,
                accuracy: 0.0001,
                file: file,
                line: line
            )
        }
    }

    private func assertDistanceValues(
        _ values: [Double],
        expected: [Double],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(values.count, expected.count, file: file, line: line)
        for index in values.indices {
            XCTAssertEqual(values[index], expected[index], accuracy: 0.0001, file: file, line: line)
        }
    }
}
