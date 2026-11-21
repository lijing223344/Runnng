import SwiftUI
import WatchConnectivity

@main
struct RunningApp: App {
    @StateObject private var localization = LocalizationManager.shared
    @StateObject private var storage = StorageManager.shared
    @StateObject private var soundManager = SoundManager.shared
    @StateObject private var phoneConnectivity = PhoneConnectivityManager.shared

    init() {
        if ProcessInfo.processInfo.arguments.contains("-ui_testing_reset") {
            StorageManager.shared.resetForUITests()
        }
        StorageManager.shared.seedMiniHurdleProfilesForUITestsIfNeeded()
        // Touch the Live Activity manager at launch so its orphan sweep runs
        // immediately — a card left behind by a killed process must not wait
        // for the user to open a training screen to be cleaned up.
        _ = TrainingLiveActivityManager.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(localization)
                .environmentObject(storage)
                .environmentObject(soundManager)
                .environment(\.locale, localization.locale)
                .preferredColorScheme(.dark)
                .onAppear {
                    storage.loadUser()
                    storage.migrateLegacySoundCuesIfNeeded()
                    let settings = storage.loadSettings()
                    localization.synchronizeWithSettingsLanguage(settings.language)
                    soundManager.setVolume(settings.soundConfig.volume)
                    soundManager.setVibrationEnabled(settings.soundConfig.vibrationEnabled)
                }
        }
    }
}
