import Foundation

enum FourHundredModelProfile: String, CaseIterable, Identifiable {
    case women
    case men

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .women:
            return "model_400_profile_women".localized
        case .men:
            return "model_400_profile_men".localized
        }
    }

    var suggestedTargetTime: Double {
        switch self {
        case .women:
            return 57.0
        case .men:
            return 47.75
        }
    }

    var cumulativePercentages: [Int: Double] {
        switch self {
        case .women:
            return [
                50: 0.1341,
                100: 0.2436,
                150: 0.3574,
                200: 0.4765,
                250: 0.5995,
                300: 0.7263,
                350: 0.8582
            ]
        case .men:
            return [
                50: 0.1390,
                100: 0.2490,
                150: 0.3618,
                200: 0.4782,
                250: 0.6003,
                300: 0.7279,
                350: 0.8597
            ]
        }
    }
}

enum FourHundredSplitGranularity: Int, CaseIterable, Identifiable {
    case _50 = 50
    case _100 = 100
    case _200 = 200

    var id: Int { rawValue }

    var displayName: String {
        "\(rawValue)\("unit_meter_short".localized)"
    }
}

struct FourHundredSplit: Identifiable {
    let startDistance: Int
    let endDistance: Int
    let time: Double

    var id: Int { endDistance }
}

struct FourHundredCheckpoint: Identifiable {
    let distance: Int
    let time: Double

    var id: Int { distance }
}

struct FourHundredModelMetrics {
    let first200: Double
    let last200: Double
    let last200Delta: Double
    let threeHundredOverTwoHundred: Double
    let fourHundredOverThreeHundred: Double
    let last200OverFirst200: Double
    let estimated200PB: Double
    let estimated200PBShareOf400: Double
}

struct FourHundredModelResult {
    let profile: FourHundredModelProfile
    let finalTime: Double
    let cumulative: [FourHundredCheckpoint]
    let split50: [FourHundredSplit]
    let split100: [FourHundredSplit]
    let split200: [FourHundredSplit]
    let metrics: FourHundredModelMetrics

    func splits(for granularity: FourHundredSplitGranularity) -> [FourHundredSplit] {
        switch granularity {
        case ._50:
            return split50
        case ._100:
            return split100
        case ._200:
            return split200
        }
    }
}

enum FourHundredModelCalculator {
    private static let checkpoints = [50, 100, 150, 200, 250, 300, 350, 400]
    private static let pb200Multiplier = 1.05

    static func calculate(profile: FourHundredModelProfile, finalTime: Double) -> FourHundredModelResult? {
        guard finalTime > 0 else { return nil }

        let cumulative = checkpoints.map { distance -> FourHundredCheckpoint in
            if distance == 400 {
                return FourHundredCheckpoint(distance: 400, time: finalTime)
            }
            let percentage = profile.cumulativePercentages[distance] ?? 0
            return FourHundredCheckpoint(distance: distance, time: finalTime * percentage)
        }

        let cumulativeTimes = Dictionary(uniqueKeysWithValues: cumulative.map { ($0.distance, $0.time) })
        let split50 = makeSplits(endingAt: [50, 100, 150, 200, 250, 300, 350, 400], cumulativeTimes: cumulativeTimes)
        let split100 = makeSplits(endingAt: [100, 200, 300, 400], cumulativeTimes: cumulativeTimes)
        let split200 = makeSplits(endingAt: [200, 400], cumulativeTimes: cumulativeTimes)

        guard let first200 = split200.first?.time, let last200 = split200.last?.time else { return nil }

        let metrics = FourHundredModelMetrics(
            first200: first200,
            last200: last200,
            last200Delta: last200 - first200,
            threeHundredOverTwoHundred: (cumulativeTimes[300] ?? 0) / max(first200, 0.0001),
            fourHundredOverThreeHundred: finalTime / max(cumulativeTimes[300] ?? 0.0001, 0.0001),
            last200OverFirst200: last200 / max(first200, 0.0001),
            estimated200PB: first200 / pb200Multiplier,
            estimated200PBShareOf400: (first200 / pb200Multiplier) / finalTime
        )

        return FourHundredModelResult(
            profile: profile,
            finalTime: finalTime,
            cumulative: cumulative,
            split50: split50,
            split100: split100,
            split200: split200,
            metrics: metrics
        )
    }

    static func makeDraftTraining(
        profile: FourHundredModelProfile,
        finalTime: Double,
        granularity: FourHundredSplitGranularity,
        intensityPercent: Double = TrainingIntensity.fullPercent
    ) -> PaceRunTraining? {
        guard let adjustedFinalTime = adjustedFinalTime(
            targetTimeAtHundredPercent: finalTime,
            intensityPercent: intensityPercent
        ) else {
            return nil
        }

        guard let result = calculate(profile: profile, finalTime: adjustedFinalTime) else { return nil }

        let sound = SoundType.allCases.first ?? .whistleShort
        let splits = result.splits(for: granularity)
        let customSegments = splits.map { split in
            CustomSegment(distance: split.endDistance - split.startDistance, time: split.time, restAfter: 0)
        }

        let title = String(
            format: "model_400_plan_name_format".localized,
            profile.displayName,
            formatTime(adjustedFinalTime),
            granularity.rawValue
        )

        let group = PaceRunGroup(
            name: title,
            colorHex: GroupColor.blue.rawValue,
            totalDistance: 400,
            segmentDistance: granularity.rawValue,
            totalTime: adjustedFinalTime,
            countdownSeconds: 3,
            setCount: nil,
            setRestTime: nil,
            segmentSound: sound,
            startSound: sound,
            endSound: sound,
            sortOrder: 0,
            customSegments: customSegments
        )

        return PaceRunTraining(
            name: title,
            groups: [group],
            countdownSeconds: 3
        )
    }

    static func adjustedFinalTime(
        targetTimeAtHundredPercent: Double,
        intensityPercent: Double
    ) -> Double? {
        TrainingIntensity.adjustedTime(
            baseTimeAtHundredPercent: targetTimeAtHundredPercent,
            intensityPercent: intensityPercent
        )
    }

    private static func makeSplits(endingAt checkpoints: [Int], cumulativeTimes: [Int: Double]) -> [FourHundredSplit] {
        var start = 0
        var previousTime = 0.0

        return checkpoints.compactMap { end in
            guard let cumulativeTime = cumulativeTimes[end] else { return nil }
            defer {
                start = end
                previousTime = cumulativeTime
            }
            return FourHundredSplit(startDistance: start, endDistance: end, time: cumulativeTime - previousTime)
        }
    }

    private static func formatTime(_ value: Double) -> String {
        let hundredths = Int((value * 100).rounded())
        let seconds = hundredths / 100
        let centiseconds = hundredths % 100
        return String(format: "%d.%02d", seconds, centiseconds)
    }
}
