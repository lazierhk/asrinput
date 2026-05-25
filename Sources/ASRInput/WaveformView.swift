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

    private let weights: [CGFloat] = (0..<48).map { index in
        let center = CGFloat(47) / 2
        let distance = abs(CGFloat(index) - center) / center
        let ripple = 0.12 * sin(CGFloat(index) * 0.92)
        return max(0.34, 1.0 - 0.48 * distance + ripple)
    }
    private var bars: [CGFloat] = Array(repeating: 0, count: 48)
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
        let refiningPulse = mode == .refining ? 0.14 + 0.08 * sin(time * 2.0) : 0

        for i in 0..<weights.count {
            let phase = Double(i) * 0.46
            let idleDepth: CGFloat = reduceMotion ? 0.001 : 0.002
            let idleBase: CGFloat = reduceMotion ? 0.003 : 0.005
            let idlePulse = idleBase + idleDepth * sin(time * 2.7 + phase)
            let modePulse = CGFloat(refiningPulse) * weights[i] * (reduceMotion ? 0.42 : 0.72)
            let jitterRange = reduceMotion ? 0 : 0.002 + 0.010 * voiceLevel
            let jitter = CGFloat.random(in: -jitterRange...jitterRange)
            let raw = idlePulse + max(voiceLevel, modePulse) * weights[i] + jitter
            let target = max(0.001, min(1, raw))
            let alpha: CGFloat = target > bars[i] ? 0.72 : 0.26
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
        let barWidth: CGFloat = 2.4
        let gap: CGFloat = 3.0
        let minH: CGFloat = 1.2
        let maxH: CGFloat = max(12, bounds.height - 6)
        let cornerRadius: CGFloat = 1.2
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let isRefining = mode == .refining

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
            let glowAlpha = (reduceMotion ? 0.10 : 0.16) + 0.34 * response
            let fillAlpha = 0.36 + 0.46 * response
            let baseRed: CGFloat = isRefining ? 1.0 : 0.20
            let baseGreen: CGFloat = isRefining ? 0.72 : 0.82
            let baseBlue: CGFloat = isRefining ? 0.28 : 1.0

            ctx.saveGState()
            ctx.setShadow(
                offset: .zero,
                blur: reduceMotion ? 4 : 6 + 10 * response,
                color: NSColor(calibratedRed: baseRed, green: baseGreen, blue: baseBlue, alpha: glowAlpha).cgColor
            )
            NSColor(
                calibratedRed: min(1, baseRed + 0.14 * centerBoost),
                green: min(1, baseGreen + 0.10 * centerBoost),
                blue: min(1, baseBlue + 0.08 * centerBoost),
                alpha: fillAlpha
            ).setFill()
            path.fill()
            ctx.restoreGState()

            NSColor(calibratedWhite: 1.0, alpha: 0.26 + 0.18 * response).setFill()
            let highlight = rect.insetBy(dx: 0.7, dy: 1.2)
            if highlight.width > 0, highlight.height > 0 {
                NSBezierPath(roundedRect: highlight, xRadius: 0.7, yRadius: 0.7).fill()
            }
        }
    }

    private func drawCenterGlow(in ctx: CGContext) {
        let glowRect = bounds.insetBy(dx: 6, dy: bounds.height * 0.28)
        let path = NSBezierPath(roundedRect: glowRect, xRadius: glowRect.height / 2, yRadius: glowRect.height / 2)
        let isRefining = mode == .refining
        let red: CGFloat = isRefining ? 1.0 : 0.12
        let green: CGFloat = isRefining ? 0.68 : 0.72
        let blue: CGFloat = isRefining ? 0.24 : 1.0

        ctx.saveGState()
        ctx.setShadow(
            offset: .zero,
            blur: 16,
            color: NSColor(calibratedRed: red, green: green, blue: blue, alpha: 0.14).cgColor
        )
        NSColor(calibratedRed: red, green: green, blue: blue, alpha: 0.030).setFill()
        path.fill()
        ctx.restoreGState()

        NSColor(calibratedWhite: 1.0, alpha: 0.06).setStroke()
        path.lineWidth = 0.6
        path.stroke()
    }
}
