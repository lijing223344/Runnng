import Foundation

enum AppVersionProvider {
    static func displayString(bundle: Bundle = .main) -> String {
        let shortVersion = (bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let build = (bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let shortVersion, !shortVersion.isEmpty, let build, !build.isEmpty {
            return "\(shortVersion) (\(build))"
        }
        if let shortVersion, !shortVersion.isEmpty {
            return shortVersion
        }
        if let build, !build.isEmpty {
            return build
        }
        return "Unknown"
    }
}
