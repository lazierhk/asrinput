import Cocoa
import AVFoundation
import LLMRuleCore
import Speech

final class SettingsWindow: NSWindowController {
    private var hotkeyRecorder: HotkeyRecorderView?
    weak var hotkeyManager: HotkeyManager?

    convenience init() {
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 640),
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

        let diagnosticsTab = NSTabViewItem(identifier: "diagnostics")
        diagnosticsTab.label = "诊断"
        diagnosticsTab.view = makeDiagnosticsView()
        tabView.addTabViewItem(diagnosticsTab)
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
    private var llmModePopup: NSPopUpButton?
    private var llmPunctuationCheck: NSButton?
    private var llmSentenceBreakCheck: NSButton?
    private var llmFillerWordsCheck: NSButton?
    private var llmCustomRulesTextView: NSTextView?
    private var llmGlossaryTextView: NSTextView?
    private var llmPreviewInputTextView: NSTextView?
    private var llmPreviewOutputLabel: NSTextField?

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

        let modeLabel = makeLabel("纠错强度:")
        let modePopup = NSPopUpButton()
        modePopup.translatesAutoresizingMaskIntoConstraints = false
        modePopup.addItems(withTitles: LLMCorrectionMode.allCases.map(\.displayName))
        if let index = LLMCorrectionMode.allCases.firstIndex(of: Preferences.shared.llmCorrectionMode) {
            modePopup.selectItem(at: index)
        }
        modePopup.widthAnchor.constraint(equalToConstant: 280).isActive = true
        self.llmModePopup = modePopup

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

        let customRulesLabel = makeLabel("附加保守规则:")
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
        customRulesScroll.heightAnchor.constraint(equalToConstant: 54).isActive = true

        let glossaryLabel = makeLabel("术语词典:")
        let glossaryTextView = NSTextView()
        glossaryTextView.string = Preferences.shared.llmGlossary
        glossaryTextView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        glossaryTextView.isRichText = false
        glossaryTextView.allowsUndo = true
        glossaryTextView.textContainerInset = NSSize(width: 6, height: 6)
        self.llmGlossaryTextView = glossaryTextView

        let glossaryScroll = NSScrollView()
        glossaryScroll.translatesAutoresizingMaskIntoConstraints = false
        glossaryScroll.hasVerticalScroller = true
        glossaryScroll.borderType = .bezelBorder
        glossaryScroll.documentView = glossaryTextView
        glossaryScroll.widthAnchor.constraint(equalToConstant: 280).isActive = true
        glossaryScroll.heightAnchor.constraint(equalToConstant: 78).isActive = true

        let previewLabel = makeLabel("测试纠错:")
        let previewInputTextView = NSTextView()
        previewInputTextView.string = "今天我们用配森处理 JSON 数据，接口是 https://example.com/v1。"
        previewInputTextView.font = .systemFont(ofSize: 12)
        previewInputTextView.isRichText = false
        previewInputTextView.allowsUndo = true
        previewInputTextView.textContainerInset = NSSize(width: 6, height: 6)
        self.llmPreviewInputTextView = previewInputTextView

        let previewInputScroll = NSScrollView()
        previewInputScroll.translatesAutoresizingMaskIntoConstraints = false
        previewInputScroll.hasVerticalScroller = true
        previewInputScroll.borderType = .bezelBorder
        previewInputScroll.documentView = previewInputTextView
        previewInputScroll.widthAnchor.constraint(equalToConstant: 280).isActive = true
        previewInputScroll.heightAnchor.constraint(equalToConstant: 56).isActive = true

        let previewOutputLabel = makeLabel("")
        previewOutputLabel.textColor = .secondaryLabelColor
        previewOutputLabel.lineBreakMode = .byWordWrapping
        previewOutputLabel.maximumNumberOfLines = 3
        previewOutputLabel.widthAnchor.constraint(equalToConstant: 280).isActive = true
        self.llmPreviewOutputLabel = previewOutputLabel

        let previewStack = NSStackView(views: [previewInputScroll, previewOutputLabel])
        previewStack.orientation = .vertical
        previewStack.alignment = .leading
        previewStack.spacing = 6

        let saveBtn = NSButton(title: "保存", target: self, action: #selector(saveLLMConfig))
        saveBtn.keyEquivalent = "\r"
        let testBtn = NSButton(title: "测试连接", target: self, action: #selector(testLLMConnection))
        let previewBtn = NSButton(title: "测试纠错", target: self, action: #selector(testLLMCorrection))

        let statusLabel = makeLabel("")
        statusLabel.textColor = .secondaryLabelColor
        self.llmStatusLabel = statusLabel

        let btnStack = NSStackView(views: [saveBtn, testBtn, previewBtn, statusLabel])
        btnStack.spacing = 12

        grid.addRow(with: [urlLabel, urlField])
        grid.addRow(with: [keyLabel, keyField])
        grid.addRow(with: [modelLabel, modelField])
        grid.addRow(with: [modeLabel, modePopup])
        grid.addRow(with: [rulesLabel, rulesStack])
        grid.addRow(with: [glossaryLabel, glossaryScroll])
        grid.addRow(with: [customRulesLabel, customRulesScroll])
        grid.addRow(with: [previewLabel, previewStack])
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
        if let index = llmModePopup?.indexOfSelectedItem,
           LLMCorrectionMode.allCases.indices.contains(index) {
            Preferences.shared.llmCorrectionMode = LLMCorrectionMode.allCases[index]
        }
        Preferences.shared.llmPunctuationEnabled = llmPunctuationCheck?.state == .on
        Preferences.shared.llmSentenceBreakEnabled = llmSentenceBreakCheck?.state == .on
        Preferences.shared.llmFillerWordsEnabled = llmFillerWordsCheck?.state == .on
        Preferences.shared.llmCustomRules = llmCustomRulesTextView?.string.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        Preferences.shared.llmGlossary = llmGlossaryTextView?.string.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
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

    @objc private func testLLMCorrection() {
        saveLLMConfig()
        let rawText = llmPreviewInputTextView?.string.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !rawText.isEmpty else {
            llmPreviewOutputLabel?.stringValue = "请输入测试文本"
            llmPreviewOutputLabel?.textColor = .systemRed
            return
        }

        llmStatusLabel?.stringValue = "纠错测试中…"
        llmStatusLabel?.textColor = .secondaryLabelColor
        llmPreviewOutputLabel?.stringValue = "等待模型返回…"
        llmPreviewOutputLabel?.textColor = .secondaryLabelColor

        LLMRefiner().refineDecision(rawText) { [weak self] decision in
            DispatchQueue.main.async {
                self?.llmStatusLabel?.stringValue = decision.accepted ? "纠错已接受 ✓" : "已回退原文"
                self?.llmStatusLabel?.textColor = decision.accepted ? .systemGreen : .systemOrange
                self?.llmPreviewOutputLabel?.stringValue = "\(decision.reason)\n\(decision.text)"
                self?.llmPreviewOutputLabel?.textColor = decision.accepted ? .labelColor : .secondaryLabelColor
            }
        }
    }

    // MARK: - Diagnostics Tab

    private var diagnosticsRows: [String: NSTextField] = [:]

    private func makeDiagnosticsView() -> NSView {
        let container = NSView()

        let grid = NSGridView()
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.columnSpacing = 12
        grid.rowSpacing = 12
        container.addSubview(grid)

        addDiagnosticsRow(to: grid, key: "microphone", title: "麦克风权限")
        addDiagnosticsRow(to: grid, key: "accessibility", title: "辅助功能权限")
        addDiagnosticsRow(to: grid, key: "speech", title: "Apple Speech")
        addDiagnosticsRow(to: grid, key: "backend", title: "当前识别后端")
        addDiagnosticsRow(to: grid, key: "whisper", title: "Whisper HTTP")
        addDiagnosticsRow(to: grid, key: "llm", title: "LLM 连接")
        addDiagnosticsRow(to: grid, key: "last", title: "上一条转写")

        let refreshButton = NSButton(title: "刷新", target: self, action: #selector(refreshDiagnostics))
        refreshButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(refreshButton)

        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: container.topAnchor, constant: 24),
            grid.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 24),
            grid.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -24),

            refreshButton.topAnchor.constraint(equalTo: grid.bottomAnchor, constant: 18),
            refreshButton.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 24),
        ])

        grid.column(at: 0).xPlacement = .trailing
        refreshDiagnostics()

        return container
    }

    private func addDiagnosticsRow(to grid: NSGridView, key: String, title: String) {
        let titleLabel = makeLabel(title + ":")
        let valueLabel = makeLabel("待检查")
        valueLabel.textColor = .secondaryLabelColor
        valueLabel.lineBreakMode = .byWordWrapping
        valueLabel.maximumNumberOfLines = 2
        valueLabel.widthAnchor.constraint(equalToConstant: 390).isActive = true
        diagnosticsRows[key] = valueLabel
        grid.addRow(with: [titleLabel, valueLabel])
    }

    @objc private func refreshDiagnostics() {
        updateDiagnosticsRow("microphone", microphoneStatus())
        updateDiagnosticsRow("accessibility", PermissionManager.checkAccessibility(prompt: false) ? "已授权" : "未授权")
        updateDiagnosticsRow("speech", speechStatus())
        updateDiagnosticsRow("backend", Preferences.shared.sttBackend.rawValue)
        updateDiagnosticsRow("last", LastTranscriptionStore.shared.latest == nil ? "无" : "有")
        checkWhisperDiagnostics()
        checkLLMDiagnostics()
    }

    private func updateDiagnosticsRow(_ key: String, _ value: String, color: NSColor = .secondaryLabelColor) {
        diagnosticsRows[key]?.stringValue = value
        diagnosticsRows[key]?.textColor = color
    }

    private func microphoneStatus() -> String {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return "已授权"
        case .notDetermined:
            return "未请求"
        case .denied:
            return "已拒绝"
        case .restricted:
            return "受限制"
        @unknown default:
            return "未知"
        }
    }

    private func speechStatus() -> String {
        let authorization: String
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            authorization = "已授权"
        case .notDetermined:
            authorization = "未请求"
        case .denied:
            authorization = "已拒绝"
        case .restricted:
            authorization = "受限制"
        @unknown default:
            authorization = "未知"
        }

        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: Preferences.shared.language))
        let availability = recognizer?.isAvailable == true ? "可用" : "不可用"
        return "\(authorization)，\(availability)"
    }

    private func checkWhisperDiagnostics() {
        updateDiagnosticsRow("whisper", "检查中…")
        guard let url = URL(string: Preferences.shared.whisperEndpoint + "/v1/models") else {
            updateDiagnosticsRow("whisper", "URL 格式错误", color: .systemRed)
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        WhisperTranscriber.setAuthorizationHeader(on: &request, apiKey: Preferences.shared.whisperAPIKey)

        URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
            DispatchQueue.main.async {
                if let error {
                    self?.updateDiagnosticsRow("whisper", "连接失败: \(error.localizedDescription)", color: .systemRed)
                    return
                }
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                self?.updateDiagnosticsRow(
                    "whisper",
                    "HTTP \(code) \(code > 0 && code < 400 ? "✓" : "✗")",
                    color: code > 0 && code < 400 ? .systemGreen : .systemRed
                )
            }
        }.resume()
    }

    private func checkLLMDiagnostics() {
        updateDiagnosticsRow("llm", Preferences.shared.llmBaseURL.isEmpty ? "未配置" : "检查中…")
        guard !Preferences.shared.llmBaseURL.isEmpty else { return }

        LLMRefiner().testConnection { [weak self] success, message in
            DispatchQueue.main.async {
                self?.updateDiagnosticsRow("llm", message, color: success ? .systemGreen : .systemRed)
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
