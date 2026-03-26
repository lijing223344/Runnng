import SwiftUI

@main
struct RunningApp: App {
    @StateObject private var localization = LocalizationManager.shared
    @StateObject private var storage = StorageManager.shared
    @StateObject private var soundManager = SoundManager.shared

    init() {
        if ProcessInfo.processInfo.arguments.contains("-ui_testing_reset") {
            StorageManager.shared.resetForUITests()
        }
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
                    let settings = storage.loadSettings()
                    localization.synchronizeWithSettingsLanguage(settings.language)
                    soundManager.setVolume(settings.soundConfig.volume)
                    soundManager.setVibrationEnabled(settings.soundConfig.vibrationEnabled)
                }
        }
    }
}
