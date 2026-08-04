import SwiftUI
import HealthKit

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
                .onAppear { requestHealthKitAuth() }
        }
    }

    private func requestHealthKitAuth() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let store = HKHealthStore()
        let types: Set<HKSampleType> = [
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!
        ]
        store.requestAuthorization(toShare: types, read: types) { _, _ in }
    }
}
