import SwiftUI

@main
struct RunningWatchApp: App {
    @StateObject private var connectivityManager = WatchConnectivityManager.shared
    @StateObject private var watchStorage = WatchStorageManager.shared

    var body: some Scene {
        WindowGroup {
            WatchHomeView()
                .environmentObject(connectivityManager)
                .environmentObject(watchStorage)
                .preferredColorScheme(.dark)
        }
    }
}
