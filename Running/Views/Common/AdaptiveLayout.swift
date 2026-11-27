import SwiftUI

enum DSLayout {
    static let wideBreakpoint: CGFloat = 700
    static func isWide(_ width: CGFloat) -> Bool { width >= wideBreakpoint }
}

/// Reserves the controls' actual height when the device rotates or an
/// authorization hint appears. Both controls and timer use the same safe area.
struct TrainingSessionScreen<Content: View>: View {
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    let accent: Color
    let isPaused: Bool
    let isComplete: Bool
    let showsActivityHint: Bool
    let onPause: () -> Void
    let onRestart: () -> Void
    let onStop: () -> Void
    let content: Content

    init(accent: Color, isPaused: Bool, isComplete: Bool, showsActivityHint: Bool,
         onPause: @escaping () -> Void, onRestart: @escaping () -> Void, onStop: @escaping () -> Void,
         @ViewBuilder content: () -> Content) {
        self.accent = accent
        self.isPaused = isPaused
        self.isComplete = isComplete
        self.showsActivityHint = showsActivityHint
        self.onPause = onPause
        self.onRestart = onRestart
        self.onStop = onStop
        self.content = content()
    }

    var body: some View {
        let compact = verticalSizeClass == .compact
        let height: CGFloat = compact ? 44 : 56
        let highlighted = isComplete || isPaused
        VStack(spacing: 0) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if showsActivityHint {
                LiveActivityUnavailableHint()
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
            }
            HStack(spacing: 12) {
                Button(action: isComplete ? onRestart : onPause) {
                    Label((isComplete ? "restart_training" : isPaused ? "resume" : "pause").localized,
                          systemImage: isComplete ? "arrow.clockwise" : isPaused ? "play.fill" : "pause.fill")
                        .foregroundStyle(highlighted ? .white : DS.Colors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: height)
                        .trainingControlSurface(highlighted: highlighted, accent: accent)
                }
                .accessibilityIdentifier("training_pause_resume")
                Button(action: onStop) {
                    Label("stop".localized, systemImage: "stop.fill")
                        .foregroundStyle(DS.Colors.error)
                        .frame(width: 110, height: height)
                        .trainingStopSurface()
                }
            }
            .labelStyle(.titleAndIcon)
            .font(.system(size: 16, weight: .semibold))
            .padding(.horizontal, 16)
            .padding(.top, compact ? 4 : 12)
            .padding(.bottom, compact ? 4 : 32)
        }
        .background(Color.black.ignoresSafeArea())
    }
}

/// Two-pane session shell. Each pane scrolls independently so the timer never
/// moves off screen while the coach browses the remaining work.
struct DSTrainingSplit<Leading: View, Trailing: View>: View {
    let width: CGFloat
    /// Optional floor for the content height so a short block sits in the
    /// optical middle of a tall canvas instead of hugging the top edge.
    var fillHeight: CGFloat = 0
    @ViewBuilder var leading: () -> Leading
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                leading()
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: fillHeight, alignment: .center)
            }
            .frame(width: max(340, min(width * 0.54, 560)))

            Rectangle()
                .fill(DS.Colors.borderLight)
                .frame(width: 1)

            ScrollView(showsIndicators: false) {
                trailing()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: fillHeight, alignment: .center)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

extension View {
    /// Keeps long reading columns comfortable on a wide canvas instead of
    /// stretching line length across the whole display.
    func dsReadableColumn(_ maxWidth: CGFloat = 860) -> some View {
        // A single cap is enough: the scroll container proposes its own finite
        // width, so the frame shrinks to the screen on a phone and to the cap on
        // a wide canvas. A second maxWidth: .infinity here would propose
        // infinity and force 720 pt even on a 402 pt phone, clipping the right
        // edge of every card.
        frame(maxWidth: maxWidth)
    }
}
