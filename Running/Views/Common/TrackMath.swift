import SwiftUI

enum TrackMath {
    static func normalizedValues(from source: [Double], desired: Int, fallback: Double) -> [Double] {
        let targetCount = max(1, desired)
        let normalized: [Double]
        if source.count == targetCount {
            normalized = source
        } else if source.isEmpty {
            normalized = Array(repeating: fallback, count: targetCount)
        } else if source.count > targetCount {
            normalized = Array(source.prefix(targetCount))
        } else {
            let padding = Array(repeating: source.last ?? fallback, count: targetCount - source.count)
            normalized = source + padding
        }
        return normalized.map { max(0, $0) }
    }

    static func slotWidths(totalWidth: CGFloat, gap: CGFloat, weights: [Double], count: Int) -> [CGFloat] {
        let safeCount = max(1, count)
        let totalGaps = CGFloat(max(0, safeCount - 1)) * gap
        let availableWidth = max(1, totalWidth - totalGaps)
        let normalized = Array(weights.prefix(safeCount))
        let totalWeight = max(0.001, normalized.reduce(0, +))
        return normalized.map { availableWidth * CGFloat($0 / totalWeight) }
    }

    static func boundaryPositions(widths: [CGFloat], gap: CGFloat) -> [CGFloat] {
        guard !widths.isEmpty else { return [0] }
        var points: [CGFloat] = [0]
        points.reserveCapacity(widths.count + 1)
        var cursor: CGFloat = 0
        for idx in widths.indices {
            cursor += widths[idx]
            points.append(cursor)
            if idx < widths.count - 1 {
                cursor += gap
            }
        }
        return points
    }
}

enum TrackVisualStyle {
    static let slotHeight: CGFloat = 12
    static let compactHeight: CGFloat = 12
    static let activeShadowRadius: CGFloat = 3
    static let activeShadowOpacity: Double = 0.45
    static let activeOutlineWidth: CGFloat = 1
    static let inlineLabelSize: CGFloat = 8
}

extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0, index < count else { return nil }
        return self[index]
    }
}
