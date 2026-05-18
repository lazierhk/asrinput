#!/usr/bin/env swift
import Foundation
import ImageIO

let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"
let sourcePath = "Sources/ASRInput/Resources/AppIconSource.png"

let fileManager = FileManager.default
guard fileManager.fileExists(atPath: sourcePath) else {
    fputs("Missing icon source: \(sourcePath)\n", stderr)
    exit(1)
}

let sourceURL = URL(fileURLWithPath: sourcePath)
guard let imageSource = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
      let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
      let width = properties[kCGImagePropertyPixelWidth] as? Int,
      let height = properties[kCGImagePropertyPixelHeight] as? Int
else {
    fputs("Failed to inspect icon source: \(sourcePath)\n", stderr)
    exit(1)
}

guard width == 1024, height == 1024 else {
    fputs("Icon source must be 1024x1024, got \(width)x\(height): \(sourcePath)\n", stderr)
    exit(1)
}

let outputURL = URL(fileURLWithPath: outputPath)
let outputDir = outputURL.deletingLastPathComponent()
try? fileManager.createDirectory(at: outputDir, withIntermediateDirectories: true)
try? fileManager.removeItem(at: outputURL)

do {
    try fileManager.copyItem(at: sourceURL, to: outputURL)
    print("Icon written to \(outputPath)")
} catch {
    fputs("Failed to write icon: \(error.localizedDescription)\n", stderr)
    exit(1)
}
