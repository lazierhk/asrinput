import Foundation
import LLMRuleCore

final class TranscriptionPipeline {
    private let llm: LLMRefiner
    private let injector: TextInjector
    private let store: LastTranscriptionStore

    init(
        llm: LLMRefiner,
        injector: TextInjector,
        store: LastTranscriptionStore = .shared
    ) {
        self.llm = llm
        self.injector = injector
        self.store = store
    }

    func process(
        rawText: String,
        overlay: OverlayPanel
    ) {
        guard let rawText = TranscriptionPostProcessing.injectionText(rawText: rawText, refinedText: nil) else {
            DispatchQueue.main.async { overlay.dismiss() }
            return
        }
        let text = applyWordReplacements(rawText)

        DispatchQueue.main.async { overlay.updateText(text) }

        guard Preferences.shared.llmEnabled, !Preferences.shared.llmBaseURL.isEmpty else {
            finish(
                rawText: rawText,
                processedText: text,
                finalText: text,
                overlay: overlay
            )
            return
        }

        DispatchQueue.main.async { overlay.showRefining() }
        llm.refine(text) { [weak self, weak overlay] refinedText in
            guard let self, let overlay else { return }
            let selectedText = TranscriptionPostProcessing.injectionText(rawText: text, refinedText: refinedText) ?? text
            let finalText = self.applyWordReplacements(selectedText)
            DispatchQueue.main.async { overlay.updateText(finalText) }
            self.finish(
                rawText: rawText,
                processedText: text,
                finalText: finalText,
                overlay: overlay
            )
        }
    }

    private func applyWordReplacements(_ text: String) -> String {
        WordReplacementService.apply(to: text, glossary: Preferences.shared.llmGlossary)
    }

    private func injectAndDismiss(_ text: String, overlay: OverlayPanel) {
        DispatchQueue.global(qos: .userInitiated).async {
            self.injector.inject(text)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            overlay.dismiss()
        }
    }

    private func finish(
        rawText: String,
        processedText: String,
        finalText: String,
        overlay: OverlayPanel
    ) {
        store.save(
            LastTranscription(
                rawText: rawText,
                processedText: processedText,
                finalText: finalText,
                language: Preferences.shared.language,
                backend: Preferences.shared.sttBackend.rawValue
            )
        )
        NotificationCenter.default.post(name: .lastTranscriptionChanged, object: nil)
        injectAndDismiss(finalText, overlay: overlay)
    }
}

extension Notification.Name {
    static let lastTranscriptionChanged = Notification.Name("com.asrinput.lastTranscriptionChanged")
}
