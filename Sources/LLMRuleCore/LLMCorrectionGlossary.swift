import Foundation

public struct LLMGlossaryEntry: Equatable {
    public var canonical: String
    public var aliases: [String]

    public init(canonical: String, aliases: [String]) {
        self.canonical = canonical
        self.aliases = aliases
    }
}

public enum LLMCorrectionGlossary {
    public static func parse(_ text: String) -> [LLMGlossaryEntry] {
        text.split(whereSeparator: \.isNewline)
            .compactMap { parseLine(String($0)) }
    }

    public static func promptSection(from text: String) -> String {
        let entries = parse(text)
        guard !entries.isEmpty else { return "" }

        let lines = entries.map { entry in
            let aliases = entry.aliases.joined(separator: "、")
            return "- \(entry.canonical)：\(aliases)"
        }
        return lines.joined(separator: "\n")
    }

    private static func parseLine(_ rawLine: String) -> LLMGlossaryEntry? {
        let line = rawLine
            .split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !line.isEmpty else { return nil }

        if let range = line.range(of: "->") {
            let aliasSide = String(line[..<range.lowerBound])
            let canonicalSide = String(line[range.upperBound...])
            return makeEntry(canonical: canonicalSide, aliases: aliasSide)
        }

        if let range = line.range(of: "=") {
            let canonicalSide = String(line[..<range.lowerBound])
            let aliasSide = String(line[range.upperBound...])
            return makeEntry(canonical: canonicalSide, aliases: aliasSide)
        }

        return nil
    }

    private static func makeEntry(canonical: String, aliases: String) -> LLMGlossaryEntry? {
        let canonical = canonical.trimmingCharacters(in: .whitespacesAndNewlines)
        let aliases = aliases
            .split { char in
                char == "," || char == "，" || char == ";" || char == "；" || char == "、"
            }
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0 != canonical }

        guard !canonical.isEmpty, !aliases.isEmpty else { return nil }
        return LLMGlossaryEntry(canonical: canonical, aliases: aliases)
    }
}
