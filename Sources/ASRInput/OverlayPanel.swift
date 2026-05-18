import Cocoa
import OverlayHUDCore

final class OverlayPanel: NSPanel {
    private let visualEffect = NSVisualEffectView()
    private let glassStrokeView = GlassStrokeView()
    private let waveformView = WaveformView()
    private let textLabel = NSTextField(labelWithString: "")

    private let metrics = OverlayHUDMetrics()
    private let panelWidth: CGFloat = 316
    private let hudHeight: CGFloat = 70
    private var panelHeight: CGFloat { hudHeight }
    private var bottomMargin: CGFloat { CGFloat(metrics.bottomMargin) }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 56),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        setupPanel()
        setupContent()
    }

    private func setupPanel() {
        level = .screenSaver
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        worksWhenModal = true
        alphaValue = 0
    }

    private func setupContent() {
        visualEffect.material = .hudWindow
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = panelHeight / 2
        visualEffect.layer?.masksToBounds = true
        visualEffect.layer?.backgroundColor = NSColor(calibratedWhite: 1, alpha: 0.09).cgColor
        contentView = visualEffect

        glassStrokeView.translatesAutoresizingMaskIntoConstraints = false
        waveformView.translatesAutoresizingMaskIntoConstraints = false
        textLabel.translatesAutoresizingMaskIntoConstraints = false

        textLabel.textColor = NSColor.white
        textLabel.font = NSFont.systemFont(ofSize: 1, weight: .regular)
        textLabel.lineBreakMode = .byTruncatingTail
        textLabel.maximumNumberOfLines = 1
        textLabel.cell?.usesSingleLineMode = true
        textLabel.alignment = .left
        textLabel.isHidden = true

        visualEffect.addSubview(waveformView)
        visualEffect.addSubview(textLabel)
        visualEffect.addSubview(glassStrokeView)

        NSLayoutConstraint.activate([
            glassStrokeView.topAnchor.constraint(equalTo: visualEffect.topAnchor),
            glassStrokeView.bottomAnchor.constraint(equalTo: visualEffect.bottomAnchor),
            glassStrokeView.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor),
            glassStrokeView.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor),

            waveformView.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor, constant: 24),
            waveformView.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor, constant: -24),
            waveformView.centerYAnchor.constraint(equalTo: visualEffect.centerYAnchor),
            waveformView.heightAnchor.constraint(equalToConstant: 50),

            textLabel.widthAnchor.constraint(equalToConstant: 1),
            textLabel.heightAnchor.constraint(equalToConstant: 1),
            textLabel.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor),
            textLabel.bottomAnchor.constraint(equalTo: visualEffect.bottomAnchor),
        ])
    }

    func show() {
        let initialText = "正在聆听…"
        textLabel.stringValue = initialText
        guard let screen = screenForPlacement() else { return }
        let x = centeredX(panelWidth: panelWidth, screen: screen)
        let targetY = screen.visibleFrame.origin.y + bottomMargin
        let startY = targetY - 20

        setFrame(NSRect(x: x, y: startY, width: panelWidth, height: panelHeight), display: false)
        alphaValue = 0
        orderFrontRegardless()
        waveformView.mode = .listening
        waveformView.startAnimating()
        setAccessibilityLabel(initialText)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.35
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().alphaValue = 1
            animator().setFrame(
                NSRect(x: x, y: targetY, width: panelWidth, height: panelHeight),
                display: true
            )
        }
    }

    func updateText(_ text: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isVisible else { return }
            let displayText = text.trimmingCharacters(in: .whitespacesAndNewlines)
            self.textLabel.stringValue = displayText.isEmpty ? "正在聆听…" : displayText
            self.setAccessibilityLabel(self.textLabel.stringValue)
        }
    }

    func updateLevel(_ level: Float) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isVisible else { return }
            self.waveformView.inputLevel = level
        }
    }

    func showRefining() {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isVisible else { return }
            self.waveformView.mode = .refining
            self.updateText("优化中…")
        }
    }

    func dismiss() {
        waveformView.stopAnimating()
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.22
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            animator().alphaValue = 0
            var f = frame
            f = f.insetBy(dx: 4, dy: 2)
            animator().setFrame(f, display: true)
        }, completionHandler: {
            self.orderOut(nil)
            self.textLabel.stringValue = ""
            self.alphaValue = 0
            self.waveformView.mode = .listening
        })
    }

    private func screenForPlacement() -> NSScreen? {
        screen ?? NSScreen.main ?? NSScreen.screens.first
    }

    private func centeredX(panelWidth: CGFloat, screen: NSScreen) -> CGFloat {
        screen.visibleFrame.origin.x + (screen.visibleFrame.width - panelWidth) / 2
    }
}

private final class GlassStrokeView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 0.75, dy: 0.75)
        let radius = rect.height / 2
        let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

        NSColor(calibratedWhite: 1.0, alpha: 0.15).setFill()
        path.fill()

        NSColor(calibratedWhite: 1.0, alpha: 0.34).setStroke()
        path.lineWidth = 1.2
        path.stroke()

        let highlightRect = rect.insetBy(dx: 8, dy: 4)
        let highlightPath = NSBezierPath(roundedRect: highlightRect, xRadius: highlightRect.height / 2, yRadius: highlightRect.height / 2)
        NSColor(calibratedWhite: 1.0, alpha: 0.10).setStroke()
        highlightPath.lineWidth = 1
        highlightPath.stroke()
    }
}
