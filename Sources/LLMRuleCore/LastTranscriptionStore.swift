import Foundation

public struct LastTranscription: Equatable {
    public var rawText: String
    public var processedText: String
    public var finalText: String
    public var language: String
    public var backend: String
    public var timestamp: Date

    public init(
        rawText: String,
        processedText: String,
        finalText: String,
        language: String,
        backend: String,
        timestamp: Date = Date()
    ) {
        self.rawText = rawText
        self.processedText = processedText
        self.finalText = finalText
        self.language = language
        self.backend = backend
        self.timestamp = timestamp
    }
}

public final class LastTranscriptionStore {
    public static let shared = LastTranscriptionStore()

    private var value: LastTranscription?

    public init() {}

    public var latest: LastTranscription? {
        value
    }

    @discardableResult
    public func save(_ transcription: LastTranscription) -> Bool {
        guard !transcription.finalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        value = transcription
        return true
    }

    public func clear() {
        value = nil
    }
}
