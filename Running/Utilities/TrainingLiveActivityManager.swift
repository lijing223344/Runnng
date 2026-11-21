import Foundation
import ActivityKit
import UIKit
import os.log

/// Owns the Live Activity that mirrors an active session onto the Lock Screen,
/// Always-On Display and Dynamic Island.
///
/// The session UI is the source of truth: it hands over already-localized
/// strings plus an absolute block end date, so the widget can tick by itself
/// without waking the app every second.
///
/// Lifecycle contract: the activity follows the session, not the foreground
/// state. A running session keeps the process alive in the background through
/// its audio keep-alive, so the card deliberately stays on the Lock Screen and
/// Dynamic Island while the app is backgrounded — phase pushes keep coming
/// from the still-running process and the widget self-ticks between them. An
/// activity must never outlive the session, though: it is ended on explicit
/// stop/complete/disappear, best-effort on termination, and on next launch as
/// a sweep over anything a killed process left behind. If the process dies
/// anyway, the staleDate lets the system mark the card outdated instead of
/// presenting a frozen clock as if it were live.
@MainActor
final class TrainingLiveActivityManager {

    static let shared = TrainingLiveActivityManager()

    private var activity: Activity<TrainingActivityAttributes>?
    private var activityTrainingID: String?
    private var lastSignature = ""
    private var lastPushAt = Date.distantPast
    private var willTerminateObserver: NSObjectProtocol?
    private let log = Logger(subsystem: "SCTN.Running", category: "LiveActivity")

    private init() {
        registerLifecycleObservers()
        Task { await sweepOrphanedActivities() }
    }

    deinit {
        if let willTerminateObserver { NotificationCenter.default.removeObserver(willTerminateObserver) }
    }

    var isEnabled: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    // MARK: - Session lifecycle

    func begin(trainingID: UUID, state: TrainingActivityAttributes.ContentState) {
        begin(trainingID: trainingID.uuidString, state: state)
    }

    func begin(trainingID: String, state: TrainingActivityAttributes.ContentState) {
        guard isEnabled else {
            log.notice("Live Activities disabled by system settings")
            return
        }
        if let activity, activityTrainingID == trainingID {
            push(state, to: activity, force: true)
            return
        }
        // A different session is starting: close any stale card first so two
        // activities for different sessions can never coexist. The registry
        // pass also retires untracked leftovers the in-memory reference no
        // longer knows about — a 90 s grace card from the previous session,
        // or an orphan left by a crashed process.
        if activity != nil {
            endAllImmediately()
        }
        Task { [trainingID] in
            for other in Activity<TrainingActivityAttributes>.activities
            where other.attributes.trainingID != trainingID {
                await other.end(nil, dismissalPolicy: .immediate)
            }
        }

        do {
            let attributes = TrainingActivityAttributes(trainingID: trainingID)
            let content = ActivityContent(state: state, staleDate: staleDate(for: state))
            activity = try Activity.request(attributes: attributes, content: content, pushType: nil)
            activityTrainingID = trainingID
            log.notice("started \(trainingID, privacy: .public)")
            lastSignature = signature(of: state)
            lastPushAt = Date()
        } catch {
            log.error("request failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Called from the training tick. ActivityKit re-renders the whole island
    /// on every push, so pushes are event-driven: only a changed phase, step,
    /// pause/complete flag, colour or a 10% progress step is sent. The clock
    /// itself is rendered by `Text(timerInterval:)` inside the widget, which
    /// means a quiet second never touches the island and it cannot wobble.
    func update(_ state: TrainingActivityAttributes.ContentState) {
        guard let activity else { return }
        let newSignature = signature(of: state)
        guard newSignature != lastSignature else { return }
        let now = Date()
        guard now.timeIntervalSince(lastPushAt) >= 0.4 else { return }
        lastSignature = newSignature
        lastPushAt = now
        push(state, to: activity, force: false)
    }

    func end(final state: TrainingActivityAttributes.ContentState? = nil,
             keepVisibleFor seconds: TimeInterval = 0) {
        guard let activity else { return }
        let current = activity
        self.activity = nil
        activityTrainingID = nil
        lastSignature = ""
        let dismissal: ActivityUIDismissalPolicy = seconds > 0
            ? .after(Date().addingTimeInterval(seconds))
            : .immediate
        Task {
            if let state {
                await current.end(ActivityContent(state: state, staleDate: staleDate(for: state)), dismissalPolicy: dismissal)
            } else {
                await current.end(nil, dismissalPolicy: dismissal)
            }
        }
    }

    /// Ends every tracked activity immediately, with no grace card. Used when
    /// a different session takes over, or as a best-effort when the app is
    /// about to be terminated, so the island never keeps showing a session
    /// that is no longer running.
    func endAllImmediately() {
        guard let activity else { return }
        let current = activity
        self.activity = nil
        activityTrainingID = nil
        lastSignature = ""
        Task {
            await current.end(nil, dismissalPolicy: .immediate)
        }
    }

    // MARK: - Private

    private func push(_ state: TrainingActivityAttributes.ContentState,
                      to activity: Activity<TrainingActivityAttributes>,
                      force: Bool) {
        Task {
            await activity.update(ActivityContent(state: state, staleDate: staleDate(for: state)))
        }
    }

    /// Structural fingerprint. Deliberately excludes `remainingText` and
    /// `endDate`: both change every tick and would turn a calm countdown into
    /// a one-update-per-second repaint. Progress is bucketed so the rail
    /// advances in visible steps instead of on every tick.
    /// If the app is killed mid-session the card stops ticking; telling the
    /// system when the current block was due lets it mark the card outdated
    /// instead of presenting a frozen clock as if it were live.
    private func staleDate(for state: TrainingActivityAttributes.ContentState) -> Date? {
        guard !state.isPaused, !state.isComplete else { return nil }
        return state.endDate
    }

    private func signature(of state: TrainingActivityAttributes.ContentState) -> String {
        let progressBucket = Int((state.progress * 10).rounded(.down))
        return [
            state.phaseLabel,
            state.stepLabel,
            state.detailLabel,
            state.statusLabel,
            state.accentHex,
            String(progressBucket),
            state.isPaused ? "p" : "r",
            state.isComplete ? "c" : "a"
        ].joined(separator: "|")
    }

    // MARK: - Lifecycle observers & orphan sweep

    private func registerLifecycleObservers() {
        let center = NotificationCenter.default
        willTerminateObserver = center.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self else { return }
            MainActor.assumeIsolated { self.endAllImmediately() }
        }
    }

    /// On launch, close any activity that survived a previous process death
    /// (swipe-to-kill, crash, jetsam). The in-memory `activity` reference is
    /// gone after a relaunch, so we enumerate the system registry directly.
    private func sweepOrphanedActivities() async {
        let activities = Activity<TrainingActivityAttributes>.activities
        guard !activities.isEmpty else { return }
        log.notice("sweeping \(activities.count, privacy: .public) orphaned activity(ies)")
        for activity in activities {
            switch activity.activityState {
            case .active, .stale, .pending:
                await activity.end(nil, dismissalPolicy: .immediate)
            case .ended, .dismissed:
                break
            @unknown default:
                break
            }
        }
    }
}
