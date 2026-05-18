import Cocoa

final class SettingsWindow: NSWindowController {
    private var hotkeyRecorder: HotkeyRecorderView?
    weak var hotkeyManager: HotkeyManager?

    convenience init() {
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 480),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.title = "ASRInput 设置"
        win.isReleasedWhenClosed = false
        win.center()
        self.init(window: win)
        win.delegate = self
        buildTabs()
    }

    private func buildTabs() {
        let tabView = NSTabView()
        tabView.translatesAutoresizingMaskIntoConstraints = false
        window!.contentView!.addSubview(tabView)
        NSLayoutConstraint.activate([
            tabView.topAnchor.constraint(equalTo: window!.contentView!.topAnchor, constant: 8),
            tabView.bottomAnchor.constraint(equalTo: window!.contentView!.bottomAnchor, constant: -8),
            tabView.leadingAnchor.constraint(equalTo: window!.contentView!.leadingAnchor, constant: 8),
            tabView.trailingAnchor.constraint(equalTo: window!.contentView!.trailingAnchor, constant: -8),
        ])

        let hotkeyTab = NSTabViewItem(identifier: "hotkey")
        hotkeyTab.label = "快捷键"
        hotkeyTab.view = makeHotkeyView()
        tabView.addTabViewItem(hotkeyTab)

        let sttTab = NSTabViewItem(identifier: "stt")
        sttTab.label = "语音识别"
        sttTab.view = makeSTTView()
        tabView.addTabViewItem(sttTab)

        let llmTab = NSTabViewItem(identifier: "llm")
        llmTab.label = "LLM 优化"
        llmTab.view = makeLLMView()
        tabView.addTabViewItem(llmTab)
    }

    // MARK: - Hotkey Tab

    private func makeHotkeyView() -> NSView {
        let container = NSView()

        let descLabel = makeLabel("按下快捷键区域，然后按目标按键（如 Fn、⌃Space、Right ⌥）")
        descLabel.translatesAutoresizingMaskIntoConstraints = false
        descLabel.textColor = .secondaryLabelColor
        descLabel.font = NSFont.systemFont(ofSize: 12)
        container.addSubview(descLabel)

        let recorder = HotkeyRecorderView(config: Preferences.shared.hotkeyConfig)
        recorder.translatesAutoresizingMaskIntoConstraints = false
        recorder.delegate = self
        container.addSubview(recorder)
        self.hotkeyRecorder = recorder

        let resetBtn = NSButton(title: "恢复默认 (Fn)", target: self, action: #selector(resetHotkey))
        resetBtn.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(resetBtn)

        NSLayoutConstraint.activate([
            descLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 24),
            descLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 24),
            descLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -24),

            recorder.topAnchor.constraint(equalTo: descLabel.bottomAnchor, constant: 16),
            recorder.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            recorder.widthAnchor.constraint(equalToConstant: 200),
            recorder.heightAnchor.constraint(equalToConstant: 52),

            resetBtn.topAnchor.constraint(equalTo: recorder.bottomAnchor, constant: 16),
            resetBtn.centerXAnchor.constraint(equalTo: container.centerXAnchor),
        ])

        return container
    }

    @objc private func resetHotkey() {
        let config = HotkeyConfig.defaultConfig
        Preferences.shared.hotkeyConfig = config
        hotkeyRecorder?.updateConfig(config)
        hotkeyManager?.updateConfig(config)
    }

    // MARK: - STT Tab

    private var whisperEndpointField: NSTextField?
    private var whisperModelField: NSTextField?
    private var whisperAPIKeyField: NSSecureTextField?
    private var sttStatusLabel: NSTextField?
    private var whisperEndpointConstraint: NSLayoutConstraint?
    private weak var appleRadioRef: NSButton?
    private weak var whisperRadioRef: NSButton?

    private func makeSTTView() -> NSView {
        let container = NSView()

        let appleRadio = NSButton(radioButtonWithTitle: "Apple Speech（流式，在线）", target: self, action: #selector(sttBackendChanged(_:)))
        appleRadio.tag = 0
        appleRadio.translatesAutoresizingMaskIntoConstraints = false
        appleRadio.state = Preferences.shared.sttBackend == .apple ? .on : .off
        self.appleRadioRef = appleRadio

        let whisperRadio = NSButton(radioButtonWithTitle: "本地 Whisper HTTP（离线，非流式）", target: self, action: #selector(sttBackendChanged(_:)))
        whisperRadio.tag = 1
        whisperRadio.translatesAutoresizingMaskIntoConstraints = false
        whisperRadio.state = Preferences.shared.sttBackend == .whisper ? .on : .off
        self.whisperRadioRef = whisperRadio

        container.addSubview(appleRadio)
        container.addSubview(whisperRadio)

        let grid = NSGridView()
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.columnSpacing = 12
        grid.rowSpacing = 10
        container.addSubview(grid)

        let epLabel = makeLabel("Endpoint URL:")
        let epField = NSTextField()
        epField.placeholderString = "http://localhost:8080"
        epField.stringValue = Preferences.shared.whisperEndpoint
        epField.translatesAutoresizingMaskIntoConstraints = false
        epField.widthAnchor.constraint(equalToConstant: 260).isActive = true
        epField.target = self
        epField.action = #selector(saveWhisperConfig)
        self.whisperEndpointField = epField

        let modelLabel = makeLabel("Model:")
        let modelField = NSTextField()
        modelField.placeholderString = "whisper-1"
        modelField.stringValue = Preferences.shared.whisperModel
        modelField.translatesAutoresizingMaskIntoConstraints = false
        modelField.widthAnchor.constraint(equalToConstant: 260).isActive = true
        modelField.target = self
        modelField.action = #selector(saveWhisperConfig)
        self.whisperModelField = modelField

        let apiKeyLabel = makeLabel("API Key:")
        let apiKeyField = NSSecureTextField()
        apiKeyField.placeholderString = "可选，用于需要鉴权的本地服务"
        apiKeyField.stringValue = Preferences.shared.whisperAPIKey
        apiKeyField.translatesAutoresizingMaskIntoConstraints = false
        apiKeyField.widthAnchor.constraint(equalToConstant: 260).isActive = true
        apiKeyField.target = self
        apiKeyField.action = #selector(saveWhisperConfig)
        self.whisperAPIKeyField = apiKeyField

        let testBtn = NSButton(title: "测试连接", target: self, action: #selector(testWhisperConnection))
        let saveBtn = NSButton(title: "保存", target: self, action: #selector(saveWhisperConfig))

        let statusLabel = makeLabel("")
        statusLabel.textColor = .secondaryLabelColor
        self.sttStatusLabel = statusLabel

        let btnStack = NSStackView(views: [saveBtn, testBtn, statusLabel])
        btnStack.spacing = 12

        grid.addRow(with: [epLabel, epField])
        grid.addRow(with: [modelLabel, modelField])
        grid.addRow(with: [apiKeyLabel, apiKeyField])
        grid.addRow(with: [NSGridCell.emptyContentView, btnStack])
        grid.column(at: 0).xPlacement = .trailing

        let isWhisper = Preferences.shared.sttBackend == .whisper
        grid.isHidden = !isWhisper

        NSLayoutConstraint.activate([
            appleRadio.topAnchor.constraint(equalTo: container.topAnchor, constant: 24),
            appleRadio.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 24),

            whisperRadio.topAnchor.constraint(equalTo: appleRadio.bottomAnchor, constant: 12),
            whisperRadio.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 24),

            grid.topAnchor.constraint(equalTo: whisperRadio.bottomAnchor, constant: 16),
            grid.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 24),
        ])

        // Store grid reference for show/hide
        grid.identifier = NSUserInterfaceItemIdentifier("whisperGrid")

        return container
    }

    @objc private func sttBackendChanged(_ sender: NSButton) {
        let backend: STTBackend = sender.tag == 0 ? .apple : .whisper
        Preferences.shared.sttBackend = backend

        // Mutually exclusive toggle
        appleRadioRef?.state  = backend == .apple   ? .on : .off
        whisperRadioRef?.state = backend == .whisper ? .on : .off

        // Show/hide whisper config grid
        if let view = sender.superview,
           let grid = view.subviews.first(where: { $0.identifier?.rawValue == "whisperGrid" }) {
            grid.isHidden = backend == .apple
        }

        NotificationCenter.default.post(name: .sttBackendChanged, object: nil)
    }

    @objc private func saveWhisperConfig() {
        if let ep = whisperEndpointField?.stringValue.trimmingCharacters(in: .whitespacesAndNewlines), !ep.isEmpty {
            Preferences.shared.whisperEndpoint = ep
        }
        if let model = whisperModelField?.stringValue.trimmingCharacters(in: .whitespacesAndNewlines), !model.isEmpty {
            Preferences.shared.whisperModel = model
        }
        Preferences.shared.whisperAPIKey = whisperAPIKeyField?.stringValue ?? ""
        sttStatusLabel?.stringValue = "已保存 ✓"
        sttStatusLabel?.textColor = .systemGreen
    }

    @objc private func testWhisperConnection() {
        sttStatusLabel?.stringValue = "测试中…"
        sttStatusLabel?.textColor = .secondaryLabelColor
        saveWhisperConfig()

        let endpoint = Preferences.shared.whisperEndpoint
        guard let url = URL(string: endpoint + "/v1/models") else {
            sttStatusLabel?.stringValue = "URL 格式错误"
            sttStatusLabel?.textColor = .systemRed
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        WhisperTranscriber.setAuthorizationHeader(on: &request, apiKey: Preferences.shared.whisperAPIKey)

        URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
            DispatchQueue.main.async {
                if let error {
                    self?.sttStatusLabel?.stringValue = "连接失败: \(error.localizedDescription)"
                    self?.sttStatusLabel?.textColor = .systemRed
                } else if let code = (response as? HTTPURLResponse)?.statusCode {
                    self?.sttStatusLabel?.stringValue = "HTTP \(code) \(code < 400 ? "✓" : "✗")"
                    self?.sttStatusLabel?.textColor = code < 400 ? .systemGreen : .systemRed
                }
            }
        }.resume()
    }

    // MARK: - LLM Tab

    private var llmBaseURLField: NSTextField?
    private var llmAPIKeyField: NSSecureTextField?
    private var llmModelField: NSTextField?
    private var llmStatusLabel: NSTextField?
    private var llmEnabledCheck: NSButton?
    private var llmPunctuationCheck: NSButton?
    private var llmSentenceBreakCheck: NSButton?
    private var llmFillerWordsCheck: NSButton?
    private var llmCustomRulesTextView: NSTextView?

    private func makeLLMView() -> NSView {
        let container = NSView()

        let enableCheck = NSButton(checkboxWithTitle: "启用 LLM 校正", target: self, action: #selector(toggleLLM))
        enableCheck.state = Preferences.shared.llmEnabled ? .on : .off
        enableCheck.translatesAutoresizingMaskIntoConstraints = false
        self.llmEnabledCheck = enableCheck
        container.addSubview(enableCheck)

        let grid = NSGridView()
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.columnSpacing = 12
        grid.rowSpacing = 10
        container.addSubview(grid)

        let urlLabel = makeLabel("API Base URL:")
        let urlField = NSTextField()
        urlField.placeholderString = "https://api.openai.com/v1"
        urlField.stringValue = Preferences.shared.llmBaseURL
        urlField.translatesAutoresizingMaskIntoConstraints = false
        urlField.widthAnchor.constraint(equalToConstant: 280).isActive = true
        self.llmBaseURLField = urlField

        let keyLabel = makeLabel("API Key:")
        let keyField = NSSecureTextField()
        keyField.placeholderString = "sk-..."
        keyField.stringValue = Preferences.shared.llmAPIKey
        keyField.translatesAutoresizingMaskIntoConstraints = false
        keyField.widthAnchor.constraint(equalToConstant: 280).isActive = true
        self.llmAPIKeyField = keyField

        let modelLabel = makeLabel("模型:")
        let modelField = NSTextField()
        modelField.placeholderString = "gpt-4o-mini"
        modelField.stringValue = Preferences.shared.llmModel
        modelField.translatesAutoresizingMaskIntoConstraints = false
        modelField.widthAnchor.constraint(equalToConstant: 280).isActive = true
        self.llmModelField = modelField

        let rulesLabel = makeLabel("整理规则:")
        let punctuationCheck = NSButton(
            checkboxWithTitle: "补全标点",
            target: nil,
            action: nil
        )
        punctuationCheck.state = Preferences.shared.llmPunctuationEnabled ? .on : .off
        self.llmPunctuationCheck = punctuationCheck

        let sentenceBreakCheck = NSButton(
            checkboxWithTitle: "优化断句",
            target: nil,
            action: nil
        )
        sentenceBreakCheck.state = Preferences.shared.llmSentenceBreakEnabled ? .on : .off
        self.llmSentenceBreakCheck = sentenceBreakCheck

        let fillerWordsCheck = NSButton(
            checkboxWithTitle: "移除口头填充词",
            target: nil,
            action: nil
        )
        fillerWordsCheck.state = Preferences.shared.llmFillerWordsEnabled ? .on : .off
        self.llmFillerWordsCheck = fillerWordsCheck

        let rulesStack = NSStackView(views: [punctuationCheck, sentenceBreakCheck, fillerWordsCheck])
        rulesStack.orientation = .vertical
        rulesStack.alignment = .leading
        rulesStack.spacing = 4

        let customRulesLabel = makeLabel("自定义规则:")
        let customRulesTextView = NSTextView()
        customRulesTextView.string = Preferences.shared.llmCustomRules
        customRulesTextView.font = .systemFont(ofSize: 12)
        customRulesTextView.isRichText = false
        customRulesTextView.allowsUndo = true
        customRulesTextView.textContainerInset = NSSize(width: 6, height: 6)
        self.llmCustomRulesTextView = customRulesTextView

        let customRulesScroll = NSScrollView()
        customRulesScroll.translatesAutoresizingMaskIntoConstraints = false
        customRulesScroll.hasVerticalScroller = true
        customRulesScroll.borderType = .bezelBorder
        customRulesScroll.documentView = customRulesTextView
        customRulesScroll.widthAnchor.constraint(equalToConstant: 280).isActive = true
        customRulesScroll.heightAnchor.constraint(equalToConstant: 72).isActive = true

        let saveBtn = NSButton(title: "保存", target: self, action: #selector(saveLLMConfig))
        saveBtn.keyEquivalent = "\r"
        let testBtn = NSButton(title: "测试连接", target: self, action: #selector(testLLMConnection))

        let statusLabel = makeLabel("")
        statusLabel.textColor = .secondaryLabelColor
        self.llmStatusLabel = statusLabel

        let btnStack = NSStackView(views: [saveBtn, testBtn, statusLabel])
        btnStack.spacing = 12

        grid.addRow(with: [urlLabel, urlField])
        grid.addRow(with: [keyLabel, keyField])
        grid.addRow(with: [modelLabel, modelField])
        grid.addRow(with: [rulesLabel, rulesStack])
        grid.addRow(with: [customRulesLabel, customRulesScroll])
        grid.addRow(with: [NSGridCell.emptyContentView, btnStack])
        grid.column(at: 0).xPlacement = .trailing

        NSLayoutConstraint.activate([
            enableCheck.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            enableCheck.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 24),

            grid.topAnchor.constraint(equalTo: enableCheck.bottomAnchor, constant: 16),
            grid.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 24),
        ])

        return container
    }

    @objc private func toggleLLM() {
        Preferences.shared.llmEnabled = llmEnabledCheck?.state == .on
    }

    @objc private func saveLLMConfig() {
        Preferences.shared.llmBaseURL = llmBaseURLField?.stringValue.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        Preferences.shared.llmAPIKey  = llmAPIKeyField?.stringValue ?? ""
        Preferences.shared.llmModel   = llmModelField?.stringValue.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        Preferences.shared.llmPunctuationEnabled = llmPunctuationCheck?.state == .on
        Preferences.shared.llmSentenceBreakEnabled = llmSentenceBreakCheck?.state == .on
        Preferences.shared.llmFillerWordsEnabled = llmFillerWordsCheck?.state == .on
        Preferences.shared.llmCustomRules = llmCustomRulesTextView?.string.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        llmStatusLabel?.stringValue   = "已保存 ✓"
        llmStatusLabel?.textColor     = .systemGreen
    }

    @objc private func testLLMConnection() {
        saveLLMConfig()
        llmStatusLabel?.stringValue = "测试中…"
        llmStatusLabel?.textColor = .secondaryLabelColor
        LLMRefiner().testConnection { [weak self] success, message in
            DispatchQueue.main.async {
                self?.llmStatusLabel?.stringValue = message
                self?.llmStatusLabel?.textColor = success ? .systemGreen : .systemRed
            }
        }
    }

    // MARK: - Helpers

    private func makeLabel(_ text: String) -> NSTextField {
        let f = NSTextField(labelWithString: text)
        f.translatesAutoresizingMaskIntoConstraints = false
        return f
    }

    func present() {
        guard let win = window else { return }
        NSApp.setActivationPolicy(.regular)
        if !win.isVisible { win.center() }
        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
        win.orderFrontRegardless()
    }
}

extension SettingsWindow: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

extension SettingsWindow: HotkeyRecorderViewDelegate {
    func hotkeyRecorder(_ view: HotkeyRecorderView, didRecord config: HotkeyConfig) {
        Preferences.shared.hotkeyConfig = config
        hotkeyManager?.updateConfig(config)
        AppLogger.hotkey.info("Hotkey updated via recorder: \(config.displayString)")
    }
}

extension Notification.Name {
    static let sttBackendChanged = Notification.Name("com.asrinput.sttBackendChanged")
}
