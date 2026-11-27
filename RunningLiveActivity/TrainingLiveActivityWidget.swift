import WidgetKit
import SwiftUI
import ActivityKit

// MARK: - Palette (mirrors DS.Colors; the extension has no app module)

private enum LA {
    static let compactWidth: CGFloat = 50
    static let bg      = Color(red: 0.043, green: 0.047, blue: 0.059) // #0B0C0F
    static let card    = Color(red: 0.075, green: 0.078, blue: 0.094) // #131418
    static let primary = Color(red: 0.929, green: 0.929, blue: 0.937)
    static let secondary = Color(red: 0.627, green: 0.627, blue: 0.655)
    static let muted   = Color(red: 0.482, green: 0.482, blue: 0.514)

    static func accent(_ hex: String) -> Color {
        let value = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard value.count == 6, let rgb = UInt32(value, radix: 16) else { return .white }
        return Color(
            red: Double((rgb >> 16) & 0xFF) / 255.0,
            green: Double((rgb >> 8) & 0xFF) / 255.0,
            blue: Double(rgb & 0xFF) / 255.0
        )
    }
}

// MARK: - Widget

@main
struct RunningLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        TrainingLiveActivityWidget()
    }
}

struct TrainingLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TrainingActivityAttributes.self) { context in
            LockScreenSessionView(state: context.state)
                .activityBackgroundTint(LA.bg)
                .activitySystemActionForegroundColor(LA.primary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Capsule()
                            .fill(LA.accent(context.state.accentHex))
                            .frame(width: 3, height: 26)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(context.state.kindLabel)
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(LA.muted)
                            Text(context.state.planTitle)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(LA.primary)
                                .lineLimit(1)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 1) {
                        LiveCountdown(state: context.state)
                            .font(.system(size: 17, weight: .medium, design: .monospaced))
                            .foregroundStyle(context.state.isPaused ? LA.secondary : LA.primary)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 64, alignment: .trailing)
                        Text(context.state.stepLabel)
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .foregroundStyle(LA.muted)
                            .lineLimit(1)
                            .frame(width: 64, alignment: .trailing)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.phaseLabel)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(LA.primary)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 5) {
                        ProgressRail(progress: context.state.progress, accentHex: context.state.accentHex)
                        HStack {
                            Text(context.state.detailLabel)
                                .font(.system(size: 10))
                                .foregroundStyle(LA.secondary)
                                .lineLimit(1)
                            Spacer()
                            if context.state.isPaused || context.state.isComplete {
                                Text(context.state.statusLabel)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(LA.secondary)
                            }
                        }
                    }
                }
            } compactLeading: {
                CompactStep(state: context.state)
            } compactTrailing: {
                LiveCountdown(state: context.state)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(context.state.isPaused ? LA.secondary : LA.primary)
                    .multilineTextAlignment(.trailing)
                    .minimumScaleFactor(0.72)
                    .frame(width: LA.compactWidth, alignment: .trailing)
            } minimal: {
                LiveCountdown(state: context.state)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(LA.accent(context.state.accentHex))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.65)
                    .frame(width: 30)
            }
            .keylineTint(LA.accent(context.state.accentHex))
        }
    }
}

private struct CompactStep: View {
    let state: TrainingActivityAttributes.ContentState

    var body: some View {
        let counter = state.compactLabel.isEmpty ? state.stepLabel : state.compactLabel
        HStack(spacing: 5) {
            Capsule()
                .fill(LA.accent(state.accentHex))
                .frame(width: 3, height: 15)
            Group {
                if state.isPaused || counter.isEmpty {
                    Image(systemName: state.isPaused ? "pause.fill" : "timer")
                        .accessibilityLabel(state.statusLabel)
                } else {
                    ViewThatFits(in: .horizontal) {
                        Text(verbatim: counter).fixedSize()
                        Text(verbatim: counter)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .fixedSize()
                        Text(verbatim: String(counter.prefix { $0 != "/" }))
                    }
                    .accessibilityLabel(Text(verbatim: state.stepLabel))
                }
            }
            .transition(.identity)
            .contentTransition(.identity)
        }
        .font(.system(size: 12, weight: .semibold, design: .monospaced))
        .monospacedDigit()
        .foregroundStyle(state.isPaused ? LA.secondary : LA.primary)
        .lineLimit(1)
        // SpringBoard sizes this half of the island from its content's ideal width.
        .frame(width: LA.compactWidth, alignment: .leading)
        .animation(nil, value: state)
    }
}

// MARK: - Lock screen / Always-On

private struct LockScreenSessionView: View {
    let state: TrainingActivityAttributes.ContentState

    private var accent: Color { LA.accent(state.accentHex) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 9) {
                Capsule()
                    .fill(accent)
                    .frame(width: 3, height: 26)
                VStack(alignment: .leading, spacing: 1) {
                    Text(state.kindLabel)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(LA.muted)
                    Text(state.planTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LA.primary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Text(state.statusLabel)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(state.isComplete ? accent : LA.secondary)
            }

            HStack(alignment: .lastTextBaseline, spacing: 12) {
                remaining
                    .font(.system(size: 40, weight: .medium, design: .monospaced))
                    .foregroundStyle(state.isPaused || state.isComplete ? LA.secondary : LA.primary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                VStack(alignment: .leading, spacing: 3) {
                    Text(state.phaseLabel)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(LA.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text(state.detailLabel)
                        .font(.system(size: 11))
                        .foregroundStyle(LA.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Text(state.stepLabel)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(LA.muted)
            }

            ProgressRail(progress: state.progress, accentHex: state.accentHex)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(LA.bg)
    }

    private var remaining: some View { LiveCountdown(state: state) }
}

/// One clock used everywhere. While a block is live it is drawn by the system
/// timer so it advances without any ActivityKit update; when paused or done it
/// falls back to the frozen text. The fixed width keeps the digits from
/// re-measuring the surrounding layout on every second.
private struct LiveCountdown: View {
    let state: TrainingActivityAttributes.ContentState

    var body: some View {
        Group {
            if let end = state.endDate, !state.isPaused, !state.isComplete {
                Text(timerInterval: min(Date.now, end)...end, countsDown: true)
            } else {
                Text(verbatim: state.remainingText)
            }
        }
        .monospacedDigit()
        .lineLimit(1)
        .contentTransition(.identity)
        .transition(.identity)
        .animation(nil, value: state)
    }
}

private struct ProgressRail: View {
    let progress: Double
    let accentHex: String

    var body: some View {
        Capsule()
            .fill(Color.white.opacity(0.10))
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(LA.accent(accentHex))
                    // Scale, not width: a progress step must not trigger a
                    // layout pass inside the island.
                    .scaleEffect(x: max(0.001, min(max(progress, 0), 1)), y: 1, anchor: .leading)
            }
            .frame(height: 2)
            .clipShape(Capsule())
    }
}
