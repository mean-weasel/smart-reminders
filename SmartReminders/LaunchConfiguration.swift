import Foundation

enum LaunchConfiguration {
    static func initialIntentText(environment: [String: String] = ProcessInfo.processInfo.environment) -> String {
        #if DEBUG
        environment["SMART_REMINDERS_INITIAL_TEXT"] ?? ""
        #else
        ""
        #endif
    }
}
