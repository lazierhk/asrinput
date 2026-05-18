import AVFoundation
import Foundation

final class WhisperTranscriber: Transcriber {
    var onPartial: ((String) -> Void)?
    var onLevel:   ((Float) -> Void)?

    private let engine = AVAudioEngine()
    private var audioFile: AVAudioFile?
    private var tempURL: URL?
    private var language: String = "zh"
    private var isStopping = false
    private var levelTimer: Timer?

    func start(language: String, completion: @escaping (Error?) -> Void) {
        isStopping = false
        self.language = String(language.prefix(2))  // "zh-CN" → "zh"

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("asrinput_\(UUID().uuidString).wav")
        tempURL = url

        let inputNode = engine.inputNode
        let fmt = inputNode.outputFormat(forBus: 0)

        do {
            audioFile = try AVAudioFile(forWriting: url, settings: fmt.settings)
        } catch {
            completion(error)
            return
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: fmt) { [weak self] buf, _ in
            guard let self else { return }
            try? self.audioFile?.write(from: buf)
            let rms = SpeechTranscriber.computeRMS(buf)
            DispatchQueue.main.async { self.onLevel?(rms) }
        }

        do {
            try engine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            completion(error)
            return
        }

        completion(nil)
        AppLogger.whisper.info("WhisperTranscriber started")
    }

    func stop(completion: @escaping (String) -> Void) {
        guard !isStopping else { return }
        isStopping = true

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        audioFile = nil

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
