import AppKit
import Foundation

struct IconImage {
    let filename: String
    let size: Int
}

let icons = [
    IconImage(filename: "icon_16x16.png", size: 16),
    IconImage(filename: "icon_16x16@2x.png", size: 32),
    IconImage(filename: "icon_32x32.png", size: 32),
    IconImage(filename: "icon_32x32@2x.png", size: 64),
    IconImage(filename: "icon_128x128.png", size: 128),
    IconImage(filename: "icon_128x128@2x.png", size: 256),
    IconImage(filename: "icon_256x256.png", size: 256),
    IconImage(filename: "icon_256x256@2x.png", size: 512),
    IconImage(filename: "icon_512x512.png", size: 512),
    IconImage(filename: "icon_512x512@2x.png", size: 1024)
]

guard CommandLine.arguments.count == 3 else {
    FileHandle.standardError.write(Data("Usage: MakeIcon <source.png> <output.iconset>\n".utf8))
    exit(64)
}

let sourceURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])

guard let source = NSImage(contentsOf: sourceURL) else {
    FileHandle.standardError.write(Data("Could not read source image: \(sourceURL.path)\n".utf8))
    exit(66)
}

try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

for icon in icons {
    let pixelSize = NSSize(width: icon.size, height: icon.size)
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: icon.size,
        pixelsHigh: icon.size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        FileHandle.standardError.write(Data("Could not create bitmap for \(icon.filename)\n".utf8))
        exit(70)
    }

    rep.size = pixelSize
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSColor.clear.setFill()
    NSRect(origin: .zero, size: pixelSize).fill()
    source.draw(
        in: NSRect(origin: .zero, size: pixelSize),
        from: .zero,
        operation: .sourceOver,
        fraction: 1.0
    )
    NSGraphicsContext.restoreGraphicsState()

    guard let png = rep.representation(using: .png, properties: [:]) else {
        FileHandle.standardError.write(Data("Could not encode \(icon.filename)\n".utf8))
        exit(70)
    }

    try png.write(to: outputURL.appendingPathComponent(icon.filename), options: .atomic)
}
