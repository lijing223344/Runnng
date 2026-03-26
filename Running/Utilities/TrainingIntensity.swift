import Foundation

enum TrainingIntensity {
    static let fullPercent = 100.0
    static let minPercent = 1.0
    static let maxPercent = 300.0
    static let quickOptions: [Double] = [80, 85, 90, 95, 100]

    static func sanitizeInput(_ input: String) -> String {
        input.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
    }

    static func parsePercent(_ input: String) -> Double? {
        let sanitized = sanitizeInput(input)
        guard let value = Double(sanitized), value > 0 else { return nil }
        return value
    }

    static func clampedPercent(_ value: Double) -> Double {
        min(maxPercent, max(minPercent, value))
    }

    static func adjustedTime(
        baseTimeAtHundredPercent: Double,
        intensityPercent: Double
    ) -> Double? {
        guard baseTimeAtHundredPercent > 0, intensityPercent > 0 else { return nil }
        return baseTimeAtHundredPercent * (fullPercent / intensityPercent)
    }

    static func baselineTime(
        trainingTimeAtSelectedIntensity: Double,
        intensityPercent: Double
    ) -> Double? {
        guard trainingTimeAtSelectedIntensity > 0, intensityPercent > 0 else { return nil }
        return trainingTimeAtSelectedIntensity * (intensityPercent / fullPercent)
    }

    static func displayText(_ value: Double) -> String {
        let rounded = value.rounded()
        if abs(value - rounded) < 0.0001 {
            return String(format: "%.0f", rounded)
        }
        return String(format: "%.1f", value)
    }

    static func isQuickSelected(currentPercent: Double?, option: Double) -> Bool {
        guard let currentPercent else { return false }
        return abs(currentPercent - option) < 0.0001
    }
}
