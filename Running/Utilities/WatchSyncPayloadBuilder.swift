import Foundation

enum WatchSyncPayloadBuilder {
    static func makeContext(plans: [SavedPlan], settings: UserSettings) -> [String: Any] {
        var context: [String: Any] = [:]

        if let plansData = try? JSONEncoder().encode(plans) {
            context["plans"] = plansData
        }

        context["language"] = settings.language
        context["vibrationEnabled"] = settings.soundConfig.vibrationEnabled
        context["soundVolume"] = settings.soundConfig.volume

        return context
    }
}
