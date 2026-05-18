#!/usr/bin/env swift
import CoreGraphics
import Foundation
import ImageIO

let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"
let size = 1024
let scale: CGFloat = 1.0

let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(
    data: nil,
    width: size,
    height: size,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    print("Failed to create context")
    exit(1)
}

let w = CGFloat(size)
let h = CGFloat(size)

// Rounded rect clip
let radius = w * 0.2237
let roundedRect = CGRect(x: 0, y: 0, width: w, height: h)
let path = CGPath(roundedRect: roundedRect, cornerWidth: radius, cornerHeight: radius, transform: nil)
ctx.addPath(path)
ctx.clip()

// Background gradient: deep navy → midnight blue
let bgColors: [CGFloat] = [
    0.05, 0.07, 0.18, 1.0,   // top: deep navy
    0.02, 0.03, 0.10, 1.0    // bottom: midnight
]
let bgLocations: [CGFloat] = [0.0, 1.0]
let bgGradient = CGGradient(
    colorSpace: colorSpace,
    colorComponents: bgColors,
    locations: bgLocations,
    count: 2
)!
ctx.drawLinearGradient(
    bgGradient,
    start: CGPoint(x: w / 2, y: h),
    end: CGPoint(x: w / 2, y: 0),
    options: []
)

// Radial glow: indigo center
let glowColors: [CGFloat] = [
    0.25, 0.35, 0.90, 0.45,
    0.10, 0.15, 0.50, 0.15,
    0.05, 0.07, 0.18, 0.0
]
let glowLocations: [CGFloat] = [0.0, 0.45, 1.0]
let glowGradient = CGGradient(
    colorSpace: colorSpace,
    colorComponents: glowColors,
    locations: glowLocations,
    count: 3
)!
let glowCenter = CGPoint(x: w * 0.5, y: h * 0.52)
ctx.drawRadialGradient(
    glowGradient,
    startCenter: glowCenter,
    startRadius: 0,
    endCenter: glowCenter,
    endRadius: w * 0.58,
    options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
)

// Microphone body
ctx.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.96)
let micX = w * 0.385
let micW = w * 0.23
let micH = h * 0.38
let micY = h * 0.30
let micRadius = micW / 2.0
let micRect = CGRect(x: micX, y: micY, width: micW, height: micH)
let micPath = CGPath(roundedRect: micRect, cornerWidth: micRadius, cornerHeight: micRadius, transform: nil)
ctx.addPath(micPath)
ctx.fillPath()

// Microphone stand (stem)
ctx.setLineWidth(w * 0.038)
ctx.setStrokeColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.96)
ctx.setLineCap(.round)

let stemX = w * 0.5
let stemTop = micY - w * 0.022
let stemBottom = h * 0.735
ctx.move(to: CGPoint(x: stemX, y: stemTop))
ctx.addLine(to: CGPoint(x: stemX, y: stemBottom))
ctx.strokePath()

// Base line
ctx.move(to: CGPoint(x: w * 0.36, y: stemBottom))
ctx.addLine(to: CGPoint(x: w * 0.64, y: stemBottom))
ctx.strokePath()

// Curved arc around mic (sound waves) - 3 arcs
let arcCenter = CGPoint(x: w * 0.5, y: micY + micH * 0.44)
let arcColors: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
    (0.38, 0.60, 1.0, 0.85),
    (0.38, 0.60, 1.0, 0.55),
    (0.38, 0.60, 1.0, 0.28)
]
let arcRadii: [CGFloat] = [w * 0.30, w * 0.38, w * 0.46]
let arcLineWidths: [CGFloat] = [w * 0.028, w * 0.022, w * 0.016]
let startAngle = CGFloat.pi * 0.18
let endAngle = CGFloat.pi * 0.82

for i in 0..<3 {
    let (r, g, b, a) = arcColors[i]
    ctx.setStrokeColor(red: r, green: g, blue: b, alpha: a)
    ctx.setLineWidth(arcLineWidths[i])
    ctx.setLineCap(.round)
    ctx.addArc(
        center: arcCenter,
        radius: arcRadii[i],
        startAngle: CGFloat.pi - endAngle,
        endAngle: CGFloat.pi - startAngle,
        clockwise: false
    )
    ctx.strokePath()
}

// Subtle highlight at top
let highlightColors: [CGFloat] = [
    1.0, 1.0, 1.0, 0.08,
    1.0, 1.0, 1.0, 0.0
]
let highlightLocations: [CGFloat] = [0.0, 1.0]
let highlightGradient = CGGradient(
    colorSpace: colorSpace,
    colorComponents: highlightColors,
    locations: highlightLocations,
    count: 2
)!
ctx.drawLinearGradient(
    highlightGradient,
    start: CGPoint(x: w / 2, y: h),
    end: CGPoint(x: w / 2, y: h * 0.6),
    options: []
)

guard let image = ctx.makeImage() else {
    print("Failed to create image")
    exit(1)
}

let url = URL(fileURLWithPath: outputPath)
guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
    print("Failed to create image destination")
    exit(1)
}
CGImageDestinationAddImage(dest, image, nil)
guard CGImageDestinationFinalize(dest) else {
    print("Failed to write image")
    exit(1)
}

print("Icon written to \(outputPath)")
