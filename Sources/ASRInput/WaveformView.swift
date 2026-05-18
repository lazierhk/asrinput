import Cocoa

enum WaveformMode {
    case listening
    case refining
}

final class WaveformView: NSView {
    var inputLevel: Float = 0
    var mode: WaveformMode = .listening {
        didSet {
            needsDisplay = true
        }
    }

    private let weights: [CGFloat] = [
        0.42, 0.56, 0.76, 0.94, 1.10, 0.84, 1.18, 0.98, 1.36,
        0.98, 1.18, 0.84, 1.10, 0.94, 0.76, 0.56, 0.42
    ]
    private var bars: [CGFloat] = Array(repeating: 0, count: 17)
    private var timer: Timer?

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) { fatalError() }

    func startAnimating() {
        timer?.invalidate()
        let interval = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 1.0 / 24.0 : 1.0 / 60.0
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.current.add(timer!, forMode: .common)
    }

    func stopAnimating() {
        timer?.invalidate()
        timer = nil
        bars = Array(repeating: 0, count: weights.count)
        needsDisplay = true
    }

    private func tick() {
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let input = max(0, min(1, CGFloat(inputLevel)))
        let voiceLevel = normalizedVoiceLevel(from: input)
        let time = Date().timeIntervalSinceReferenceDate
        let refiningPulse = mode == .refining ? 0.18 + 0.08 * sin(time * 2.0) : 0

        for i in 0..<weights.count {
            let phase = Double(i) * 0.68
            let idleDepth: CGFloat = reduceMotion ? 0.001 : 0.002
            let idleBase: CGFloat = reduceMotion ? 0.002 : 0.003
            let idlePulse = idleBase + idleDepth * sin(time * 3.2 + phase)
            let modePulse = CGFloat(refiningPulse) * weights[i] * (reduceMotion ? 0.42 : 0.72)
            let jitterRange = reduceMotion ? 0 : 0.004 + 0.014 * voiceLevel
            let jitter = CGFloat.random(in: -jitterRange...jitterRange)
            let raw = idlePulse + max(voiceLevel, modePulse) * weights[i] + jitter
            let target = max(0.001, min(1, raw))
            let alpha: CGFloat = target > bars[i] ? 0.82 : 0.34
            bars[i] += alpha * (target - bars[i])
        }
        needsDisplay = true
    }

    private func normalizedVoiceLevel(from input: CGFloat) -> CGFloat {
        let noiseFloor: CGFloat = 0.09
        let fullScale: CGFloat = 0.30
        guard input > noiseFloor else { return 0 }

        let normalized = min(1, (input - noiseFloor) / (fullScale - noiseFloor))
        return pow(normalized, 0.42)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        let totalBars = weights.count
        let barWidth: CGFloat = 6
        let gap: CGFloat = 7
        let minH: CGFloat = 1.2
        let maxH: CGFloat = max(14, bounds.height - 2)
        let cornerRadius: CGFloat = 3
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

        let totalWidth = CGFloat(totalBars) * barWidth + CGFloat(totalBars - 1) * gap
        let startX = (bounds.width - totalWidth) / 2

        drawCenterGlow(in: ctx)

        for i in 0..<totalBars {
            let response = bars[i] < 0.02 ? bars[i] * 0.35 : pow(bars[i], 0.60)
            let barH = minH + response * (maxH - minH)
            let x = startX + CGFloat(i) * (barWidth + gap)
            let y = (bounds.height - barH) / 2
            let rect = CGRect(x: x, y: y, width: barWidth, height: barH)
            let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
            let distanceFromCenter = abs(CGFloat(i) - CGFloat(totalBars - 1) / 2) / (CGFloat(totalBars) / 2)
            let centerBoost = 1 - distanceFromCenter
            let glowAlpha = (reduceMotion ? 0.18 : 0.30) + 0.50 * response
            let fillAlpha = 0.54 + 0.38 * response

            ctx.saveGState()
            ctx.setShadow(
                offset: .zero,
                blur: reduceMotion ? 6 : 9 + 12 * response,
                color: NSColor(calibratedRed: 0.18, green: 0.88, blue: 1.0, alpha: glowAlpha).cgColor
            )
            NSColor(
                calibratedRed: 0.16 + 0.18 * centerBoost,
                green: 0.82 + 0.12 * centerBoost,
                blue: 1.0,
                alpha: fillAlpha
            ).setFill()
            path.fill()
            ctx.restoreGState()

            NSColor(calibratedRed: 0.76, green: 0.98, blue: 1.0, alpha: 0.62 + 0.24 * response).setFill()
            let highlight = rect.insetBy(dx: 1.5, dy: 1.4)
            NSBezierPath(roundedRect: highlight, xRadius: 1.1, yRadius: 1.1).fill()
        }
    }

    private func drawCenterGlow(in ctx: CGContext) {
        let glowRect = bounds.insetBy(dx: 5, dy: bounds.height * 0.20)
        let path = NSBezierPath(roundedRect: glowRect, xRadius: glowRect.height / 2, yRadius: glowRect.height / 2)

        ctx.saveGState()
        ctx.setShadow(
            offset: .zero,
            blur: 22,
            color: NSColor(calibratedRed: 0.12, green: 0.72, blue: 1.0, alpha: 0.20).cgColor
        )
        NSColor(calibratedRed: 0.12, green: 0.72, blue: 1.0, alpha: 0.045).setFill()
        path.fill()
        ctx.restoreGState()

        NSColor(calibratedWhite: 1.0, alpha: 0.08).setStroke()
        path.lineWidth = 0.8
        path.stroke()
    }
}
