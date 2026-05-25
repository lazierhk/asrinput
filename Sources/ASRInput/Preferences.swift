import Foundation
import LLMRuleCore

enum STTBackend: String, Codable {
    case apple
    case whisper
}

final class Preferences {
    static let shared = Preferences()
    private init() {}

    private let defaults = UserDefaults.standard

    private func bool(forKey key: String, default defaultValue: Bool) -> Bool {
        guard defaults.object(forKey: key) != nil else { return defaultValue }
        return defaults.bool(forKey: key)
    }

    // MARK: - Language
    var language: String {
        get { defaults.string(forKey: "language") ?? "zh-CN" }
        set { defaults.set(newValue, forKey: "language") }
    }

    // MARK: - Hotkey
    var hotkeyConfig: HotkeyConfig {
        get {
            guard let data = defaults.data(forKey: "hotkeyConfig"),
                  let config = try? JSONDecoder().decode(HotkeyConfig.self, from: data)
            else { return .defaultConfig }
            return config
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: "hotkeyConfig")
            }
        }
    }

    // MARK: - Paste
    var clipboardRestoreDelay: TimeInterval {
        get {
            let value = defaults.double(forKey: "clipboardRestoreDelay")
            return value > 0 ? value : 0.2
        }
        set { defaults.set(max(newValue, 0.05), forKey: "clipboardRestoreDelay") }
    }

    // MARK: - STT Backend
    var sttBackend: STTBackend {
        get {
            guard let raw = defaults.string(forKey: "sttBackend"),
                  let backend = STTBackend(rawValue: raw)
            else { return .apple }
            return backend
        }
        set { defaults.set(newValue.rawValue, forKey: "sttBackend") }
    }

    var whisperEndpoint: String {
        get { defaults.string(forKey: "whisperEndpoint") ?? "http://localhost:8080" }
        set { defaults.set(newValue, forKey: "whisperEndpoint") }
    }

    var whisperModel: String {
        get { defaults.string(forKey: "whisperModel") ?? "whisper-1" }
        set { defaults.set(newValue, forKey: "whisperModel") }
    }

    var whisperAPIKey: String {
        get { defaults.string(forKey: "whisperAPIKey") ?? "" }
        set { defaults.set(newValue, forKey: "whisperAPIKey") }
    }

    // MARK: - LLM
    var llmEnabled: Bool {
        get { defaults.bool(forKey: "llmEnabled") }
        set { defaults.set(newValue, forKey: "llmEnabled") }
    }

    var llmBaseURL: String {
        get { defaults.string(forKey: "llmBaseURL") ?? "" }
        set { defaults.set(newValue, forKey: "llmBaseURL") }
    }

    var llmAPIKey: String {
        get { defaults.string(forKey: "llmAPIKey") ?? "" }
        set { defaults.set(newValue, forKey: "llmAPIKey") }
    }

    var llmModel: String {
        get { defaults.string(forKey: "llmModel") ?? "gpt-4o-mini" }
        set { defaults.set(newValue, forKey: "llmModel") }
    }

    var llmCorrectionMode: LLMCorrectionMode {
        get {
            guard let raw = defaults.string(forKey: "llmCorrectionMode"),
                  let mode = LLMCorrectionMode(rawValue: raw)
            else { return .strict }
            return mode
        }
        set { defaults.set(newValue.rawValue, forKey: "llmCorrectionMode") }
    }

    var llmPunctuationEnabled: Bool {
        get { bool(forKey: "llmPunctuationEnabled", default: true) }
        set { defaults.set(newValue, forKey: "llmPunctuationEnabled") }
    }

    var llmSentenceBreakEnabled: Bool {
        get { bool(forKey: "llmSentenceBreakEnabled", default: true) }
        set { defaults.set(newValue, forKey: "llmSentenceBreakEnabled") }
    }

    var llmFillerWordsEnabled: Bool {
        get { bool(forKey: "llmFillerWordsEnabled", default: true) }
        set { defaults.set(newValue, forKey: "llmFillerWordsEnabled") }
    }

    var llmCustomRules: String {
        get { defaults.string(forKey: "llmCustomRules") ?? "" }
        set { defaults.set(newValue, forKey: "llmCustomRules") }
    }

    var llmGlossary: String {
        get { defaults.string(forKey: "llmGlossary") ?? "" }
        set { defaults.set(newValue, forKey: "llmGlossary") }
    }
}
