import Foundation

public struct LLMCorrectionDecision: Equatable {
    public var text: String
    public var accepted: Bool
    public var reason: String

    public init(text: String, accepted: Bool, reason: String) {
        self.text = text
        self.accepted = accepted
        self.reason = reason
    }
}

public enum LLMCorrectionGuard {
    public static func evaluate(
        original: String,
        candidate: String,
        mode: LLMCorrectionMode
    ) -> LLMCorrectionDecision {
        let original = original.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = candidate.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !original.isEmpty else {
            return LLMCorrectionDecision(text: original, accepted: false, reason: "原文为空")
        }
        guard !candidate.isEmpty else {
            return LLMCorrectionDecision(text: original, accepted: false, reason: "模型输出为空，回退原文")
        }
        guard !containsExplanationMarker(candidate) else {
            return LLMCorrectionDecision(text: original, accepted: false, reason: "模型输出包含解释或思考标记，回退原文")
        }

        if candidate == original {
            return LLMCorrectionDecision(text: original, accepted: true, reason: "文本未变化")
        }

        if let missing = firstMissingProtectedToken(original: original, candidate: candidate) {
            return LLMCorrectionDecision(text: original, accepted: false, reason: "保护内容丢失：\(missing)")
        }

        guard lengthRatioLooksSafe(original: original, candidate: candidate, mode: mode) else {
            return LLMCorrectionDecision(text: original, accepted: false, reason: "改动幅度过大，回退原文")
        }

        if lineStructureChangedTooMuch(original: original, candidate: candidate, mode: mode) {
            return LLMCorrectionDecision(text: original, accepted: false, reason: "文本结构变化过大，回退原文")
        }

        return LLMCorrectionDecision(text: candidate, accepted: true, reason: "已接受模型修正")
    }

    private static func containsExplanationMarker(_ text: String) -> Bool {
        let lowered = text.lowercased()
        let markers = [
            "<think>",
            "</think>",
            "```",
            "修正说明",
            "修改说明",
            "原因：",
            "解释：",
            "analysis:",
            "reasoning:"
        ]
        return markers.contains { lowered.contains($0.lowercased()) }
    }

    private static func lengthRatioLooksSafe(
        original: String,
        candidate: String,
        mode: LLMCorrectionMode
    ) -> Bool {
        let originalCount = max(original.count, 1)
        let ratio = Double(candidate.count) / Double(originalCount)

        let range: ClosedRange<Double>
        switch mode {
        case .strict:
            range = originalCount <= 12 ? 0.75...1.35 : 0.65...1.45
        case .lightCleanup:
            range = originalCount <= 12 ? 0.65...1.55 : 0.50...1.80
        case .terminologyFocused:
            range = originalCount <= 12 ? 0.55...2.40 : 0.55...1.80
        }
        return range.contains(ratio)
    }

    private static func lineStructureChangedTooMuch(
        original: String,
        candidate: String,
        mode: LLMCorrectionMode
    ) -> Bool {
        guard mode == .strict else { return false }
        let originalLines = original.split(whereSeparator: \.isNewline).count
        let candidateLines = candidate.split(whereSeparator: \.isNewline).count
        guard originalLines > 1 else { return false }
        return abs(originalLines - candidateLines) > 1
    }

    private static func firstMissingProtectedToken(original: String, candidate: String) -> String? {
        for token in protectedTokens(in: original) {
            guard candidate.contains(token) else { return token }
        }
        return nil
    }

    private static func protectedTokens(in text: String) -> [String] {
        let patterns = [
            #"`[^`]+`"#,
            #"https?://[^\s，。！？；、）\)]+"#,
            #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#,
            #"\b\d+(?:[.,:/-]\d+)*(?:%|ms|s|MB|GB|TB|元|块|美元|℃)?\b"#
        ]

        var tokens: [String] = []
        for pattern in patterns {
            tokens.append(contentsOf: matches(pattern: pattern, in: text))
        }
        return Array(Set(tokens)).sorted { $0.count > $1.count }
    }

    private static func matches(pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let stringRange = Range(match.range, in: text) else { return nil }
            return String(text[stringRange])
        }
    }
}
