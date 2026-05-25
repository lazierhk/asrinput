import Cocoa
import LLMRuleCore

final class TextInjector {
    private static let pasteSessionType = NSPasteboard.PasteboardType("com.asrinput.pasteSession")
    private let switcher = InputSourceSwitcher()

    func inject(_ text: String) {
        guard !text.isEmpty else { return }
        if Thread.isMainThread {
            injectOnMain(text)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.injectOnMain(text)
            }
        }
    }

    private func injectOnMain(_ text: String) {
        let pb = NSPasteboard.general
        let savedItems = saveClipboard(pb)
        let sessionID = UUID().uuidString

        let switched = switcher.switchToASCIIIfNeeded()
        let pasteDelay: TimeInterval = switched ? 0.06 : 0

        DispatchQueue.main.asyncAfter(deadline: .now() + pasteDelay) { [weak self] in
            guard let self else { return }
            pb.clearContents()
            pb.setString(text, forType: .string)
            pb.setString(sessionID, forType: Self.pasteSessionType)

            self.simulatePaste()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
                guard let self else { return }
                if switched {
                    self.switcher.restoreIfNeeded()
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + Preferences.shared.clipboardRestoreDelay) { [weak self] in
                    guard ClipboardPasteSession.shouldRestoreClipboard(
                        currentText: pb.string(forType: .string),
                        currentSessionID: pb.string(forType: Self.pasteSessionType),
                        expectedText: text,
                        expectedSessionID: sessionID
                    ) else {
                        AppLogger.inject.info("Skipped clipboard restore because pasteboard changed")
                        return
                    }
                    self?.restoreClipboard(pb, items: savedItems)
                }
            }
        }

        AppLogger.inject.info("Injected \(text.count) chars")
    }

    private func saveClipboard(_ pb: NSPasteboard) -> [(NSPasteboardItem, [NSPasteboard.PasteboardType: Data])] {
        var saved: [(NSPasteboardItem, [NSPasteboard.PasteboardType: Data])] = []
        for item in pb.pasteboardItems ?? [] {
            var types: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    types[type] = data
                }
            }
            saved.append((item, types))
        }
        return saved
    }

    private func restoreClipboard(_ pb: NSPasteboard, items: [(NSPasteboardItem, [NSPasteboard.PasteboardType: Data])]) {
        pb.clearContents()
        for (_, types) in items {
            let newItem = NSPasteboardItem()
            for (type, data) in types {
                newItem.setData(data, forType: type)
            }
            pb.writeObjects([newItem])
        }
    }

    private func simulatePaste() {
        let src = CGEventSource(stateID: .combinedSessionState)
        let keyDown = CGEvent(keyboardEventSource: src, virtualKey: 9, keyDown: true)
        let keyUp   = CGEvent(keyboardEventSource: src, virtualKey: 9, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags   = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
