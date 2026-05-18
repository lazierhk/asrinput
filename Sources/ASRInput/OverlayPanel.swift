import Cocoa
import OverlayHUDCore

final class OverlayPanel: NSPanel {
    private let visualEffect = NSVisualEffectView()
    private(set) var waveformView = WaveformView()
    private let textLabel = NSTextField(labelWithString: "")

    private let metrics = OverlayHUDMetrics()
    private var panelHeight: CGFloat { CGFloat(metrics.panelHeight) }
    private var bottomMargin: CGFloat { CGFloat(metrics.bottomMargin) }
    private var hPadding: CGFloat { CGFloat(metrics.horizontalPadding) }
    private var waveformWidth: CGFloat { CGFloat(metrics.waveformWidth) }
    private var waveGap: CGFloat { CGFloat(metrics.waveGap) }

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
        contentView = visualEffect

        waveformView.translatesAutoresizingMaskIntoConstraints = false
        textLabel.translatesAutoresizingMaskIntoConstraints = false

        textLabel.textColor = NSColor.white
        textLabel.font = NSFont.systemFont(ofSize: 15, weight: .medium)
        textLabel.lineBreakMode = .byTruncatingTail
        textLabel.maximumNumberOfLines = 1
        textLabel.cell?.usesSingleLineMode = true
        textLabel.alignment = .left

        visualEffect.addSubview(waveformView)
        visualEffect.addSubview(textLabel)

        NSLayoutConstraint.activate([
            waveformView.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor, constant: hPadding),
            waveformView.centerYAnchor.constraint(equalTo: visualEffect.centerYAnchor),
            waveformView.widthAnchor.constraint(equalToConstant: waveformWidth),
            waveformView.heightAnchor.constraint(equalToConstant: 40),

            textLabel.leadingAnchor.constraint(equalTo: waveformView.trailingAnchor, constant: waveGap),
            textLabel.centerYAnchor.constraint(equalTo: visualEffect.centerYAnchor),
            textLabel.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor, constant: -hPadding),
        ])
    }

    func show() {
        let initialText = "正在聆听…"
        textLabel.stringValue = initialText
        guard let screen = screenForPlacement() else { return }
        let textWidth = clampedTextWidth(initialText)
        let panelWidth = self.panelWidth(textWidth: textWidth)
        let x = centeredX(panelWidth: panelWidth, screen: screen)
        let targetY = screen.visibleFrame.origin.y + bottomMargin
        let startY = targetY - 20

        setFrame(NSRect(x: x, y: startY, width: panelWidth, height: panelHeight), display: false)
        alphaValue = 0
        orderFrontRegardless()
        waveformView.startAnimating()

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
            let newWidth = self.clampedTextWidth(self.textLabel.stringValue)
            let newPanelWidth = self.panelWidth(textWidth: newWidth)
            guard let screen = self.screenForPlacement() else { return }
            let x = self.centeredX(panelWidth: newPanelWidth, screen: screen)
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.28
                ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.18, 0.89, 0.32, 1.18)
                self.animator().setFrame(
                    NSRect(
                        x: x,
                        y: screen.visibleFrame.origin.y + self.bottomMargin,
                        width: newPanelWidth,
                        height: self.panelHeight
                    ),
                    display: true
                )
            }
        }
    }

    func showRefining() {
        updateText("优化中…")
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
        })
    }

    private func clampedTextWidth(_ text: String) -> CGFloat {
        let fontSize = textLabel.font?.pointSize ?? NSFont.systemFontSize
        let sampledText = text.prefix(120)
        let weightedUnits = sampledText.reduce(0.0) { total, character in
            total + (character.isASCII ? 0.58 : 1.0)
        }
        let natural = weightedUnits * Double(fontSize) + 8
        return CGFloat(
            OverlayHUDLayout.textWidth(
                naturalWidth: Double(natural),
                metrics: metrics
            )
        )
    }

    private func panelWidth(textWidth: CGFloat) -> CGFloat {
        CGFloat(
            OverlayHUDLayout.panelWidth(
                textWidth: Double(textWidth),
                metrics: metrics
            )
        )
    }

    private func screenForPlacement() -> NSScreen? {
        screen ?? NSScreen.main ?? NSScreen.screens.first
    }

    private func centeredX(panelWidth: CGFloat, screen: NSScreen) -> CGFloat {
        screen.visibleFrame.origin.x + (screen.visibleFrame.width - panelWidth) / 2
    }
}
