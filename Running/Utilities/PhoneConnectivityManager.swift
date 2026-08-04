import Foundation
import WatchConnectivity
import Combine

/// Manages Watch Connectivity on the iPhone side.
/// Sends plans to Watch, receives training records back.
class PhoneConnectivityManager: NSObject, ObservableObject {
    static let shared = PhoneConnectivityManager()

    @Published var isWatchReachable: Bool = false
    @Published var isPaired: Bool = false

    private override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }

    // MARK: - Unified Application Context (P0 fix)

    /// Builds a merged applicationContext containing all sync data,
    /// so that a single updateApplicationContext call carries everything.
    private func sendUnifiedApplicationContext() {
        guard WCSession.default.activationState == .activated else { return }
        let context = WatchSyncPayloadBuilder.makeContext(
            plans: StorageManager.shared.loadPlans(),
            settings: StorageManager.shared.loadSettings()
        )

        try? WCSession.default.updateApplicationContext(context)
    }

    // MARK: - Send Plans to Watch

    func syncPlansToWatch() {
        guard WCSession.default.activationState == .activated else { return }
        let plans = StorageManager.shared.loadPlans()
        guard let data = try? JSONEncoder().encode(plans) else { return }

        // Always update applicationContext so Watch can read it even when not reachable
        sendUnifiedApplicationContext()

        // Also try direct message for immediate delivery
        if WCSession.default.isReachable {
            let message: [String: Any] = [
                "type": "sync_plans",
                "plans": data
            ]
            WCSession.default.sendMessage(message, replyHandler: nil, errorHandler: nil)
        }
    }

    /// Sync language preference to Watch
    func syncLanguageToWatch(_ language: String) {
        guard WCSession.default.activationState == .activated else { return }
        let message: [String: Any] = [
            "type": "sync_language",
            "language": language
        ]
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil) { [weak self] _ in
                self?.sendUnifiedApplicationContext()
            }
        } else {
            sendUnifiedApplicationContext()
        }
    }

    /// Sync vibration preference to Watch
    func syncVibrationToWatch(_ enabled: Bool) {
        guard WCSession.default.activationState == .activated else { return }
        let message: [String: Any] = [
            "type": "sync_vibration",
            "vibrationEnabled": enabled
        ]
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil) { [weak self] _ in
                self?.sendUnifiedApplicationContext()
            }
        } else {
            sendUnifiedApplicationContext()
        }
    }

    /// Sync sound volume preference to Watch
    func syncSoundVolumeToWatch(_ volume: Float) {
        guard WCSession.default.activationState == .activated else { return }
        let message: [String: Any] = [
            "type": "sync_sound_volume",
            "soundVolume": volume
        ]
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil) { [weak self] _ in
                self?.sendUnifiedApplicationContext()
            }
        } else {
            sendUnifiedApplicationContext()
        }
    }
}

// MARK: - WCSessionDelegate

extension PhoneConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isWatchReachable = session.isReachable
            self.isPaired = session.isPaired
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchReachable = session.isReachable
        }
        if session.isReachable {
            syncPlansToWatch()
        }
    }

    // Handle requests from Watch
    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        guard let type = message["type"] as? String else {
            replyHandler(["error": "unknown"])
            return
        }

        switch type {
        case "request_plans":
            let plans = StorageManager.shared.loadPlans()
            if let data = try? JSONEncoder().encode(plans) {
                replyHandler(["plans": data])
            } else {
                replyHandler(["error": "encode_failed"])
            }
        default:
            replyHandler(["status": "ok"])
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleReceivedMessage(message)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        handleReceivedMessage(userInfo)
    }

    private func handleReceivedMessage(_ message: [String: Any]) {
        guard let type = message["type"] as? String else { return }

        switch type {
        case "training_record":
            guard let data = message["data"] as? Data,
                  let record = try? JSONDecoder().decode(TrainingRecord.self, from: data) else { return }
            DispatchQueue.main.async {
                var records = StorageManager.shared.loadTrainingRecords()
                // P2 fix: deduplicate by record id
                guard !records.contains(where: { $0.id == record.id }) else { return }
                records.insert(record, at: 0)
                StorageManager.shared.saveTrainingRecords(records)
            }

        case "plan_used":
            guard let idString = message["planId"] as? String,
                  let planId = UUID(uuidString: idString) else { return }
            DispatchQueue.main.async {
                var plans = StorageManager.shared.loadPlans()
                if let idx = plans.firstIndex(where: { $0.id == planId }) {
                    plans[idx].lastUsedAt = Date()
                    StorageManager.shared.savePlans(plans)
                }
            }

        default:
            break
        }
    }
}
