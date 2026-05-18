import Cocoa

protocol HotkeyRecorderViewDelegate: AnyObject {
    func hotkeyRecorder(_ view: HotkeyRecorderView, didRecord config: HotkeyConfig)
}

final class HotkeyRecorderView: NSView {
    weak var delegate: HotkeyRecorderViewDelegate?

    private(set) var currentConfig: HotkeyConfig
    private var isRecordingKey = false

    private let label = NSTextField(labelWithString: "")
    private let hintLabel = NSTextField(labelWithString: "")

    init(config: HotkeyConfig) {
        self.currentConfig = config
        super.init(frame: NSRect(x: 0, y: 0, width: 200, height: 36))
        setup()
        updateDisplay()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.borderWidth = 1.5
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .medium)
        label.textColor = .labelColor
        label.alignment = .center
        addSubview(label)

        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        hintLabel.font = NSFont.systemFont(ofSize: 10)
        hintLabel.textColor = .secondaryLabelColor
        hintLabel.alignment = .center
        hintLabel.stringValue = "点击录制"
        addSubview(hintLabel)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -6),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 8),

            hintLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            hintLabel.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 1),
        ])
    }

    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool {
        isRecordingKey = true
        layer?.borderColor = NSColor.systemBlue.cgColor
        layer?.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.08).cgColor
        hintLabel.stringValue = "按下快捷键…"
        return super.becomeFirstResponder()
    }

    override func resignFirstResponder() -> Bool {
        isRecordingKey = false
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        hintLabel.stringValue = "点击录制"
        return super.resignFirstResponder()
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        guard isRecordingKey else { return }
        let keyCode = Int(event.keyCode)
        let modifiers = event.modifierFlags.intersection([.shift, .control, .option, .command])

        // Escape cancels recording
        if keyCode == 53 && modifiers.isEmpty {
            window?.makeFirstResponder(nil)
            return
        }

        let cgMods = modifiers.toCGEventFlags()
        let config = HotkeyConfig(kind: .regularKey, keyCode: keyCode, modifiers: cgMods.rawValue)
        currentConfig = config
        updateDisplay()
        delegate?.hotkeyRecorder(self, didRecord: config)
        window?.makeFirstResponder(nil)
    }

    override func flagsChanged(with event: NSEvent) {
        guard isRecordingKey else { return }
        let keyCode = Int(event.keyCode)

        // Fn key
        if keyCode == 63 {
            let fnBit: UInt = 0x800000
            if event.modifierFlags.rawValue & fnBit != 0 {
                let config = HotkeyConfig(kind: .fn, keyCode: 63, modifiers: 0)
                currentConfig = config
                updateDisplay()
                delegate?.hotkeyRecorder(self, didRecord: config)
                window?.makeFirstResponder(nil)
            }
            return
        }

        // Modifier key only pressed (no normal key yet)
        let mods = event.modifierFlags.intersection([.shift, .control, .option, .command])
        if !mods.isEmpty && keyCode != 63 {
            let cgMods = mods.toCGEventFlags()
            let config = HotkeyConfig(kind: .regularKey, keyCode: 0, modifiers: cgMods.rawValue)
            label.stringValue = config.displayString
        }
    }

    func updateConfig(_ config: HotkeyConfig) {
        currentConfig = config
        updateDisplay()
    }

    private func updateDisplay() {
        label.stringValue = currentConfig.displayString
    }
}

private extension NSEvent.ModifierFlags {
    func toCGEventFlags() -> CGEventFlags {
        var flags: CGEventFlags = []
        if contains(.control)  { flags.insert(.maskControl) }
        if contains(.option)   { flags.insert(.maskAlternate) }
        if contains(.shift)    { flags.insert(.maskShift) }
        if contains(.command)  { flags.insert(.maskCommand) }
        return flags
    }
}
