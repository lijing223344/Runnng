import Foundation
import Combine

/// Lightweight storage for Watch-local data.
class WatchStorageManager: ObservableObject {
    static let shared = WatchStorageManager()

    @Published var trainingRecords: [TrainingRecord] = []

    private let recordsKey = "watch_training_records"

    private init() {
        loadRecords()
    }

    // MARK: - Training Records

    func loadRecords() {
        guard let data = UserDefaults.standard.data(forKey: recordsKey),
              let records = try? JSONDecoder().decode([TrainingRecord].self, from: data) else {
            trainingRecords = []
            return
        }
        trainingRecords = records
    }

    func saveRecord(_ record: TrainingRecord) {
        trainingRecords.insert(record, at: 0)
        persistRecords()
        // Also send to iPhone
        WatchConnectivityManager.shared.sendTrainingRecord(record)
    }

    private func persistRecords() {
        guard let data = try? JSONEncoder().encode(trainingRecords) else { return }
        UserDefaults.standard.set(data, forKey: recordsKey)
    }
}
