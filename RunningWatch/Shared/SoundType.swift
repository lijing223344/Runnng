import Foundation

// SoundType enum — shared with iOS app for model compatibility.
// Keep in sync with Running/Utilities/SoundManager.swift SoundType enum.
enum SoundType: String, CaseIterable, Identifiable, Codable {
    case whistleShort
    case whistleDouble
    case whistleTriple
    case airHorn
    case buzzer
    case whistleStandard
    case whistleQixinlu

    var id: String { rawValue }

    var displayNameKey: String {
        switch self {
        case .whistleShort:    return "sound_whistle_short"
        case .whistleDouble:   return "sound_whistle_double"
        case .whistleTriple:   return "sound_whistle_triple"
        case .airHorn:         return "sound_air_horn"
        case .buzzer:          return "sound_buzzer"
        case .whistleStandard: return "sound_whistle_standard"
        case .whistleQixinlu:  return "sound_whistle_qixinlu"
        }
    }

    // Backward-compatible decoding
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = SoundType(rawValue: raw) ?? .whistleShort
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
