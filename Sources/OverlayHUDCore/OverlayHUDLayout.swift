import Foundation

public struct OverlayHUDMetrics {
    public var panelHeight: Double
    public var bottomMargin: Double
    public var horizontalPadding: Double
    public var waveformWidth: Double
    public var waveGap: Double
    public var minTextWidth: Double
    public var maxTextWidth: Double

    public init(
        panelHeight: Double = 56,
        bottomMargin: Double = 80,
        horizontalPadding: Double = 18,
        waveformWidth: Double = 48,
        waveGap: Double = 12,
        minTextWidth: Double = 132,
        maxTextWidth: Double = 640
    ) {
        self.panelHeight = panelHeight
        self.bottomMargin = bottomMargin
        self.horizontalPadding = horizontalPadding
        self.waveformWidth = waveformWidth
        self.waveGap = waveGap
        self.minTextWidth = minTextWidth
        self.maxTextWidth = maxTextWidth
    }
}

public enum OverlayHUDLayout {
    public static func textWidth(naturalWidth: Double, metrics: OverlayHUDMetrics) -> Double {
        max(metrics.minTextWidth, min(metrics.maxTextWidth, naturalWidth))
    }

    public static func panelWidth(textWidth: Double, metrics: OverlayHUDMetrics) -> Double {
        metrics.horizontalPadding + metrics.waveformWidth + metrics.waveGap + textWidth + metrics.horizontalPadding
    }
}
