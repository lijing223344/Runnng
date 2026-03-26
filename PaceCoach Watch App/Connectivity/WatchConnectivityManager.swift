import Foundation
import WatchConnectivity
import Combine

/// Manages Watch Connectivity on the watchOS side.
/// Receives plans from iPhone, sends training records back.
class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()

    @Published var receivedPlans: [SavedPlan] = []
    @Published var isReachable: Bool = false

    private override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
        loadLocalPlans()
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

    // MARK: - Send Training Record to iPhone

    func sendTrainingRecord(_ record: TrainingRecord) {
        guard WCSession.default.activationState == .activated else { return }
        guard let data = try? JSONEncoder().encode(record) else { return }
        let message: [String: Any] = [
            "type": "training_record",
            "data": data
        ]
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil)
        } else {
            WCSession.default.transferUserInfo(message)
        }
    }

    // MARK: - Request Plans from iPhone

    func requestPlansSync() {
        guard WCSession.default.activationState == .activated,
              WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(
            ["type": "request_plans"],
            replyHandler: { [weak self] reply in
                guard let data = reply["plans"] as? Data,
                      let plans = try? JSONDecoder().decode([SavedPlan].self, from: data) else { return }
                DispatchQueue.main.async {
                    self?.receivedPlans = plans
                    self?.saveLocalPlans()
                }
            }
        )
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
        if activationState == .activated {
            requestPlansSync()
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
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
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        handleReceivedMessage(applicationContext)
    }

    private func handleReceivedMessage(_ message: [String: Any]) {
        guard let type = message["type"] as? String else { return }

        switch type {
        case "sync_plans":
            guard let data = message["plans"] as? Data,
                  let plans = try? JSONDecoder().decode([SavedPlan].self, from: data) else { return }
            DispatchQueue.main.async {
                self.receivedPlans = plans
                self.saveLocalPlans()
            }

        case "sync_language":
            if let lang = message["language"] as? String {
                UserDefaults.standard.set(lang, forKey: "app_language")
                WatchLocalizationManager.shared.refresh()
            }

        default:
            break
        }
    }
}
