import Foundation
import WatchConnectivity

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

    // MARK: - Send Plans to Watch

    func syncPlansToWatch() {
        guard WCSession.default.activationState == .activated else { return }
        let plans = StorageManager.shared.loadPlans()
        guard let data = try? JSONEncoder().encode(plans) else { return }

        let message: [String: Any] = [
            "type": "sync_plans",
            "plans": data
        ]

        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil)
        } else {
            // Use application context for background delivery
            try? WCSession.default.updateApplicationContext(message)
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
            WCSession.default.sendMessage(message, replyHandler: nil)
        } else {
            try? WCSession.default.updateApplicationContext(message)
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
        // Re-activate for phone switching
        WCSession.default.activate()
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchReachable = session.isReachable
        }
        // Auto-sync plans when Watch becomes reachable
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
                records.insert(record, at: 0)
                StorageManager.shared.saveTrainingRecords(records)
            }

        default:
            break
        }
    }
}
