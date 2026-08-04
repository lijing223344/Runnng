import Foundation

enum AppRuntimeConfiguration {
    enum LaunchDestination {
        case home
        case miniHurdle
    }

    enum MiniHurdleSeedScenario: String {
        case athleteProfiles
    }

    enum MiniHurdleScrollTarget: String {
        case top
        case middle
        case layout
        case hurdles
        case measurement
        case measurementVertical
        case bottom

        var anchorID: String {
            switch self {
            case .top:
                return "mini_hurdle_anchor_top"
            case .middle:
                return "mini_hurdle_anchor_middle"
            case .layout:
                return "mini_hurdle_anchor_layout"
            case .hurdles:
                return "mini_hurdle_anchor_hurdles"
            case .measurement:
                return "mini_hurdle_anchor_measurement"
            case .measurementVertical:
                return "mini_hurdle_anchor_measurement_vertical"
            case .bottom:
                return "mini_hurdle_anchor_bottom"
            }
        }
    }

    static func shouldDisableAudio(arguments: [String] = ProcessInfo.processInfo.arguments) -> Bool {
        arguments.contains("-ui_testing_disable_sound")
    }

    static func shouldEnableDebugLogs(arguments: [String] = ProcessInfo.processInfo.arguments) -> Bool {
        arguments.contains("-debug_logs")
    }

    static func shouldEnableAudioDebugLogs(arguments: [String] = ProcessInfo.processInfo.arguments) -> Bool {
        arguments.contains("-debug_audio_logs") || shouldEnableDebugLogs(arguments: arguments)
    }

    static func launchDestination(arguments: [String] = ProcessInfo.processInfo.arguments) -> LaunchDestination {
        if arguments.contains("-ui_testing_open_mini_hurdle") {
            return .miniHurdle
        }
        return .home
    }

    static func miniHurdleScrollTarget(
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> MiniHurdleScrollTarget? {
        guard let index = arguments.firstIndex(of: "-ui_testing_mini_hurdle_section"),
              index + 1 < arguments.count else {
            return nil
        }
        return MiniHurdleScrollTarget(rawValue: arguments[index + 1])
    }

    static func miniHurdleSeedScenario(
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> MiniHurdleSeedScenario? {
        guard let index = arguments.firstIndex(of: "-ui_testing_seed_mini_hurdle"),
              index + 1 < arguments.count else {
            return nil
        }
        return MiniHurdleSeedScenario(rawValue: arguments[index + 1])
    }
}
