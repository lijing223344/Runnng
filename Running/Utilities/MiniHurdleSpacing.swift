import Foundation

enum MiniHurdleProfile: String, Codable, CaseIterable, Identifiable {
    case women
    case men

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .women:
            return "mini_hurdle_profile_women".localized
        case .men:
            return "mini_hurdle_profile_men".localized
        }
    }

    var clarkLowerRatio: Double {
        switch self {
        case .women: return 2.25
        case .men: return 2.30
        }
    }

    var clarkUpperRatio: Double {
        switch self {
        case .women: return 2.45
        case .men: return 2.50
        }
    }

    var mannRecommendedRatio: Double {
        switch self {
        case .women: return 2.35
        case .men: return 2.43
        }
    }
}

enum MiniHurdleMeasurementUnit: String, Codable, CaseIterable, Identifiable {
    case centimeters
    case meters

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .centimeters:
            return "mini_hurdle_measurement_unit_cm".localized
        case .meters:
            return "mini_hurdle_measurement_unit_m".localized
        }
    }

    var metricFormat: String {
        switch self {
        case .centimeters:
            return "%.0f cm"
        case .meters:
            return "%.2f m"
        }
    }
}

enum MiniHurdleStrategyKind: String, Codable, CaseIterable, Identifiable {
    case clarkRange
    case mannRecommended

    var id: String { rawValue }

    /// 兼容历史持久化值：早期版本的 clarkLowerBound / clarkUpperBound / custom
    /// 统一映射为 clarkRange（其 customRatio 字段仍保留原系数）。
    init?(rawValue: String) {
        switch rawValue {
        case "mannRecommended":
            self = .mannRecommended
        default:
            self = .clarkRange
        }
    }

    var title: String {
        switch self {
        case .clarkRange:
            return "mini_hurdle_strategy_clark_range".localized
        case .mannRecommended:
            return "mini_hurdle_strategy_mann".localized
        }
    }

    var subtitle: String {
        switch self {
        case .clarkRange:
            return "mini_hurdle_strategy_clark_range_desc".localized
        case .mannRecommended:
            return "mini_hurdle_strategy_mann_desc".localized
        }
    }

    var currentNote: String {
        switch self {
        case .clarkRange:
            return "mini_hurdle_strategy_note_clark_range".localized
        case .mannRecommended:
            return "mini_hurdle_strategy_note_mann".localized
        }
    }
}

enum MiniHurdleStrategy: Hashable, Identifiable, CaseIterable {
    case clarkLowerBound
    case mannRecommended
    case clarkUpperBound
    case custom(ratio: Double)

    static var allCases: [MiniHurdleStrategy] {
        [.clarkLowerBound, .mannRecommended, .clarkUpperBound, .custom(ratio: 2.35)]
    }

    var id: String {
        switch self {
        case .clarkLowerBound:
            return "clark-lower"
        case .mannRecommended:
            return "mann-recommended"
        case .clarkUpperBound:
            return "clark-upper"
        case .custom:
            return "custom"
        }
    }

    func ratio(for profile: MiniHurdleProfile) -> Double {
        switch self {
        case .clarkLowerBound:
            return profile.clarkLowerRatio
        case .mannRecommended:
            return profile.mannRecommendedRatio
        case .clarkUpperBound:
            return profile.clarkUpperRatio
        case .custom(let ratio):
            return ratio
        }
    }
}

struct MiniHurdleMark: Identifiable {
    let title: String
    let stepNumber: Int
    let worksheetStepNumber: Int
    let spacing: Double
    let cumulativePosition: Double
    let pureCumulativePosition: Double
    let normalizedSpacing: Double

    var id: String { "\(title)-\(worksheetStepNumber)" }
}

typealias MiniHurdleAccelerationMark = MiniHurdleMark

struct MiniHurdlePlacementMark: Identifiable {
    let hurdleNumber: Int
    let spacing: Double
    let positionFromStart: Double
    let positionFromFirstHurdle: Double

    var worksheetCoordinate: Double { positionFromStart }

    var id: Int { hurdleNumber }
}

struct MiniHurdleSpacingResult {
    let greaterTrochanterLength: Double
    let profile: MiniHurdleProfile
    let strategy: MiniHurdleStrategy
    let selectedRatio: Double
    let clarkLowerRatio: Double
    let clarkUpperRatio: Double
    let mannRecommendedRatio: Double
    let maximumSpacing: Double
    let minimumSpacing: Double
    let clarkLowerSpacing: Double
    let clarkUpperSpacing: Double
    let mannRecommendedSpacing: Double
    let accelerationMarks: [MiniHurdleMark]
    let hurdles: [MiniHurdleMark]
    let hurdlePlacements: [MiniHurdlePlacementMark]
    let worksheetStartPosition: Double
    let leadInDistanceToFirstHurdle: Double

    var worksheetSequence: [MiniHurdleMark] {
        let startMark = MiniHurdleMark(
            title: "mini_hurdle_mark_start".localized,
            stepNumber: 0,
            worksheetStepNumber: 0,
            spacing: 0,
            cumulativePosition: worksheetStartPosition,
            pureCumulativePosition: 0,
            normalizedSpacing: 0
        )
        return [startMark] + accelerationMarks + hurdles
    }

    var totalLayoutDistance: Double {
        hurdles.last?.cumulativePosition ?? 0
    }

    var pureLayoutDistance: Double {
        hurdles.last?.pureCumulativePosition ?? 0
    }

    var hurdlePlacementDistance: Double {
        hurdlePlacements.last?.positionFromFirstHurdle ?? 0
    }

    var firstHurdleCoordinate: Double {
        hurdlePlacements.first?.positionFromStart ?? 0
    }

    var lastHurdleCoordinate: Double {
        hurdlePlacements.last?.positionFromStart ?? 0
    }

    var recommendedRunOutDistance: Double {
        20
    }
}

enum MiniHurdleSpacingCalculator {
    private static let accelerationMarkStepDowns: [Decimal] = [
        decimal("-0.48"),
        decimal("-0.48"),
        decimal("-0.40"),
        decimal("-0.32"),
        decimal("-0.24"),
        decimal("-0.16"),
        decimal("-0.08")
    ]
    private static let hurdleOffsets: [Decimal] = [
        decimal("-0.41"), decimal("-0.41"),
        decimal("-0.33"), decimal("-0.33"),
        decimal("-0.25"), decimal("-0.25"),
        decimal("-0.18"), decimal("-0.18"), decimal("-0.18"),
        decimal("-0.10"), decimal("-0.10"), decimal("-0.10"),
        decimal("-0.05"), decimal("-0.05"), decimal("-0.05"),
        decimal("-0.03"), decimal("-0.03"), decimal("-0.03"),
        decimal("0"), decimal("0"), decimal("0")
    ]

    static func calculate(
        greaterTrochanterLength: Double,
        profile: MiniHurdleProfile,
        strategy: MiniHurdleStrategy
    ) -> MiniHurdleSpacingResult? {
        guard greaterTrochanterLength.isFinite, greaterTrochanterLength > 0 else { return nil }

        let selectedRatio = strategy.ratio(for: profile)
        guard selectedRatio.isFinite, selectedRatio > 0 else { return nil }

        let maximumSpacingDecimal = roundedProduct(greaterTrochanterLength, selectedRatio)
        let lowerSpacingDecimal = roundedProduct(greaterTrochanterLength, profile.clarkLowerRatio)
        let upperSpacingDecimal = roundedProduct(greaterTrochanterLength, profile.clarkUpperRatio)
        let recommendedSpacingDecimal = roundedProduct(greaterTrochanterLength, profile.mannRecommendedRatio)

        let maximumSpacing = doubleValue(maximumSpacingDecimal)
        let lowerSpacing = doubleValue(lowerSpacingDecimal)
        let upperSpacing = doubleValue(upperSpacingDecimal)
        let recommendedSpacing = doubleValue(recommendedSpacingDecimal)

        let hurdleSpacings = hurdleOffsets.map { rounded(maximumSpacingDecimal + $0, scale: 2) }
        guard hurdleSpacings.allSatisfy({ doubleValue($0) > 0 }) else { return nil }
        let openingSpacingDecimal = hurdleSpacings[0]

        let accelerationSpacings = makeAccelerationSpacings(openingSpacing: openingSpacingDecimal)
        guard accelerationSpacings.allSatisfy({ doubleValue($0) > 0 }) else { return nil }

        let accelerationMarks = makeMarks(
            titlePrefix: "mini_hurdle_acc_mark".localized,
            startStepNumber: 1,
            worksheetStartStepNumber: 1,
            spacings: accelerationSpacings,
            maximumSpacing: maximumSpacingDecimal,
            worksheetStartingPosition: decimal("0"),
            pureStartingPosition: decimal("0")
        )

        let hurdleMarks = makeMarks(
            titlePrefix: "mini_hurdle_hurdle".localized,
            startStepNumber: 1,
            worksheetStartStepNumber: 8,
            spacings: hurdleSpacings,
            maximumSpacing: maximumSpacingDecimal,
            worksheetStartingPosition: decimal(accelerationMarks.last?.cumulativePosition ?? 0),
            pureStartingPosition: decimal("0")
        )

        let hurdlePlacements = makePlacementMarks(from: hurdleMarks)

        return MiniHurdleSpacingResult(
            greaterTrochanterLength: greaterTrochanterLength,
            profile: profile,
            strategy: strategy,
            selectedRatio: selectedRatio,
            clarkLowerRatio: profile.clarkLowerRatio,
            clarkUpperRatio: profile.clarkUpperRatio,
            mannRecommendedRatio: profile.mannRecommendedRatio,
            maximumSpacing: maximumSpacing,
            minimumSpacing: doubleValue(hurdleSpacings.first ?? maximumSpacingDecimal),
            clarkLowerSpacing: lowerSpacing,
            clarkUpperSpacing: upperSpacing,
            mannRecommendedSpacing: recommendedSpacing,
            accelerationMarks: accelerationMarks,
            hurdles: hurdleMarks,
            hurdlePlacements: hurdlePlacements,
            worksheetStartPosition: 0,
            leadInDistanceToFirstHurdle: doubleValue(openingSpacingDecimal)
        )
    }

    private static func makeAccelerationSpacings(openingSpacing: Decimal) -> [Decimal] {
        accelerationMarkStepDowns.enumerated().map { index, offset in
            let value = openingSpacing + offset
            let scale = index == 0 ? 3 : 2
            return rounded(index == 0 ? value / decimal("2") : value, scale: scale)
        }
    }

    private static func makeMarks(
        titlePrefix: String,
        startStepNumber: Int,
        worksheetStartStepNumber: Int,
        spacings: [Decimal],
        maximumSpacing: Decimal,
        worksheetStartingPosition: Decimal,
        pureStartingPosition: Decimal
    ) -> [MiniHurdleMark] {
        var worksheetCumulative = worksheetStartingPosition
        var pureCumulative = pureStartingPosition
        return spacings.enumerated().map { index, spacing in
            worksheetCumulative += spacing
            pureCumulative += spacing
            return MiniHurdleMark(
                title: "\(titlePrefix) \(index + 1)",
                stepNumber: startStepNumber + index,
                worksheetStepNumber: worksheetStartStepNumber + index,
                spacing: doubleValue(spacing),
                cumulativePosition: doubleValue(worksheetCumulative),
                pureCumulativePosition: doubleValue(pureCumulative),
                normalizedSpacing: doubleValue(spacing / maximumSpacing)
            )
        }
    }

    private static func makePlacementMarks(from hurdleMarks: [MiniHurdleMark]) -> [MiniHurdlePlacementMark] {
        guard let firstCoordinate = hurdleMarks.first?.cumulativePosition else { return [] }
        return hurdleMarks.enumerated().map { index, mark in
            MiniHurdlePlacementMark(
                hurdleNumber: index + 1,
                spacing: mark.spacing,
                positionFromStart: mark.cumulativePosition,
                positionFromFirstHurdle: mark.cumulativePosition - firstCoordinate,
            )
        }
    }

    private static func roundedProduct(_ greaterTrochanterLength: Double, _ ratio: Double) -> Decimal {
        let product = decimal(greaterTrochanterLength) * decimal(ratio)
        return rounded(product, scale: 2)
    }

    private static func rounded(_ value: Decimal, scale: Int) -> Decimal {
        var source = value
        var rounded = Decimal()
        NSDecimalRound(&rounded, &source, scale, .plain)
        return rounded
    }

    private static func decimal(_ value: Double) -> Decimal {
        Decimal(string: String(value), locale: Locale(identifier: "en_US_POSIX")) ?? Decimal(value)
    }

    private static func decimal(_ value: String) -> Decimal {
        Decimal(string: value, locale: Locale(identifier: "en_US_POSIX")) ?? 0
    }

    private static func doubleValue(_ value: Decimal) -> Double {
        NSDecimalNumber(decimal: value).doubleValue
    }
}
