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

    private var values: [LastTranscription] = []
    private let limit: Int

    public init(limit: Int = 20) {
        self.limit = max(1, limit)
    }

    public var latest: LastTranscription? {
        values.first
    }

    public var history: [LastTranscription] {
        values
    }

    @discardableResult
    public func save(_ transcription: LastTranscription) -> Bool {
        guard !transcription.finalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        values.insert(transcription, at: 0)
        if values.count > limit {
            values.removeLast(values.count - limit)
        }
        return true
    }

    public func clear() {
        values.removeAll()
    }
}
