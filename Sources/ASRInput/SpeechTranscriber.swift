import AVFoundation
import Speech
import Foundation

// MARK: - Transcriber Protocol

protocol Transcriber: AnyObject {
    var onPartial: ((String) -> Void)? { get set }
    var onLevel:   ((Float) -> Void)?  { get set }
    func start(language: String, completion: @escaping (Error?) -> Void)
    func stop(completion: @escaping (String) -> Void)
}

// MARK: - Apple Speech Transcriber

final class SpeechTranscriber: NSObject, Transcriber, SFSpeechRecognizerDelegate {
    var onPartial: ((String) -> Void)?
    var onLevel:   ((Float) -> Void)?

    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let engine = AVAudioEngine()

    private var silenceTimer: Timer?
    private var lastPartialTime = Date()
    private var stopCompletion: ((String) -> Void)?
    private var finalText = ""
    private var isStopping = false

    func start(language: String, completion: @escaping (Error?) -> Void) {
        isStopping = false
        finalText = ""

        let locale = Locale(identifier: language)
        recognizer = SFSpeechRecognizer(locale: locale)
        recognizer?.delegate = self

        guard recognizer?.isAvailable == true else {
            completion(NSError(domain: "SpeechTranscriber", code: 1,
                               userInfo: [NSLocalizedDescriptionKey: "Speech recognizer unavailable"]))
            return
        }

        request = SFSpeechAudioBufferRecognitionRequest()
        guard let request else { return }
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false

        let inputNode = engine.inputNode
        let fmt = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: fmt) { [weak self] buf, _ in
            guard let self else { return }
            self.request?.append(buf)
            let rms = Self.computeRMS(buf)
            DispatchQueue.main.async { self.onLevel?(rms) }
        }

        do {
            try engine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            completion(error)
            return
        }

        task = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self, !self.isStopping else { return }
            if let result {
                let text = result.bestTranscription.formattedString
                if !text.isEmpty {
                    self.finalText = text
                    self.lastPartialTime = Date()
                    DispatchQueue.main.async { self.onPartial?(text) }
                    self.resetSilenceTimer()
                }
                if result.isFinal {
                    self.finalize(text: text)
                }
            }
            if let error {
                let nsErr = error as NSError
                // Ignore cancellation errors
                if nsErr.code != 301 && nsErr.code != 203 {
                    AppLogger.speech.error("Recognition error: \(error.localizedDescription)")
                }
            }
        }

        completion(nil)
        AppLogger.speech.info("SpeechTranscriber started: \(language)")
    }

    func stop(completion: @escaping (String) -> Void) {
        guard !isStopping else { return }
        isStopping = true
        stopCompletion = completion
        silenceTimer?.invalidate()
        silenceTimer = nil

        request?.endAudio()
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()

        // Give recognizer a moment to finalize
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self else { return }
            self.task?.cancel()
            self.task = nil
            self.request = nil
            let text = self.finalText
            self.finalText = ""
            self.stopCompletion = nil
            completion(text)
            AppLogger.speech.info("SpeechTranscriber stopped, text length: \(text.count)")
        }
    }

    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: false) { [weak self] _ in
            guard let self, !self.isStopping else { return }
            AppLogger.speech.info("Silence timeout, auto-stopping")
            self.stop { text in
                // Notify AppDelegate via notification
                NotificationCenter.default.post(
                    name: .speechAutoStopped,
                    object: nil,
                    userInfo: ["text": text]
                )
            }
        }
    }

    private func finalize(text: String) {
        guard let completion = stopCompletion else { return }
        isStopping = true
        silenceTimer?.invalidate()
        engine.inputNode.removeTap(onBus: 0)
        if engine.isRunning { engine.stop() }
        task = nil
        request = nil
        stopCompletion = nil
        finalText = ""
        completion(text)
    }

    static func computeRMS(_ buf: AVAudioPCMBuffer) -> Float {
        guard let data = buf.floatChannelData, buf.frameLength > 0 else { return 0 }
        let n = Int(buf.frameLength)
        var sum: Float = 0
        for i in 0..<n {
            let s = data[0][i]
            sum += s * s
        }
        return min(sqrtf(sum / Float(n)) / 0.3, 1.0)
    }

    func speechRecognizer(_ recognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        AppLogger.speech.info("Speech recognizer availability: \(available)")
    }
}

extension Notification.Name {
    static let speechAutoStopped = Notification.Name("com.asrinput.speechAutoStopped")
}
