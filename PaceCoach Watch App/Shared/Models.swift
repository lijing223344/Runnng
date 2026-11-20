// ⚠️ Mirror of Running/Models/Models.swift — keep in sync when modifying data models.
import Foundation

// MARK: - SoundConfig
struct SoundConfig: Codable {
    var volume: Float
    var vibrationEnabled: Bool

    init(volume: Float = 1.0, vibrationEnabled: Bool = true) {
        self.volume = volume
        self.vibrationEnabled = vibrationEnabled
    }

    private enum CodingKeys: String, CodingKey {
        case volume, vibrationEnabled
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.volume = try c.decodeIfPresent(Float.self, forKey: .volume) ?? 1.0
        self.vibrationEnabled = try c.decodeIfPresent(Bool.self, forKey: .vibrationEnabled) ?? true
    }
}

enum TrainingType: String, Codable, CaseIterable {
    case paceRun = "pace_run"
    case intervalTraining = "interval_training"
}

struct User: Codable, Identifiable {
    var id: String
    var appleId: String?
    var nickname: String
    var language: String
    var createdAt: Date
    init(id: String = UUID().uuidString, appleId: String? = nil, nickname: String = "", language: String = "zh-Hans", createdAt: Date = Date()) {
        self.id = id; self.appleId = appleId; self.nickname = nickname; self.language = language; self.createdAt = createdAt
    }
}

// MARK: - Custom Segment (per-segment distance + time)

struct CustomSegment: Codable, Identifiable {
    var id: UUID
    var distance: Int      // meters
    var time: Double       // seconds
    var restAfter: Double  // seconds, rest after this segment (ignored for last segment)

    init(id: UUID = UUID(), distance: Int = 100, time: Double = 30.0, restAfter: Double = 0.0) {
        self.id = id
        self.distance = distance
        self.time = time
        self.restAfter = restAfter
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case distance
        case time
        case restAfter
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.distance = try c.decodeIfPresent(Int.self, forKey: .distance) ?? 100
        self.time = try c.decodeIfPresent(Double.self, forKey: .time) ?? 30.0
        self.restAfter = try c.decodeIfPresent(Double.self, forKey: .restAfter) ?? 0.0
    }
}

// MARK: - Pace Run Models

struct PaceRunGroup: Codable, Identifiable {
    static var defaultName: String { "default_group_name".localized }
    var id: UUID
    var name: String
    var colorHex: String
    var totalDistance: Int
    var segmentDistance: Int
    var totalTime: Double
    var segmentTime: Double
    var countdownSeconds: Int
    var setCount: Int?
    var setRestTime: Double?
    var segmentSound: SoundType
    var startSound: SoundType
    var endSound: SoundType
    var sortOrder: Int
    var customSegments: [CustomSegment]?  // nil = uniform mode
    var intensityPercent: Double

    init(
        id: UUID = UUID(),
        name: String = PaceRunGroup.defaultName,
        colorHex: String = "#FF5733",
        totalDistance: Int = 800,
        segmentDistance: Int = 50,
        totalTime: Double = 240.0,
        countdownSeconds: Int = 3,
        setCount: Int? = nil,
        setRestTime: Double? = nil,
        segmentSound: SoundType = .splitTick,
        startSound: SoundType = .startTriad,
        endSound: SoundType = .finishArpeggio,
        sortOrder: Int = 0,
        customSegments: [CustomSegment]? = nil,
        intensityPercent: Double = 100
    ) {
        let uniformCount = max(1, Int(ceil(Double(totalDistance) / Double(max(1, segmentDistance)))))
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.totalDistance = totalDistance
        self.segmentDistance = segmentDistance
        self.totalTime = totalTime
        self.segmentTime = max(0.1, totalTime / Double(uniformCount))
        self.countdownSeconds = countdownSeconds
        self.setCount = setCount
        self.setRestTime = setRestTime
        self.segmentSound = segmentSound
        self.startSound = startSound
        self.endSound = endSound
        self.sortOrder = sortOrder
        self.customSegments = customSegments
        self.intensityPercent = intensityPercent
    }

    var segmentCount: Int {
        if let cs = customSegments, !cs.isEmpty { return cs.count }
        return max(1, Int(ceil(Double(totalDistance) / Double(max(1, segmentDistance)))))
    }

    var isCustomMode: Bool { customSegments != nil && !(customSegments!.isEmpty) }
    var effectiveSetCount: Int { max(1, setCount ?? 1) }
    var effectiveSetRest: Double { max(0, setRestTime ?? 0) }

    /// Get time for segment at index (works for both modes)
    func timeForSegment(_ index: Int) -> Double {
        if let cs = customSegments, index < cs.count { return cs[index].time }
        return segmentTime
    }

    /// Rest after segment at index. In uniform mode, default to 0.
    func restAfterSegment(_ index: Int) -> Double {
        if let cs = customSegments, index < cs.count { return max(0, cs[index].restAfter) }
        return 0
    }

    /// Total planned workout duration including custom rests between segments.
    func totalPlannedDuration() -> Double {
        let sets = effectiveSetCount
        let setRest = effectiveSetRest

        let singleSet: Double
        if let cs = customSegments, !cs.isEmpty {
            var total = 0.0
            for i in cs.indices {
                total += max(0, cs[i].time)
                if i < cs.count - 1 {
                    total += max(0, cs[i].restAfter)
                }
            }
            singleSet = total
        } else {
            singleSet = max(0, totalTime)
        }
        return singleSet * Double(sets) + setRest * Double(max(0, sets - 1))
    }

    /// Get distance for segment at index
    func distanceForSegment(_ index: Int) -> Double {
        if let cs = customSegments, index < cs.count { return Double(cs[index].distance) }
        return Double(segmentDistance)
    }

    /// Cumulative distance markers at each segment boundary.
    /// Result always starts with 0 and has `segmentCount + 1` elements.
    func cumulativeDistanceMarkers() -> [Int] {
        var markers: [Int] = [0]

        if let cs = customSegments, !cs.isEmpty {
            var sum = 0
            for seg in cs {
                sum += max(0, seg.distance)
                markers.append(sum)
            }
            return markers
        }

        let count = segmentCount
        let step = max(1, segmentDistance)
        var covered = 0
        for idx in 0..<count {
            if idx == count - 1 {
                // Last segment takes the remainder so end marker equals totalDistance.
                covered = max(0, totalDistance)
            } else {
                let next = covered + step
                covered = min(max(0, totalDistance), next)
            }
            markers.append(covered)
        }
        return markers
    }

    /// Per-segment distance values.
    /// The sum is expected to match the last cumulative distance marker.
    func segmentDistanceValues() -> [Int] {
        let markers = cumulativeDistanceMarkers()
        guard markers.count >= 2 else {
            return Array(repeating: max(1, segmentDistance), count: max(1, segmentCount))
        }
        var values: [Int] = []
        values.reserveCapacity(max(0, markers.count - 1))
        for idx in 1..<markers.count {
            values.append(max(0, markers[idx] - markers[idx - 1]))
        }
        return values
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case colorHex
        case totalDistance
        case segmentDistance
        case totalTime
        case segmentTime
        case countdownSeconds
        case setCount
        case setRestTime
        case segmentSound
        case startSound
        case endSound
        case sortOrder
        case customSegments
        case intensityPercent
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        let decodedTotalDistance = try c.decodeIfPresent(Int.self, forKey: .totalDistance) ?? 800
        let decodedSegmentDistance = try c.decodeIfPresent(Int.self, forKey: .segmentDistance) ?? 50
        let decodedTotalTime = try c.decodeIfPresent(Double.self, forKey: .totalTime) ?? 240.0
        let uniformCount = max(1, Int(ceil(Double(decodedTotalDistance) / Double(max(1, decodedSegmentDistance)))))

        self.id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.name = try c.decodeIfPresent(String.self, forKey: .name) ?? PaceRunGroup.defaultName
        self.colorHex = try c.decodeIfPresent(String.self, forKey: .colorHex) ?? "#FF5733"
        self.totalDistance = decodedTotalDistance
        self.segmentDistance = decodedSegmentDistance
        self.totalTime = decodedTotalTime
        self.segmentTime = try c.decodeIfPresent(Double.self, forKey: .segmentTime) ?? max(0.1, decodedTotalTime / Double(uniformCount))
        self.countdownSeconds = try c.decodeIfPresent(Int.self, forKey: .countdownSeconds) ?? 3
        self.setCount = try c.decodeIfPresent(Int.self, forKey: .setCount)
        self.setRestTime = try c.decodeIfPresent(Double.self, forKey: .setRestTime)
        self.segmentSound = try c.decodeIfPresent(SoundType.self, forKey: .segmentSound) ?? .splitTick
        self.startSound = try c.decodeIfPresent(SoundType.self, forKey: .startSound) ?? .startTriad
        self.endSound = try c.decodeIfPresent(SoundType.self, forKey: .endSound) ?? .finishArpeggio
        self.sortOrder = try c.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        self.customSegments = try c.decodeIfPresent([CustomSegment].self, forKey: .customSegments)
        self.intensityPercent = try c.decodeIfPresent(Double.self, forKey: .intensityPercent) ?? 100
    }
}

struct PaceRunTraining: Codable, Identifiable {
    var id: UUID
    var userId: String
    var name: String
    var groups: [PaceRunGroup]
    var countdownSeconds: Int
    var createdAt: Date
    var updatedAt: Date
    
    init(
        id: UUID = UUID(),
        userId: String = "",
        name: String = "pace_run".localized,        groups: [PaceRunGroup] = [],
        countdownSeconds: Int = 3,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.groups = groups
        self.countdownSeconds = countdownSeconds
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension PaceRunTraining {
    func plannedSessionDuration() -> Double {
        Double(max(0, countdownSeconds)) + (groups.map { $0.totalPlannedDuration() }.max() ?? 0)
    }
}

// Legacy model for compatibility
struct PaceRunConfig: Codable, Identifiable {
    var id: UUID; var userId: String; var name: String; var totalDistance: Int; var segmentDistance: Int; var segmentCount: Int; var totalTime: Int; var segmentTime: Int; var countdownSeconds: Int; var createdAt: Date; var updatedAt: Date
    init(id: UUID = UUID(), userId: String = "", name: String = "pace_run".localized, totalDistance: Int = 800, segmentDistance: Int = 50, totalTime: Int = 240, countdownSeconds: Int = 3, createdAt: Date = Date(), updatedAt: Date = Date()) {
        let count = max(1, Int(ceil(Double(totalDistance) / Double(max(1, segmentDistance)))))
        self.id = id; self.userId = userId; self.name = name; self.totalDistance = totalDistance; self.segmentDistance = segmentDistance
        self.segmentCount = count; self.totalTime = totalTime; self.segmentTime = max(1, totalTime / count); self.countdownSeconds = countdownSeconds; self.createdAt = createdAt; self.updatedAt = updatedAt
    }
    mutating func recalculate() { segmentCount = max(1, Int(ceil(Double(totalDistance) / Double(max(1, segmentDistance))))); segmentTime = max(1, totalTime / max(1, segmentCount)) }
}

// MARK: - Interval Training Models

struct IntervalRepeatConfig: Codable, Identifiable {
    var id: UUID
    var runTime: Double   // seconds
    var restTime: Double  // seconds after this rep (ignored for last rep)

    init(id: UUID = UUID(), runTime: Double = 15.0, restTime: Double = 45.0) {
        self.id = id
        self.runTime = runTime
        self.restTime = restTime
    }
}

struct IntervalGroup: Codable, Identifiable {
    static var defaultName: String { "default_group_name".localized }
    var id: UUID
    var name: String
    var colorHex: String
    var runDistance: Int
    var runTime: Int
    var restTime: Int
    var repetitions: Int
    var countdownSeconds: Int?
    var setCount: Int?
    var setRestTime: Double?
    var startSound: SoundType
    var restSound: SoundType
    var endSound: SoundType
    var sortOrder: Int
    var customRepeats: [IntervalRepeatConfig]?
    var intensityPercent: Double

    init(
        id: UUID = UUID(),
        name: String = IntervalGroup.defaultName,
        colorHex: String = "#FF5733",
        runDistance: Int = 100,
        runTime: Int = 15,
        restTime: Int = 45,
        repetitions: Int = 10,
        countdownSeconds: Int? = nil,
        setCount: Int? = nil,
        setRestTime: Double? = nil,
        startSound: SoundType = .startTriad,
        restSound: SoundType = .restBell,
        endSound: SoundType = .finishArpeggio,
        sortOrder: Int = 0,
        customRepeats: [IntervalRepeatConfig]? = nil,
        intensityPercent: Double = 100
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.runDistance = runDistance
        self.runTime = runTime
        self.restTime = restTime
        self.repetitions = repetitions
        self.countdownSeconds = countdownSeconds
        self.setCount = setCount
        self.setRestTime = setRestTime
        self.startSound = startSound
        self.restSound = restSound
        self.endSound = endSound
        self.sortOrder = sortOrder
        self.customRepeats = customRepeats
        self.intensityPercent = intensityPercent
    }

    var isCustomRepeatsMode: Bool {
        customRepeats != nil && !(customRepeats?.isEmpty ?? true)
    }
    var restCountdownLeadSeconds: Int { max(1, countdownSeconds ?? 3) }
    var effectiveSetCount: Int { max(1, setCount ?? 1) }
    var effectiveSetRest: Double { max(0, setRestTime ?? 0) }

    var effectiveRepetitions: Int {
        if let custom = customRepeats, !custom.isEmpty { return custom.count }
        return max(1, repetitions)
    }

    func runTimeForRep(_ index: Int) -> Double {
        if let custom = customRepeats, index >= 0, index < custom.count {
            return max(0, custom[index].runTime)
        }
        return Double(max(0, runTime))
    }

    func restTimeForRep(_ index: Int) -> Double {
        if let custom = customRepeats, index >= 0, index < custom.count {
            return max(0, custom[index].restTime)
        }
        return Double(max(0, restTime))
    }

    func totalPlannedDuration() -> Double {
        let reps = effectiveRepetitions
        guard reps > 0 else { return 0 }
        var total = 0.0
        for i in 0..<reps {
            total += runTimeForRep(i)
            if i < reps - 1 {
                total += restTimeForRep(i)
            }
        }
        return total * Double(effectiveSetCount) + effectiveSetRest * Double(max(0, effectiveSetCount - 1))
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case colorHex
        case runDistance
        case runTime
        case restTime
        case repetitions
        case countdownSeconds
        case setCount
        case setRestTime
        case startSound
        case restSound
        case endSound
        case sortOrder
        case customRepeats
        case intensityPercent
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        self.id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.name = try c.decodeIfPresent(String.self, forKey: .name) ?? IntervalGroup.defaultName
        self.colorHex = try c.decodeIfPresent(String.self, forKey: .colorHex) ?? "#FF5733"
        self.runDistance = try c.decodeIfPresent(Int.self, forKey: .runDistance) ?? 100
        self.runTime = try c.decodeIfPresent(Int.self, forKey: .runTime) ?? 15
        self.restTime = try c.decodeIfPresent(Int.self, forKey: .restTime) ?? 45
        self.repetitions = try c.decodeIfPresent(Int.self, forKey: .repetitions) ?? 10
        self.countdownSeconds = try c.decodeIfPresent(Int.self, forKey: .countdownSeconds)
        self.setCount = try c.decodeIfPresent(Int.self, forKey: .setCount)
        self.setRestTime = try c.decodeIfPresent(Double.self, forKey: .setRestTime)
        self.startSound = try c.decodeIfPresent(SoundType.self, forKey: .startSound) ?? .startTriad
        self.restSound = try c.decodeIfPresent(SoundType.self, forKey: .restSound) ?? .restBell
        self.endSound = try c.decodeIfPresent(SoundType.self, forKey: .endSound) ?? .finishArpeggio
        self.sortOrder = try c.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        self.customRepeats = try c.decodeIfPresent([IntervalRepeatConfig].self, forKey: .customRepeats)
        self.intensityPercent = try c.decodeIfPresent(Double.self, forKey: .intensityPercent) ?? 100
    }
}

struct IntervalTraining: Codable, Identifiable {
    var id: UUID; var userId: String; var name: String; var groups: [IntervalGroup]; var countdownSeconds: Int; var createdAt: Date; var updatedAt: Date
    init(id: UUID = UUID(), userId: String = "", name: String = "interval_training".localized, groups: [IntervalGroup] = [], countdownSeconds: Int = 3, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id; self.userId = userId; self.name = name; self.groups = groups; self.countdownSeconds = countdownSeconds; self.createdAt = createdAt; self.updatedAt = updatedAt
    }
}

extension IntervalTraining {
    func plannedSessionDuration() -> Double {
        Double(max(0, countdownSeconds)) + (groups.map { $0.totalPlannedDuration() }.max() ?? 0)
    }
}
// MARK: - User Settings

/// Speed display unit: 0 = m/s, 1 = min/km, 2 = km/h
struct UserSettings: Codable {
    var userId: String; var language: String; var soundConfig: SoundConfig; var countdownSeconds: Int; var autoConnectBluetooth: Bool; var speedUnit: Int
    init(userId: String = "", language: String = "system", soundConfig: SoundConfig = SoundConfig(), countdownSeconds: Int = 3, autoConnectBluetooth: Bool = true, speedUnit: Int = 0) {
        self.userId = userId; self.language = language; self.soundConfig = soundConfig; self.countdownSeconds = countdownSeconds; self.autoConnectBluetooth = autoConnectBluetooth; self.speedUnit = speedUnit
    }
    private enum CodingKeys: String, CodingKey { case userId, language, soundConfig, countdownSeconds, autoConnectBluetooth, speedUnit, speedUnitMps }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.userId = try c.decodeIfPresent(String.self, forKey: .userId) ?? ""
        self.language = try c.decodeIfPresent(String.self, forKey: .language) ?? "system"
        self.soundConfig = try c.decodeIfPresent(SoundConfig.self, forKey: .soundConfig) ?? SoundConfig()
        self.countdownSeconds = try c.decodeIfPresent(Int.self, forKey: .countdownSeconds) ?? 3
        self.autoConnectBluetooth = try c.decodeIfPresent(Bool.self, forKey: .autoConnectBluetooth) ?? true
        if let unit = try c.decodeIfPresent(Int.self, forKey: .speedUnit) {
            self.speedUnit = unit
        } else if let mps = try c.decodeIfPresent(Bool.self, forKey: .speedUnitMps) {
            self.speedUnit = mps ? 0 : 1
        } else {
            self.speedUnit = 0
        }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(userId, forKey: .userId)
        try c.encode(language, forKey: .language)
        try c.encode(soundConfig, forKey: .soundConfig)
        try c.encode(countdownSeconds, forKey: .countdownSeconds)
        try c.encode(autoConnectBluetooth, forKey: .autoConnectBluetooth)
        try c.encode(speedUnit, forKey: .speedUnit)
    }
}

// MARK: - Training Record

struct TrainingRecord: Codable, Identifiable {
    var id: UUID; var userId: String; var trainingType: TrainingType; var configId: UUID; var configSnapshot: String; var startTime: Date; var endTime: Date; var completed: Bool; var createdAt: Date
    init(id: UUID = UUID(), userId: String = "", trainingType: TrainingType = .paceRun, configId: UUID = UUID(), configSnapshot: String = "", startTime: Date = Date(), endTime: Date = Date(), completed: Bool = false, createdAt: Date = Date()) {
        self.id = id; self.userId = userId; self.trainingType = trainingType; self.configId = configId; self.configSnapshot = configSnapshot; self.startTime = startTime; self.endTime = endTime; self.completed = completed; self.createdAt = createdAt
    }
}

struct SavedPlan: Codable, Identifiable {
    var id: UUID
    var name: String
    var trainingType: TrainingType
    var configData: Data
    var createdAt: Date
    var updatedAt: Date
    var lastUsedAt: Date

    init(
        id: UUID = UUID(),
        name: String = "",
        trainingType: TrainingType = .paceRun,
        configData: Data = Data(),
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        lastUsedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.trainingType = trainingType
        self.configData = configData
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastUsedAt = lastUsedAt ?? updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case trainingType
        case configData
        case createdAt
        case updatedAt
        case lastUsedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.trainingType = try c.decodeIfPresent(TrainingType.self, forKey: .trainingType) ?? .paceRun
        self.configData = try c.decodeIfPresent(Data.self, forKey: .configData) ?? Data()
        self.createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        self.updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        self.lastUsedAt = try c.decodeIfPresent(Date.self, forKey: .lastUsedAt) ?? self.updatedAt
    }
}

// MARK: - Presets

enum PresetDistance: Int, CaseIterable, Identifiable { case _100=100,_200=200,_400=400,_800=800,_1500=1500,_3000=3000,_5000=5000
    var id: Int { rawValue }; var displayName: String { "\(rawValue)\("unit_meter_short".localized)" }
}
enum PresetSegmentDistance: Int, CaseIterable, Identifiable { case _25=25,_50=50,_100=100,_200=200
    var id: Int { rawValue }; var displayName: String { "\(rawValue)\("unit_meter_short".localized)" }
}
enum GroupColor: String, CaseIterable, Identifiable { case red="#FF5733",blue="#3357FF",green="#33FF57",orange="#FF8C33",purple="#8C33FF",pink="#FF3380"
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .red: return "color_red".localized
        case .blue: return "color_blue".localized
        case .green: return "color_green".localized
        case .orange: return "color_orange".localized
        case .purple: return "color_purple".localized
        case .pink: return "color_pink".localized
        }
    }
}
