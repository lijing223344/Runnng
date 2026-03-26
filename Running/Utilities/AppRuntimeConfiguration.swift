import Foundation

enum AppRuntimeConfiguration {
    static func shouldDisableAudio(arguments: [String] = ProcessInfo.processInfo.arguments) -> Bool {
        arguments.contains("-ui_testing_disable_sound")
    }

    static func shouldEnableDebugLogs(arguments: [String] = ProcessInfo.processInfo.arguments) -> Bool {
        arguments.contains("-debug_logs")
    }

    static func shouldEnableAudioDebugLogs(arguments: [String] = ProcessInfo.processInfo.arguments) -> Bool {
        arguments.contains("-debug_audio_logs") || shouldEnableDebugLogs(arguments: arguments)
    }
}
