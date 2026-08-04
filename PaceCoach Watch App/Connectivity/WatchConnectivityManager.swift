import Foundation
import WatchConnectivity
import Combine

/// Manages Watch Connectivity on the watchOS side.
/// Receives plans from iPhone, sends training records back.
class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()

    @Published var receivedPlans: [SavedPlan] = []
    @Published var isReachable: Bool = false

    /// P3: Queue of records that failed to send to iPhone
    private var pendingRecords: [TrainingRecord] = []
    private let pendingKey = "watch_pending_records"
    private let pendingQueue = DispatchQueue(label: "com.pacecoach.pending-records")

    private override init() {
        super.init()
        loadPendingRecords()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
        loadLocalPlans()
        #if DEBUG
        injectSamplePlansIfEmpty()
        #endif
    }

    // MARK: - Local Storage

    private let plansKey = "watch_saved_plans"

    private func loadLocalPlans() {
        guard let data = UserDefaults.standard.data(forKey: plansKey),
              let plans = try? JSONDecoder().decode([SavedPlan].self, from: data) else {
            return
        }
        receivedPlans = plans
    }

    private func saveLocalPlans() {
        guard let data = try? JSONEncoder().encode(receivedPlans) else { return }
        UserDefaults.standard.set(data, forKey: plansKey)
    }

    // MARK: - Pending Records Queue (P3)

    private func loadPendingRecords() {
        guard let data = UserDefaults.standard.data(forKey: pendingKey),
              let records = try? JSONDecoder().decode([TrainingRecord].self, from: data) else { return }
        pendingRecords = records
    }

    private func savePendingRecords() {
        guard let data = try? JSONEncoder().encode(pendingRecords) else { return }
        UserDefaults.standard.set(data, forKey: pendingKey)
    }

    private func addPendingRecord(_ record: TrainingRecord) {
        pendingQueue.async { [weak self] in
            guard let self else { return }
            guard !self.pendingRecords.contains(where: { $0.id == record.id }) else { return }
            self.pendingRecords.append(record)
            self.savePendingRecords()
        }
    }

    private func removePendingRecord(_ record: TrainingRecord) {
        pendingQueue.async { [weak self] in
            guard let self else { return }
            self.pendingRecords.removeAll { $0.id == record.id }
            self.savePendingRecords()
        }
    }

    /// Retry sending all pending records when iPhone becomes reachable
    private func flushPendingRecords() {
        pendingQueue.async { [weak self] in
            guard let self else { return }
            let records = self.pendingRecords
            guard !records.isEmpty else { return }
            // Clear queue first to prevent re-entrancy duplicates
            self.pendingRecords = []
            self.savePendingRecords()
            for record in records {
                self.sendTrainingRecord(record)
            }
        }
    }

    // MARK: - Send Training Record to iPhone

    func sendTrainingRecord(_ record: TrainingRecord) {
        guard WCSession.default.activationState == .activated else {
            addPendingRecord(record)
            return
        }
        guard let data = try? JSONEncoder().encode(record) else { return }
        let message: [String: Any] = [
            "type": "training_record",
            "data": data
        ]
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: { [weak self] _ in
                // Sent successfully, remove from pending if present
                self?.removePendingRecord(record)
            }) { [weak self] _ in
                // P1 fix: sendMessage failed, fall back to transferUserInfo
                WCSession.default.transferUserInfo(message)
                self?.removePendingRecord(record)
            }
        } else {
            // Not reachable — queue via transferUserInfo (guaranteed delivery)
            WCSession.default.transferUserInfo(message)
            removePendingRecord(record)
        }
    }

    // MARK: - Notify Plan Used

    func notifyPlanUsed(planId: UUID) {
        guard WCSession.default.activationState == .activated else { return }
        let message: [String: Any] = [
            "type": "plan_used",
            "planId": planId.uuidString
        ]
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil) { _ in
                // sendMessage failed — fall back to guaranteed delivery
                WCSession.default.transferUserInfo(message)
            }
        } else {
            WCSession.default.transferUserInfo(message)
        }
        // Also update local cache
        if let idx = receivedPlans.firstIndex(where: { $0.id == planId }) {
            receivedPlans[idx].lastUsedAt = Date()
            saveLocalPlans()
        }
    }

    // MARK: - Request Plans from iPhone

    func requestPlansSync() {
        guard WCSession.default.activationState == .activated else { return }

        if WCSession.default.isReachable {
            // Interactive request — iPhone replies with plans immediately
            WCSession.default.sendMessage(
                ["type": "request_plans"],
                replyHandler: { [weak self] reply in
                    guard let data = reply["plans"] as? Data,
                          let plans = try? JSONDecoder().decode([SavedPlan].self, from: data) else { return }
                    DispatchQueue.main.async {
                        self?.receivedPlans = plans
                        self?.saveLocalPlans()
                    }
                },
                errorHandler: { [weak self] _ in
                    // 交互请求失败（如手机端 App 未运行）——回退到 applicationContext 兜底刷新
                    guard let self else { return }
                    let context = WCSession.default.receivedApplicationContext
                    if !context.isEmpty {
                        self.handleUnifiedContext(context)
                    }
                }
            )
        } else {
            // Not reachable — check if applicationContext has plans we haven't applied yet
            let context = WCSession.default.receivedApplicationContext
            if !context.isEmpty {
                handleUnifiedContext(context)
            }
        }
    }
    // MARK: - Debug Sample Data

    #if DEBUG
    private func injectSamplePlansIfEmpty() {
        guard receivedPlans.isEmpty else { return }

        // Sample pace run group
        let paceGroup = PaceRunGroup(
            name: "800m 节奏跑",
            colorHex: "#3357FF",
            totalDistance: 800,
            segmentDistance: 200,
            totalTime: 240.0,
            countdownSeconds: 3,
            segmentSound: .whistleShort,
            startSound: .whistleStandard,
            endSound: .whistleShort,
            sortOrder: 0
        )
        let paceTraining = PaceRunTraining(
            name: "800m 节奏跑",
            groups: [paceGroup],
            countdownSeconds: 3
        )

        // Sample interval group
        let intervalGroup = IntervalGroup(
            name: "200m 间歇",
            colorHex: "#FF8C33",
            runDistance: 200,
            runTime: 40,
            restTime: 60,
            repetitions: 6,
            startSound: .whistleStandard,
            restSound: .whistleShort,
            endSound: .whistleShort,
            sortOrder: 0
        )
        let intervalTraining = IntervalTraining(
            name: "200m×6 间歇训练",
            groups: [intervalGroup],
            countdownSeconds: 3
        )

        // Encode as SavedPlans
        var plans: [SavedPlan] = []
        if let paceData = try? JSONEncoder().encode(paceTraining) {
            plans.append(SavedPlan(
                name: "800m 节奏跑",
                trainingType: .paceRun,
                configData: paceData
            ))
        }
        if let intervalData = try? JSONEncoder().encode(intervalTraining) {
            plans.append(SavedPlan(
                name: "200m×6 间歇训练",
                trainingType: .intervalTraining,
                configData: intervalData
            ))
        }

        receivedPlans = plans
        saveLocalPlans()
    }
    #endif
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
        if activationState == .activated {
            // Try interactive sync first
            requestPlansSync()
            flushPendingRecords()

            // Also apply any pending applicationContext (works even if not reachable)
            let context = session.receivedApplicationContext
            if !context.isEmpty {
                handleUnifiedContext(context)
            }
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
        // P3: retry pending records when iPhone becomes reachable
        if session.isReachable {
            flushPendingRecords()
        }
    }

    // Receive plans pushed from iPhone
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleReceivedMessage(message)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        handleReceivedMessage(message)
        replyHandler(["status": "ok"])
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        handleReceivedMessage(userInfo)
    }

    // Handle application context updates (background sync)
    // P0 fix: unified context now carries both plans + language in one dict
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        handleUnifiedContext(applicationContext)
    }

    /// Handle per-type messages from sendMessage / transferUserInfo
    private func handleReceivedMessage(_ message: [String: Any]) {
        guard let type = message["type"] as? String else {
            // No "type" key — could be unified context via sendMessage fallback
            handleUnifiedContext(message)
            return
        }

        switch type {
        case "sync_plans":
            applyPlans(from: message)
        case "sync_language":
            applyLanguage(from: message)
        case "sync_vibration":
            applyVibration(from: message)
        case "sync_sound_volume":
            applySoundVolume(from: message)
        default:
            break
        }
    }

    /// Handle merged applicationContext that has no "type" key,
    /// but may contain "plans" and/or "language" simultaneously.
    private func handleUnifiedContext(_ context: [String: Any]) {
        if context["plans"] != nil {
            applyPlans(from: context)
        }
        if context["language"] != nil {
            applyLanguage(from: context)
        }
        if context["vibrationEnabled"] != nil {
            applyVibration(from: context)
        }
        if context["soundVolume"] != nil {
            applySoundVolume(from: context)
        }
    }

    private func applyPlans(from message: [String: Any]) {
        guard let data = message["plans"] as? Data,
              let plans = try? JSONDecoder().decode([SavedPlan].self, from: data) else { return }
        DispatchQueue.main.async {
            self.receivedPlans = plans
            self.saveLocalPlans()
        }
    }

    private func applyLanguage(from message: [String: Any]) {
        if let lang = message["language"] as? String {
            DispatchQueue.main.async {
                UserDefaults.standard.set(lang, forKey: "app_language")
                WatchLocalizationManager.shared.refresh()
            }
        }
    }

    private func applyVibration(from message: [String: Any]) {
        if let enabled = message["vibrationEnabled"] as? Bool {
            DispatchQueue.main.async {
                WatchHapticManager.shared.isEnabled = enabled
            }
        }
    }

    private func applySoundVolume(from message: [String: Any]) {
        if let volume = message["soundVolume"] as? Float {
            DispatchQueue.main.async {
                WatchSoundManager.shared.setVolume(volume)
            }
        } else if let volume = message["soundVolume"] as? Double {
            DispatchQueue.main.async {
                WatchSoundManager.shared.setVolume(Float(volume))
            }
        }
    }
}
