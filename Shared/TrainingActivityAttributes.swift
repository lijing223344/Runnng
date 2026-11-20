import Foundation
import ActivityKit

/// Shared contract between the app and the Live Activity extension.
/// Every visible string is prepared by the app in the current interface
/// language, so the widget never needs its own string table.
///
/// Note: the iOS app target defaults to `MainActor` isolation, while the
/// extension target compiles without it. Keeping this type non-isolated
/// makes its `ActivityAttributes` conformance safe to use from both the
/// app's `MainActor` Manager and the extension's concurrent ActivityKit
/// callbacks, without main-actor-isolated-conformance warnings.
nonisolated public struct TrainingActivityAttributes: ActivityAttributes, Sendable {

    public struct ContentState: Codable, Hashable {
        /// Discipline name, e.g. "节奏跑" / "Interval".
        public var kindLabel: String
        /// Plan name shown in the header.
        public var planTitle: String
        /// Current block, e.g. "第 3/8 段 · 400 m".
        public var phaseLabel: String
        /// Secondary line, e.g. pace, rest or set context.
        public var detailLabel: String
        /// Step counter, e.g. "3 / 8".
        public var stepLabel: String
        /// Narrow variant used by the island's compact trailing slot, e.g. "3/8".
        /// Kept short so the island never has to resize between steps.
        public var compactLabel: String
        /// Frozen remaining text for paused/static states.
        public var remainingText: String
        /// Absolute end of the current block, used for self-ticking text.
        public var endDate: Date?
        /// 0...1 across the whole session.
        public var progress: Double
        /// Accent colour for the discipline tick, hex without '#'.
        public var accentHex: String
        public var isPaused: Bool
        public var isComplete: Bool
        /// Localized status word shown at a glance, e.g. "已暂停" / "Paused".
        public var statusLabel: String

        public init(
            kindLabel: String,
            planTitle: String,
            phaseLabel: String,
            detailLabel: String,
            stepLabel: String,
            compactLabel: String = "",
            remainingText: String,
            endDate: Date?,
            progress: Double,
            accentHex: String,
            isPaused: Bool,
            isComplete: Bool,
            statusLabel: String
        ) {
            self.kindLabel = kindLabel
            self.planTitle = planTitle
            self.phaseLabel = phaseLabel
            self.detailLabel = detailLabel
            self.stepLabel = stepLabel
            self.compactLabel = compactLabel
            self.remainingText = remainingText
            self.endDate = endDate
            self.progress = progress
            self.accentHex = accentHex
            self.isPaused = isPaused
            self.isComplete = isComplete
            self.statusLabel = statusLabel
        }
    }

    /// Stable identifier for the session; prevents orphan activities.
    public var trainingID: String

    public init(trainingID: String) {
        self.trainingID = trainingID
    }
}
