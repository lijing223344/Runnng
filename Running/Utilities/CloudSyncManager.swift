import Foundation
import Combine

// MARK: - iCloud Key-Value Sync Manager

/// Mirrors selected UserDefaults keys to NSUbiquitousKeyValueStore for cross-device sync.
/// Requires the iCloud Key-value storage capability to be enabled in Xcode.
final class CloudSyncManager: ObservableObject {
    static let shared = CloudSyncManager()

    enum SyncStatus: String {
        case idle, syncing, synced, offline
    }

    @Published var syncStatus: SyncStatus = .idle

    private let cloud = NSUbiquitousKeyValueStore.default
    private let defaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()

    /// Base keys that should be mirrored between UserDefaults and iCloud KVS.
    /// A logged-in user will use namespaced keys such as `saved_plans::<user-id>`.
    private let syncedBaseKeys: [String] = [
        "saved_plans",
        "training_records",
        "user_settings",
        "pace_run_training",
        "interval_training_single"
    ]

    private init() {
        observeRemoteChanges()
    }

    // MARK: - Public API

    /// Pull latest data from iCloud and merge into UserDefaults. Call once on app launch.
    func initialSync() {
        syncStatus = .syncing
        cloud.synchronize()
        let keys = cloud.dictionaryRepresentation.keys.filter { isSyncedKey($0) }
        for key in keys {
            mergeRemoteToLocal(key: key)
        }
        syncStatus = .synced
    }

    /// Push a single key's data to iCloud KVS. Call after every local save.
    func push(key: String, data: Data?) {
        guard isSyncedKey(key) else { return }
        cloud.set(data, forKey: key)
        cloud.synchronize()
        syncStatus = .synced
    }

    /// Push raw value (non-Data) to iCloud KVS.
    func pushValue(key: String, value: Any?) {
        guard isSyncedKey(key) else { return }
        cloud.set(value, forKey: key)
        cloud.synchronize()
    }

    /// Remove one mirrored key from iCloud KVS.
    func remove(key: String) {
        guard isSyncedKey(key) else { return }
        cloud.removeObject(forKey: key)
        cloud.synchronize()
    }

    // MARK: - Remote Change Observation

    private func observeRemoteChanges() {
        NotificationCenter.default.publisher(
            for: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: cloud
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] notification in
            self?.handleRemoteChange(notification)
        }
        .store(in: &cancellables)
    }

    private func handleRemoteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reason = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int else {
            return
        }

        let changedKeys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] ?? []

        switch reason {
        case NSUbiquitousKeyValueStoreServerChange,
             NSUbiquitousKeyValueStoreInitialSyncChange:
            syncStatus = .syncing
            for key in changedKeys where isSyncedKey(key) {
                mergeRemoteToLocal(key: key)
            }
            syncStatus = .synced
            // Notify StorageManager to reload
            NotificationCenter.default.post(name: .cloudDataDidChange, object: nil, userInfo: ["keys": changedKeys])

        case NSUbiquitousKeyValueStoreQuotaViolationChange:
            print("[CloudSync] ⚠️ iCloud KVS quota exceeded")
            syncStatus = .offline

        case NSUbiquitousKeyValueStoreAccountChange:
            // iCloud account changed — re-sync everything
            initialSync()

        default:
            break
        }
    }

    // MARK: - Merge Logic

    /// Merge strategy: for array-based data (plans, records), merge by ID with newer-wins.
    /// For single-value data (settings, training config), remote wins if it exists.
    private func mergeRemoteToLocal(key: String) {
        guard let remoteData = cloud.data(forKey: key) else { return }
        let baseKey = baseKey(for: key)

        switch baseKey {
        case "saved_plans":
            mergePlans(remoteData: remoteData, localKey: key)
        case "training_records":
            mergeRecords(remoteData: remoteData, localKey: key)
        default:
            // For settings and single training configs, remote overwrites local
            defaults.set(remoteData, forKey: key)
        }
    }

    private func mergePlans(remoteData: Data, localKey: String) {
        let decoder = JSONDecoder()
        let encoder = JSONEncoder()

        guard let remotePlans = try? decoder.decode([SavedPlan].self, from: remoteData) else { return }

        var localPlans: [SavedPlan] = []
        if let localData = defaults.data(forKey: localKey) {
            localPlans = (try? decoder.decode([SavedPlan].self, from: localData)) ?? []
        }

        // Merge: for matching IDs, keep the one with newer updatedAt
        var merged = Dictionary(uniqueKeysWithValues: localPlans.map { ($0.id, $0) })
        for remote in remotePlans {
            if let existing = merged[remote.id] {
                if remote.updatedAt > existing.updatedAt {
                    merged[remote.id] = remote
                }
            } else {
                merged[remote.id] = remote
            }
        }

        let result = Array(merged.values)
        if let data = try? encoder.encode(result) {
            defaults.set(data, forKey: localKey)
        }
    }

    private func mergeRecords(remoteData: Data, localKey: String) {
        let decoder = JSONDecoder()
        let encoder = JSONEncoder()

        guard let remoteRecords = try? decoder.decode([TrainingRecord].self, from: remoteData) else { return }

        var localRecords: [TrainingRecord] = []
        if let localData = defaults.data(forKey: localKey) {
            localRecords = (try? decoder.decode([TrainingRecord].self, from: localData)) ?? []
        }

        // Merge: union by ID (records are append-only, no conflicts)
        var existingIds = Set(localRecords.map { $0.id })
        var merged = localRecords
        for remote in remoteRecords {
            if !existingIds.contains(remote.id) {
                merged.append(remote)
                existingIds.insert(remote.id)
            }
        }

        if let data = try? encoder.encode(merged) {
            defaults.set(data, forKey: localKey)
        }
    }

    private func isSyncedKey(_ key: String) -> Bool {
        syncedBaseKeys.contains { base in
            key == base || key.hasPrefix("\(base)::")
        }
    }

    private func baseKey(for key: String) -> String {
        key.components(separatedBy: "::").first ?? key
    }
}

// MARK: - Notification Name

extension Notification.Name {
    static let cloudDataDidChange = Notification.Name("cloudDataDidChange")
}
