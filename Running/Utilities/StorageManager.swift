import Foundation
import Combine

class StorageManager: ObservableObject {
    static let shared = StorageManager()
    private let defaults = UserDefaults.standard
    private let sync = CloudSyncManager.shared
    private var cancellables = Set<AnyCancellable>()

    private enum Keys {
        static let userId = "user_id"; static let user = "user"; static let settings = "user_settings"
        static let paceRunConfigs = "pace_run_configs"; static let intervalTrainings = "interval_trainings"
        static let trainingRecords = "training_records"; static let isLoggedIn = "is_logged_in"; static let isGuest = "is_guest"
        static let paceRunTraining = "pace_run_training"; static let intervalTraining = "interval_training_single"; static let savedPlans = "saved_plans"
        static let miniHurdleProfiles = "mini_hurdle_profiles"; static let selectedMiniHurdleProfileID = "selected_mini_hurdle_profile_id"
    }
    private init() {
        observeCloudChanges()
    }
    @Published var currentUser: User?
    @Published var isLoggedIn: Bool = false
    @Published var isGuest: Bool = false

    // MARK: - Cloud Change Observation

    private func observeCloudChanges() {
        NotificationCenter.default.publisher(for: .cloudDataDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    // MARK: - User

    func saveUser(_ user: User) {
        currentUser = user
        isLoggedIn = true
        isGuest = false
        if let data = try? JSONEncoder().encode(user) {
            defaults.set(data, forKey: Keys.user)
            defaults.set(user.id, forKey: Keys.userId)
            defaults.set(true, forKey: Keys.isLoggedIn)
            defaults.set(false, forKey: Keys.isGuest)
        }
        sync.initialSync()
    }

    func loadUser() {
        isLoggedIn = defaults.bool(forKey: Keys.isLoggedIn)
        isGuest = (defaults.object(forKey: Keys.isGuest) as? Bool) ?? false

        if let data = defaults.data(forKey: Keys.user),
           let user = try? JSONDecoder().decode(User.self, from: data) {
            currentUser = user
        } else {
            currentUser = nil
            if isLoggedIn {
                isLoggedIn = false
                defaults.set(false, forKey: Keys.isLoggedIn)
            }
        }

        if isLoggedIn, let userId = currentUser?.id, !userId.isEmpty {
            migrateLegacyDataIfNeeded(for: userId)
            sync.initialSync()
        }
    }

    func logout() {
        currentUser = nil
        isLoggedIn = false
        isGuest = false
        defaults.removeObject(forKey: Keys.user)
        defaults.removeObject(forKey: Keys.userId)
        defaults.set(false, forKey: Keys.isLoggedIn)
        defaults.set(false, forKey: Keys.isGuest)
    }

    /// Permanently delete current account data on this device, then log out.
    /// If the user is logged in, synced data buckets are also removed from iCloud KVS.
    func deleteCurrentAccount() {
        guard isLoggedIn, let userId = currentUser?.id, !userId.isEmpty else {
            logout()
            return
        }

        let baseKeysToDelete = [
            Keys.settings,
            Keys.paceRunConfigs,
            Keys.intervalTrainings,
            Keys.trainingRecords,
            Keys.paceRunTraining,
            Keys.intervalTraining,
            Keys.savedPlans,
            Keys.miniHurdleProfiles,
            Keys.selectedMiniHurdleProfileID
        ]

        for baseKey in baseKeysToDelete {
            let key = scopedKey(baseKey, userId: userId)
            defaults.removeObject(forKey: key)
            sync.remove(key: key)
        }

        logout()
    }

    func loginAsGuest() {
        currentUser = nil
        isGuest = true
        isLoggedIn = false
        defaults.removeObject(forKey: Keys.user)
        defaults.removeObject(forKey: Keys.userId)
        defaults.set(true, forKey: Keys.isGuest)
        defaults.set(false, forKey: Keys.isLoggedIn)
    }

    // MARK: - Settings

    func saveSettings(_ settings: UserSettings) {
        let key = scopedKey(Keys.settings)
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: key)
            if shouldSyncToCloud {
                sync.push(key: key, data: data)
            }
        }
    }

    func loadSettings() -> UserSettings {
        if let data = loadData(for: Keys.settings),
           let settings = try? JSONDecoder().decode(UserSettings.self, from: data) {
            return settings
        }
        return UserSettings()
    }

    // MARK: - Pace Run Configs (legacy)

    func savePaceRunConfigs(_ configs: [PaceRunConfig]) {
        if let data = try? JSONEncoder().encode(configs) {
            defaults.set(data, forKey: scopedKey(Keys.paceRunConfigs))
        }
    }

    func loadPaceRunConfigs() -> [PaceRunConfig] {
        if let data = loadData(for: Keys.paceRunConfigs),
           let configs = try? JSONDecoder().decode([PaceRunConfig].self, from: data) {
            return configs
        }
        return []
    }

    func addPaceRunConfig(_ config: PaceRunConfig) {
        var configs = loadPaceRunConfigs()
        configs.append(config)
        savePaceRunConfigs(configs)
    }

    func deletePaceRunConfig(_ config: PaceRunConfig) {
        var configs = loadPaceRunConfigs()
        configs.removeAll { $0.id == config.id }
        savePaceRunConfigs(configs)
    }

    // MARK: - Interval Trainings (legacy)

    func saveIntervalTrainings(_ trainings: [IntervalTraining]) {
        if let data = try? JSONEncoder().encode(trainings) {
            defaults.set(data, forKey: scopedKey(Keys.intervalTrainings))
        }
    }

    func loadIntervalTrainings() -> [IntervalTraining] {
        if let data = loadData(for: Keys.intervalTrainings),
           let trainings = try? JSONDecoder().decode([IntervalTraining].self, from: data) {
            return trainings
        }
        return []
    }

    func addIntervalTraining(_ training: IntervalTraining) {
        var trainings = loadIntervalTrainings()
        trainings.append(training)
        saveIntervalTrainings(trainings)
    }

    func deleteIntervalTraining(_ training: IntervalTraining) {
        var trainings = loadIntervalTrainings()
        trainings.removeAll { $0.id == training.id }
        saveIntervalTrainings(trainings)
    }

    // MARK: - Setup persistence (single training config for each mode)

    func savePaceRunTraining(_ training: PaceRunTraining) {
        let key = scopedKey(Keys.paceRunTraining)
        if let data = try? JSONEncoder().encode(training) {
            defaults.set(data, forKey: key)
            if shouldSyncToCloud {
                sync.push(key: key, data: data)
            }
        }
    }

    func loadPaceRunTraining() -> PaceRunTraining? {
        guard let data = loadData(for: Keys.paceRunTraining) else { return nil }
        return try? JSONDecoder().decode(PaceRunTraining.self, from: data)
    }

    func saveIntervalTrainingSingle(_ training: IntervalTraining) {
        let key = scopedKey(Keys.intervalTraining)
        if let data = try? JSONEncoder().encode(training) {
            defaults.set(data, forKey: key)
            if shouldSyncToCloud {
                sync.push(key: key, data: data)
            }
        }
    }

    func loadIntervalTrainingSingle() -> IntervalTraining? {
        guard let data = loadData(for: Keys.intervalTraining) else { return nil }
        return try? JSONDecoder().decode(IntervalTraining.self, from: data)
    }

    // MARK: - Training Records

    func saveTrainingRecords(_ records: [TrainingRecord]) {
        let key = scopedKey(Keys.trainingRecords)
        if let data = try? JSONEncoder().encode(records) {
            defaults.set(data, forKey: key)
            if shouldSyncToCloud {
                sync.push(key: key, data: data)
            }
        }
    }

    func loadTrainingRecords() -> [TrainingRecord] {
        if let data = loadData(for: Keys.trainingRecords),
           let records = try? JSONDecoder().decode([TrainingRecord].self, from: data) {
            return records.sorted { $0.createdAt > $1.createdAt }
        }
        return []
    }

    func addTrainingRecord(_ record: TrainingRecord) {
        var records = loadTrainingRecords()
        records.append(record)
        saveTrainingRecords(records)
    }

    func deleteTrainingRecord(_ record: TrainingRecord) {
        var records = loadTrainingRecords()
        records.removeAll { $0.id == record.id }
        saveTrainingRecords(records)
    }

    // MARK: - Saved Plans

    func savePlans(_ plans: [SavedPlan]) {
        let key = scopedKey(Keys.savedPlans)
        if let data = try? JSONEncoder().encode(plans) {
            defaults.set(data, forKey: key)
            if shouldSyncToCloud {
                sync.push(key: key, data: data)
            }
            // Sync plans to Watch whenever local plans change
            PhoneConnectivityManager.shared.syncPlansToWatch()
        }
    }

    func loadPlans() -> [SavedPlan] {
        if let data = loadData(for: Keys.savedPlans),
           let plans = try? JSONDecoder().decode([SavedPlan].self, from: data) {
            return plans.sorted { lhs, rhs in
                if lhs.lastUsedAt == rhs.lastUsedAt {
                    return lhs.updatedAt > rhs.updatedAt
                }
                return lhs.lastUsedAt > rhs.lastUsedAt
            }
        }
        return []
    }
    func addPlan(_ plan: SavedPlan) { var plans = loadPlans(); plans.append(plan); savePlans(plans) }
    func deletePlan(_ plan: SavedPlan) { var plans = loadPlans(); plans.removeAll { $0.id == plan.id }; savePlans(plans) }
    func updatePlan(_ plan: SavedPlan) { var plans = loadPlans(); if let idx = plans.firstIndex(where: { $0.id == plan.id }) { plans[idx] = plan }; savePlans(plans) }

    @discardableResult
    func upsertPlan(
        name: String,
        trainingType: TrainingType,
        configData: Data,
        lastUsedAt: Date = Date()
    ) -> SavedPlan {
        var plans = loadPlans()
        if let idx = plans.firstIndex(where: { $0.trainingType == trainingType && $0.configData == configData }) {
            plans[idx].name = name
            plans[idx].updatedAt = lastUsedAt
            plans[idx].lastUsedAt = lastUsedAt
            let updated = plans[idx]
            savePlans(plans)
            return updated
        }

        let newPlan = SavedPlan(
            name: name,
            trainingType: trainingType,
            configData: configData,
            createdAt: lastUsedAt,
            updatedAt: lastUsedAt,
            lastUsedAt: lastUsedAt
        )
        plans.append(newPlan)
        savePlans(plans)
        return newPlan
    }

    func touchPlanUsage(_ planId: UUID, at date: Date = Date()) {
        var plans = loadPlans()
        guard let idx = plans.firstIndex(where: { $0.id == planId }) else { return }
        plans[idx].updatedAt = max(plans[idx].updatedAt, date)
        plans[idx].lastUsedAt = date
        savePlans(plans)
    }

    // MARK: - Mini Hurdle Athlete Profiles

    func saveMiniHurdleProfiles(_ profiles: [MiniHurdleAthleteProfile]) {
        let key = scopedKey(Keys.miniHurdleProfiles)
        let sortedProfiles = sortMiniHurdleProfiles(profiles)
        if let data = try? JSONEncoder().encode(sortedProfiles) {
            defaults.set(data, forKey: key)
            if shouldSyncToCloud {
                sync.push(key: key, data: data)
            }
        }

        if let selectedID = loadSelectedMiniHurdleProfileID(),
           sortedProfiles.contains(where: { $0.id == selectedID }) == false {
            saveSelectedMiniHurdleProfileID(nil)
        }
    }

    func loadMiniHurdleProfiles() -> [MiniHurdleAthleteProfile] {
        if let data = loadData(for: Keys.miniHurdleProfiles),
           let profiles = try? JSONDecoder().decode([MiniHurdleAthleteProfile].self, from: data) {
            return sortMiniHurdleProfiles(profiles)
        }
        return []
    }

    @discardableResult
    func upsertMiniHurdleProfile(_ profile: MiniHurdleAthleteProfile) -> MiniHurdleAthleteProfile {
        var profiles = loadMiniHurdleProfiles()
        if let idx = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[idx] = profile
        } else {
            profiles.append(profile)
        }
        saveMiniHurdleProfiles(profiles)
        return profile
    }

    func deleteMiniHurdleProfile(_ profileID: UUID) {
        var profiles = loadMiniHurdleProfiles()
        profiles.removeAll { $0.id == profileID }
        saveMiniHurdleProfiles(profiles)

        if loadSelectedMiniHurdleProfileID() == profileID {
            saveSelectedMiniHurdleProfileID(nil)
        }
    }

    func saveSelectedMiniHurdleProfileID(_ profileID: UUID?) {
        let key = scopedKey(Keys.selectedMiniHurdleProfileID)
        guard let profileID else {
            defaults.removeObject(forKey: key)
            if shouldSyncToCloud {
                sync.remove(key: key)
            }
            return
        }

        if let data = try? JSONEncoder().encode(profileID) {
            defaults.set(data, forKey: key)
            if shouldSyncToCloud {
                sync.push(key: key, data: data)
            }
        }
    }

    func loadSelectedMiniHurdleProfileID() -> UUID? {
        guard let data = loadData(for: Keys.selectedMiniHurdleProfileID) else { return nil }
        return try? JSONDecoder().decode(UUID.self, from: data)
    }

    // MARK: - Reset

    func resetForUITests() {
        let keysToClear = [
            Keys.userId,
            Keys.user,
            Keys.isLoggedIn,
            Keys.isGuest,
            "app_language"
        ]
        keysToClear.forEach { defaults.removeObject(forKey: $0) }

        let scopedPrefixes = [
            "\(Keys.settings)::",
            "\(Keys.paceRunConfigs)::",
            "\(Keys.intervalTrainings)::",
            "\(Keys.trainingRecords)::",
            "\(Keys.paceRunTraining)::",
            "\(Keys.intervalTraining)::",
            "\(Keys.savedPlans)::",
            "\(Keys.miniHurdleProfiles)::",
            "\(Keys.selectedMiniHurdleProfileID)::"
        ]
        for key in defaults.dictionaryRepresentation().keys {
            if scopedPrefixes.contains(where: { key.hasPrefix($0) }) {
                defaults.removeObject(forKey: key)
            }
        }

        // Keep clearing legacy unscoped keys for backward compatibility in tests.
        defaults.removeObject(forKey: Keys.settings)
        defaults.removeObject(forKey: Keys.paceRunConfigs)
        defaults.removeObject(forKey: Keys.intervalTrainings)
        defaults.removeObject(forKey: Keys.trainingRecords)
        defaults.removeObject(forKey: Keys.paceRunTraining)
        defaults.removeObject(forKey: Keys.intervalTraining)
        defaults.removeObject(forKey: Keys.savedPlans)
        defaults.removeObject(forKey: Keys.miniHurdleProfiles)
        defaults.removeObject(forKey: Keys.selectedMiniHurdleProfileID)

        currentUser = nil
        isLoggedIn = false
        isGuest = false
    }

    func seedMiniHurdleProfilesForUITestsIfNeeded() {
        guard AppRuntimeConfiguration.miniHurdleSeedScenario() == .athleteProfiles else { return }

        let athleteAID = UUID(uuidString: "11111111-1111-1111-1111-111111111111") ?? UUID()
        let athleteBID = UUID(uuidString: "22222222-2222-2222-2222-222222222222") ?? UUID()
        let baseDate = Date(timeIntervalSince1970: 1_700_000_000)
        let profiles = [
            MiniHurdleAthleteProfile(
                id: athleteAID,
                name: "AthleteA",
                profile: .women,
                greaterTrochanterLength: 0.86,
                measurementUnit: .centimeters,
                strategyKind: .mannRecommended,
                customRatio: nil,
                updatedAt: baseDate,
                lastUsedAt: baseDate.addingTimeInterval(60)
            ),
            MiniHurdleAthleteProfile(
                id: athleteBID,
                name: "AthleteB",
                profile: .men,
                greaterTrochanterLength: 0.92,
                measurementUnit: .centimeters,
                strategyKind: .clarkRange,
                customRatio: nil,
                updatedAt: baseDate.addingTimeInterval(30),
                lastUsedAt: baseDate.addingTimeInterval(120)
            )
        ]

        saveMiniHurdleProfiles(profiles)
        saveSelectedMiniHurdleProfileID(athleteBID)
    }

    // MARK: - Internal Helpers

    private var shouldSyncToCloud: Bool {
        isLoggedIn && currentUser != nil
    }

    private func scopedKey(_ baseKey: String, userId: String? = nil) -> String {
        let resolvedUserId = userId ?? currentUser?.id
        guard let resolvedUserId, !resolvedUserId.isEmpty else {
            return baseKey
        }
        return "\(baseKey)::\(resolvedUserId)"
    }

    private func loadData(for baseKey: String) -> Data? {
        if shouldUseScopedStorage {
            return defaults.data(forKey: scopedKey(baseKey))
        }
        return defaults.data(forKey: baseKey)
    }

    private var shouldUseScopedStorage: Bool {
        guard isLoggedIn, let user = currentUser else { return false }
        return !user.id.isEmpty
    }

    private func migrateLegacyDataIfNeeded(for userId: String) {
        let baseKeys = [
            Keys.settings,
            Keys.paceRunConfigs,
            Keys.intervalTrainings,
            Keys.trainingRecords,
            Keys.paceRunTraining,
            Keys.intervalTraining,
            Keys.savedPlans,
            Keys.miniHurdleProfiles,
            Keys.selectedMiniHurdleProfileID
        ]

        for baseKey in baseKeys {
            let destinationKey = scopedKey(baseKey, userId: userId)
            if defaults.object(forKey: destinationKey) == nil,
               let legacyObject = defaults.object(forKey: baseKey) {
                defaults.set(legacyObject, forKey: destinationKey)
            }
        }
    }

    private func sortMiniHurdleProfiles(_ profiles: [MiniHurdleAthleteProfile]) -> [MiniHurdleAthleteProfile] {
        profiles.sorted { lhs, rhs in
            if lhs.lastUsedAt == rhs.lastUsedAt {
                if lhs.updatedAt == rhs.updatedAt {
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
                return lhs.updatedAt > rhs.updatedAt
            }
            return lhs.lastUsedAt > rhs.lastUsedAt
        }
    }
}
