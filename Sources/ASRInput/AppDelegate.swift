import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate, HotkeyManagerDelegate {
    private let menuBar = MenuBarController()
    private let overlay = OverlayPanel()
    private let injector = TextInjector()
    private let llm = LLMRefiner()
    private let hotkey = HotkeyManager()
    private var transcriber: any Transcriber
    private var settingsWindow: SettingsWindow?
    private var hotkeyRetryTimer: Timer?

    override init() {
        transcriber = Self.makeTranscriber()
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainMenu()
        menuBar.setup(delegate: self)
        hotkey.delegate = self
        setupTranscriberCallbacks()
        observeNotifications()
        requestPermissions()
        startHotkeyIfPossible(prompt: true)
        AppLogger.main.info("ASRInput launched")
    }

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu()
        appItem.submenu = appMenu
        appMenu.addItem(NSMenuItem(title: "退出 ASRInput", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        let editItem = NSMenuItem()
        mainMenu.addItem(editItem)
        let editMenu = NSMenu(title: "编辑")
        editItem.submenu = editMenu
        editMenu.addItem(NSMenuItem(title: "撤销", action: Selector(("undo:")), keyEquivalent: "z"))
        editMenu.addItem(NSMenuItem(title: "重做", action: Selector(("redo:")), keyEquivalent: "Z"))
        editMenu.addItem(.separator())
        editMenu.addItem(NSMenuItem(title: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "拷贝", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))

        NSApp.mainMenu = mainMenu
    }

    // MARK: - Menu Actions (must be @objc for NSMenuItem target/action)

    @objc func menuOpenSettings() {
        DispatchQueue.main.async { [weak self] in
            self?.openSettings()
        }
    }

    @objc func menuSelectLanguage(_ sender: NSMenuItem) {
        guard let code = sender.representedObject as? String else { return }
        Preferences.shared.language = code
        menuBar.updateLanguageCheckmarks()
        AppLogger.main.info("Language changed to \(code)")
    }

    @objc func menuToggleLLM() {
        Preferences.shared.llmEnabled.toggle()
        menuBar.rebuildMenu()
    }

    // MARK: - Settings

    func openSettings() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindow()
            settingsWindow?.hotkeyManager = hotkey
        }
        settingsWindow?.present()
    }

    // MARK: - HotkeyManagerDelegate

    func hotkeyDidStart() {
        AppLogger.main.info("Recording started")
        menuBar.setRecordingState(true)

        let lang = Preferences.shared.language
        transcriber.start(language: lang) { [weak self] error in
            if let error {
                AppLogger.speech.error("Transcriber start failed: \(error.localizedDescription)")
                self?.hotkey.resetRecordingState()
                self?.menuBar.setRecordingState(false)
                return
            }
            self?.overlay.show()
            if Preferences.shared.sttBackend == .whisper {
                self?.overlay.updateText("🎙 录音中…")
            }
        }
    }

    func hotkeyDidStop() {
        AppLogger.main.info("Recording stopped")
        stopAndInject()
    }

    // MARK: - Stop & Inject

    private func stopAndInject() {
        menuBar.setRecordingState(false)

        transcriber.stop { [weak self] rawText in
            guard let self else { return }
            let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)

            if text.isEmpty {
                DispatchQueue.main.async { self.overlay.dismiss() }
                return
            }

            DispatchQueue.main.async { self.overlay.updateText(text) }

            if Preferences.shared.llmEnabled && !Preferences.shared.llmBaseURL.isEmpty {
                DispatchQueue.main.async { self.overlay.showRefining() }
                self.llm.refine(text) { result in
                    let final = result ?? text
                    DispatchQueue.main.async { self.overlay.updateText(final) }
                    DispatchQueue.global(qos: .userInitiated).async {
                        self.injector.inject(final)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { self.overlay.dismiss() }
                }
            } else {
                DispatchQueue.global(qos: .userInitiated).async {
                    self.injector.inject(text)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { self.overlay.dismiss() }
            }
        }
    }

    // MARK: - Transcriber Callbacks

    private func setupTranscriberCallbacks() {
        transcriber.onPartial = { [weak self] text in
            self?.overlay.updateText(text)
        }
        transcriber.onLevel = { [weak self] level in
            self?.overlay.updateLevel(level)
        }
    }

    // MARK: - Notifications

    private func observeNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAutoStop(_:)),
            name: .speechAutoStopped,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSTTBackendChanged),
            name: .sttBackendChanged,
            object: nil
        )
    }

    @objc private func handleAutoStop(_ note: Notification) {
        guard hotkey.isRecording else { return }
        hotkey.resetRecordingState()
        let text = note.userInfo?["text"] as? String ?? ""
        menuBar.setRecordingState(false)

        if text.isEmpty {
            overlay.dismiss()
            return
        }

        if Preferences.shared.llmEnabled && !Preferences.shared.llmBaseURL.isEmpty {
            overlay.showRefining()
            llm.refine(text) { result in
                let final = result ?? text
                DispatchQueue.main.async { self.overlay.updateText(final) }
                DispatchQueue.global(qos: .userInitiated).async { self.injector.inject(final) }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { self.overlay.dismiss() }
            }
        } else {
            overlay.updateText(text)
            DispatchQueue.global(qos: .userInitiated).async { self.injector.inject(text) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { self.overlay.dismiss() }
        }
    }

    @objc private func handleSTTBackendChanged() {
        transcriber = Self.makeTranscriber()
        setupTranscriberCallbacks()
        AppLogger.main.info("STT backend switched to \(Preferences.shared.sttBackend.rawValue)")
    }

    // MARK: - Permissions

    private func requestPermissions() {
        PermissionManager.requestAll { granted in
            if !granted {
                AppLogger.main.warning("Permissions not fully granted")
            }
        }
    }

    private func startHotkeyIfPossible(prompt: Bool) {
        guard PermissionManager.checkAccessibility(prompt: prompt) else {
            AppLogger.hotkey.warning("Accessibility permission missing; hotkey start deferred")
            scheduleHotkeyRetry()
            return
        }

        if hotkey.start() {
            hotkeyRetryTimer?.invalidate()
            hotkeyRetryTimer = nil
        } else {
            scheduleHotkeyRetry()
        }
    }

    private func scheduleHotkeyRetry() {
        guard hotkeyRetryTimer == nil else { return }
        hotkeyRetryTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.startHotkeyIfPossible(prompt: false)
        }
    }

    // MARK: - Factory

    static func makeTranscriber() -> any Transcriber {
        Preferences.shared.sttBackend == .whisper
            ? WhisperTranscriber()
            : SpeechTranscriber()
    }
}
