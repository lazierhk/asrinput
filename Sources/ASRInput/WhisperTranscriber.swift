import AVFoundation
import Foundation

final class WhisperTranscriber: Transcriber {
    var onPartial: ((String) -> Void)?
    var onLevel:   ((Float) -> Void)?

    private var recorder: AVAudioRecorder?
    private var levelTimer: Timer?
    private var tempURL: URL?
    private var language: String = "zh"
    private var isStopping = false

    func start(language: String, completion: @escaping (Error?) -> Void) {
        cleanupAudioCapture(removeTempFile: true)
        isStopping = false
        self.language = String(language.prefix(2))  // "zh-CN" → "zh"

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("asrinput_\(UUID().uuidString).wav")
        tempURL = url

        do {
            let recorder = try AVAudioRecorder(url: url, settings: Self.recordingSettings)
            recorder.isMeteringEnabled = true
            guard recorder.record() else {
                cleanupAudioCapture(removeTempFile: true)
                completion(Self.error("无法开始录音，请检查麦克风权限和输入设备。"))
                return
            }
            self.recorder = recorder
        } catch {
            cleanupAudioCapture(removeTempFile: true)
            completion(error)
            return
        }

        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.recorder?.updateMeters()
            self.onLevel?(Self.normalizedLevel(fromDecibels: self.recorder?.averagePower(forChannel: 0) ?? -160))
        }

        completion(nil)
        AppLogger.whisper.info("WhisperTranscriber started")
    }

    func stop(completion: @escaping (String) -> Void) {
        guard !isStopping else {
            completion("")
            return
        }
        isStopping = true

        cleanupAudioCapture(removeTempFile: false)

        guard let url = tempURL else {
            completion("")
            return
        }

        let endpoint = Preferences.shared.whisperEndpoint
        let model = Preferences.shared.whisperModel
        let apiKey = Preferences.shared.whisperAPIKey
        let lang = language

        DispatchQueue.global(qos: .userInitiated).async {
            let text = Self.transcribe(url: url, endpoint: endpoint, model: model, apiKey: apiKey, language: lang)
            DispatchQueue.main.async { completion(text) }
            try? FileManager.default.removeItem(at: url)
            AppLogger.whisper.info("WhisperTranscriber stopped, result length: \(text.count)")
        }
    }

    private func cleanupAudioCapture(removeTempFile: Bool) {
        levelTimer?.invalidate()
        levelTimer = nil
        if recorder?.isRecording == true {
            recorder?.stop()
        }
        recorder = nil
        if removeTempFile, let tempURL {
            try? FileManager.default.removeItem(at: tempURL)
            self.tempURL = nil
        }
    }

    private static let recordingSettings: [String: Any] = [
        AVFormatIDKey: Int(kAudioFormatLinearPCM),
        AVSampleRateKey: 16_000.0,
        AVNumberOfChannelsKey: 1,
        AVLinearPCMBitDepthKey: 16,
        AVLinearPCMIsBigEndianKey: false,
        AVLinearPCMIsFloatKey: false
    ]

    private static func normalizedLevel(fromDecibels decibels: Float) -> Float {
        guard decibels.isFinite, decibels > -80 else { return 0 }
        return min(max(pow(10, decibels / 35), 0), 1)
    }

    private static func error(_ message: String) -> NSError {
        NSError(domain: "WhisperTranscriber", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }

    static func transcribe(url: URL, endpoint: String, model: String, apiKey: String, language: String) -> String {
        let apiURL = URL(string: endpoint.trimmingCharacters(in: .whitespaces) + "/v1/audio/transcriptions")!
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 30

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        setAuthorizationHeader(on: &request, apiKey: apiKey)

        var body = Data()
        func append(_ string: String) { body.append(Data(string.utf8)) }

        // file field
        guard let fileData = try? Data(contentsOf: url) else { return "" }
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"file\"; filename=\"recording.wav\"\r\n")
        append("Content-Type: audio/wav\r\n\r\n")
        body.append(fileData)
        append("\r\n")

        // model field
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"model\"\r\n\r\n")
        append(model)
        append("\r\n")

        // language field
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"language\"\r\n\r\n")
        append(language)
        append("\r\n")

        // response_format field
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n")
        append("json")
        append("\r\n")

        append("--\(boundary)--\r\n")
        request.httpBody = body

        let semaphore = DispatchSemaphore(value: 0)
        var result = ""
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }
            if let error {
                AppLogger.whisper.error("Whisper request error: \(error.localizedDescription)")
                return
            }
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let text = json["text"] as? String
            else {
                AppLogger.whisper.error("Whisper response parse failed")
                return
            }
            result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        task.resume()
        semaphore.wait()
        return result
    }

    static func setAuthorizationHeader(on request: inout URLRequest, apiKey: String) {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        request.setValue("Bearer \(trimmed)", forHTTPHeaderField: "Authorization")
    }
}
