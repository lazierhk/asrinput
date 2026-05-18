import Foundation

public enum LLMOutputSanitizer {
    public static func sanitize(_ raw: String) -> String {
        let withoutThinkBlocks = removeDelimitedBlocks(
            from: raw,
            start: "<think>",
            end: "</think>"
        )
        let trimmed = withoutThinkBlocks.trimmingCharacters(in: .whitespacesAndNewlines)

        if let extracted = extractAfterLastOutputMarker(from: trimmed) {
            return extracted
        }

        return trimmed
    }

    private static func removeDelimitedBlocks(from input: String, start: String, end: String) -> String {
        var result = input
        while let startRange = result.range(of: start, options: [.caseInsensitive]),
              let endRange = result.range(of: end, options: [.caseInsensitive], range: startRange.upperBound..<result.endIndex) {
            result.removeSubrange(startRange.lowerBound..<endRange.upperBound)
        }
        return result
    }

    private static func extractAfterLastOutputMarker(from input: String) -> String? {
        let markers = [
            "Output:",
            "Output：",
            "输出:",
            "输出：",
            "Final Output:",
            "Final Output：",
            "最终输出:",
            "最终输出：",
            "最终结果:",
            "最终结果："
        ]

        var bestRange: Range<String.Index>?
        for marker in markers {
            var searchStart = input.startIndex
            while let range = input.range(of: marker, range: searchStart..<input.endIndex) {
                if bestRange == nil || range.lowerBound > bestRange!.lowerBound {
                    bestRange = range
                }
                searchStart = range.upperBound
            }
        }

        guard let markerRange = bestRange else { return nil }
        let tail = input[markerRange.upperBound...]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tail.isEmpty else { return nil }

        let firstLine = tail.split(whereSeparator: \.isNewline).first.map(String.init) ?? tail
        let cleaned = firstLine
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'`"))
        return cleaned.isEmpty ? nil : cleaned
    }
}
