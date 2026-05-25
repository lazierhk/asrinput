import Foundation

public enum WordReplacementService {
    public static func apply(to text: String, glossary: String) -> String {
        let entries = LLMCorrectionGlossary.parse(glossary)
        guard !text.isEmpty, !entries.isEmpty else { return text }

        var result = text
        for entry in entries {
            for alias in entry.aliases.sorted(by: { $0.count > $1.count }) {
                guard !alias.isEmpty else { continue }
                result = result.replacingOccurrences(of: alias, with: entry.canonical)
            }
        }
        return result
    }
}
