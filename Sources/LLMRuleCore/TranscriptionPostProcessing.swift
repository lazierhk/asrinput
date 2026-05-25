import Foundation

public enum TranscriptionPostProcessing {
    public static func normalizedRawText(_ rawText: String) -> String {
        rawText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func injectionText(rawText: String, refinedText: String?) -> String? {
        let raw = normalizedRawText(rawText)
        guard !raw.isEmpty else { return nil }

        if let refined = refinedText?.trimmingCharacters(in: .whitespacesAndNewlines),
           !refined.isEmpty {
            return refined
        }

        return raw
    }
}
