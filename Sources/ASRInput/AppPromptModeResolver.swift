import AppKit
import LLMRuleCore

enum AppPromptModeResolver {
    static func currentMode() -> LLMPromptMode {
        guard Preferences.shared.appAwarePromptModeEnabled,
              let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        else {
            return Preferences.shared.llmPromptMode
        }

        if bundleID.contains("Mail") || bundleID.contains("outlook") {
            return .email
        }
        if bundleID.contains("Xcode") ||
            bundleID.contains("Terminal") ||
            bundleID.contains("iTerm") ||
            bundleID.contains("Code") {
            return .terminology
        }
        if bundleID.contains("zoom") ||
            bundleID.contains("teams") ||
            bundleID.contains("meet") {
            return .meeting
        }
        if bundleID.contains("WeChat") ||
            bundleID.contains("Telegram") ||
            bundleID.contains("Slack") ||
            bundleID.contains("Messages") {
            return .chat
        }

        return Preferences.shared.llmPromptMode
    }
}
