import Cocoa
import OverlayHUDCore

final class OverlayPanel: NSPanel {
    private let visualEffect = NSVisualEffectView()
    private let glassStrokeView = GlassStrokeView()
    private let statusView = RecorderStatusView()
    private let waveformView = WaveformView()
    private let statusLabel = NSTextField(labelWithString: "")

    private let metrics = OverlayHUDMetrics()
    private let panelWidth: CGFloat = 392
    private let hudHeight: CGFloat = 64
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
        statusView.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.textColor = NSColor(calibratedWhite: 1.0, alpha: 0.78)
        statusLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        statusLabel.lineBreakMode = .byClipping
        statusLabel.maximumNumberOfLines = 1
        statusLabel.cell?.usesSingleLineMode = true
        statusLabel.alignment = .right

        visualEffect.addSubview(statusView)
        visualEffect.addSubview(waveformView)
        visualEffect.addSubview(statusLabel)
        visualEffect.addSubview(glassStrokeView)

        NSLayoutConstraint.activate([
            glassStrokeView.topAnchor.constraint(equalTo: visualEffect.topAnchor),
            glassStrokeView.bottomAnchor.constraint(equalTo: visualEffect.bottomAnchor),
            glassStrokeView.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor),
            glassStrokeView.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor),

            statusView.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor, constant: 20),
            statusView.centerYAnchor.constraint(equalTo: visualEffect.centerYAnchor),
            statusView.widthAnchor.constraint(equalToConstant: 34),
            statusView.heightAnchor.constraint(equalToConstant: 34),

            statusLabel.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor, constant: -22),
            statusLabel.centerYAnchor.constraint(equalTo: visualEffect.centerYAnchor),
            statusLabel.widthAnchor.constraint(equalToConstant: 58),

            waveformView.leadingAnchor.constraint(equalTo: statusView.trailingAnchor, constant: 16),
            waveformView.trailingAnchor.constraint(equalTo: statusLabel.leadingAnchor, constant: -16),
            waveformView.centerYAnchor.constraint(equalTo: visualEffect.centerYAnchor),
            waveformView.heightAnchor.constraint(equalToConstant: 42),
        ])
    }

    func show() {
        let initialText = "正在聆听…"
        statusLabel.stringValue = "听写中"
        guard let screen = screenForPlacement() else { return }
        let x = centeredX(panelWidth: panelWidth, screen: screen)
        let targetY = screen.visibleFrame.origin.y + bottomMargin
        let startY = targetY - 20

        setFrame(NSRect(x: x, y: startY, width: panelWidth, height: panelHeight), display: false)
        alphaValue = 0
        orderFrontRegardless()
        waveformView.mode = .listening
        statusView.mode = .listening
        waveformView.startAnimating()
        statusView.startAnimating()
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
            self.statusLabel.stringValue = self.waveformView.mode == .refining ? "优化中" : "听写中"
            self.setAccessibilityLabel(displayText.isEmpty ? "正在聆听…" : displayText)
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
            self.statusView.mode = .refining
            self.statusLabel.stringValue = "优化中"
            self.updateText("优化中…")
        }
    }

    func dismiss() {
        waveformView.stopAnimating()
        statusView.stopAnimating()
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.22
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            animator().alphaValue = 0
            var f = frame
            f = f.insetBy(dx: 4, dy: 2)
            animator().setFrame(f, display: true)
        }, completionHandler: {
            self.orderOut(nil)
            self.statusLabel.stringValue = ""
            self.alphaValue = 0
            self.waveformView.mode = .listening
            self.statusView.mode = .listening
        })
    }

    private func screenForPlacement() -> NSScreen? {
        screen ?? NSScreen.main ?? NSScreen.screens.first
    }

    private func centeredX(panelWidth: CGFloat, screen: NSScreen) -> CGFloat {
        screen.visibleFrame.origin.x + (screen.visibleFrame.width - panelWidth) / 2
    }
}

private final class RecorderStatusView: NSView {
    var mode: WaveformMode = .listening {
        didSet { needsDisplay = true }
    }

    private var pulse: CGFloat = 0
    private var timer: Timer?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) { fatalError() }

    func startAnimating() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            let time = Date().timeIntervalSinceReferenceDate
            self.pulse = CGFloat((sin(time * 3.0) + 1) / 2)
            self.needsDisplay = true
        }
        RunLoop.current.add(timer!, forMode: .common)
    }

    func stopAnimating() {
        timer?.invalidate()
        timer = nil
        pulse = 0
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        let isRefining = mode == .refining
        let color = isRefining
            ? NSColor(calibratedRed: 1.0, green: 0.76, blue: 0.30, alpha: 1)
            : NSColor(calibratedRed: 0.20, green: 0.90, blue: 1.0, alpha: 1)

        let outer = bounds.insetBy(dx: 1.5, dy: 1.5)
        let inner = bounds.insetBy(dx: 8, dy: 8)

        ctx.saveGState()
        ctx.setShadow(
            offset: .zero,
            blur: 10 + 8 * pulse,
            color: color.withAlphaComponent(0.32 + 0.16 * pulse).cgColor
        )
        color.withAlphaComponent(0.12 + 0.08 * pulse).setFill()
        NSBezierPath(ovalIn: outer).fill()
        ctx.restoreGState()

        color.withAlphaComponent(0.92).setFill()
        NSBezierPath(ovalIn: inner).fill()

        NSColor.white.withAlphaComponent(0.88).setStroke()
        let micPath = NSBezierPath()
        let midX = bounds.midX
        let topY = bounds.midY - 5
        let bottomY = bounds.midY + 5
        micPath.lineWidth = 1.7
        micPath.lineCapStyle = .round
        micPath.move(to: CGPoint(x: midX, y: topY))
        micPath.line(to: CGPoint(x: midX, y: bottomY))
        micPath.stroke()

        let arcRect = CGRect(x: midX - 6, y: bounds.midY - 1, width: 12, height: 10)
        let arc = NSBezierPath()
        arc.appendArc(
            withCenter: CGPoint(x: arcRect.midX, y: arcRect.minY),
            radius: 6,
            startAngle: 200,
            endAngle: 340
        )
        arc.lineWidth = 1.5
        arc.lineCapStyle = .round
        arc.stroke()
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
