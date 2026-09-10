import AppKit
import Foundation

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    fatalError("Usage: MakeIconset.swift <source-png> <output-iconset>")
}

let sourcePath = arguments[1]
let iconsetURL = URL(fileURLWithPath: arguments[2], isDirectory: true)
let fileManager = FileManager.default

if fileManager.fileExists(atPath: iconsetURL.path) {
    try fileManager.removeItem(at: iconsetURL)
}
try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

guard let source = NSImage(contentsOfFile: sourcePath) else {
    fatalError("Cannot load source icon: \(sourcePath)")
}
let sourceSize = source.size

let entries: [(name: String, pixels: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for entry in entries {
    guard let canvas = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: entry.pixels,
        pixelsHigh: entry.pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        fatalError("Cannot create icon canvas")
    }

    canvas.size = NSSize(width: entry.pixels, height: entry.pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: canvas)
    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: entry.pixels, height: entry.pixels).fill()

    let scale = min(
        CGFloat(entry.pixels) / sourceSize.width,
        CGFloat(entry.pixels) / sourceSize.height
    )
    let drawWidth = sourceSize.width * scale
    let drawHeight = sourceSize.height * scale
    let drawRect = NSRect(
        x: (CGFloat(entry.pixels) - drawWidth) / 2,
        y: (CGFloat(entry.pixels) - drawHeight) / 2,
        width: drawWidth,
        height: drawHeight
    )
    source.draw(in: drawRect, from: NSRect(origin: .zero, size: sourceSize), operation: .sourceOver, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()

    guard let data = canvas.representation(using: .png, properties: [:]) else {
        fatalError("Cannot render icon PNG")
    }
    try data.write(to: iconsetURL.appendingPathComponent(entry.name))
}
