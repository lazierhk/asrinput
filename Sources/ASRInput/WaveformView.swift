import Cocoa

final class WaveformView: NSView {
    var inputLevel: Float = 0

    private let weights: [CGFloat] = [0.5, 0.8, 1.0, 0.75, 0.55]
    private var bars: [CGFloat] = Array(repeating: 0, count: 5)
    private var timer: Timer?

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) { fatalError() }

    func startAnimating() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.current.add(timer!, forMode: .common)
    }

    func stopAnimating() {
        timer?.invalidate()
        timer = nil
        bars = Array(repeating: 0, count: 5)
        needsDisplay = true
    }

    private func tick() {
        for i in 0..<5 {
            let jitter = CGFloat.random(in: -0.04...0.04)
            let raw = CGFloat(inputLevel) * weights[i] + jitter
            let target = max(0, min(1, raw))
            let alpha: CGFloat = target > bars[i] ? 0.40 : 0.15
            bars[i] += alpha * (target - bars[i])
        }
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard NSGraphicsContext.current?.cgContext != nil else { return }

        let totalBars = 5
        let barWidth: CGFloat = 4
        let gap: CGFloat = 4
        let minH: CGFloat = 4
        let maxH: CGFloat = 32
        let cornerRadius: CGFloat = 1.5

        let totalWidth = CGFloat(totalBars) * barWidth + CGFloat(totalBars - 1) * gap
        let startX = (bounds.width - totalWidth) / 2

        NSColor.white.withAlphaComponent(0.9).setFill()

        for i in 0..<totalBars {
            let barH = minH + bars[i] * (maxH - minH)
            let x = startX + CGFloat(i) * (barWidth + gap)
            let y = (bounds.height - barH) / 2
            let rect = CGRect(x: x, y: y, width: barWidth, height: barH)
            let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
            path.fill()
        }
    }
}
