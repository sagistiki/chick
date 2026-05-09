import Cocoa

// Loads an SVG via NSImage (macOS 13+) and writes a PNG of the requested size.

guard CommandLine.arguments.count == 4 else {
    FileHandle.standardError.write("usage: render_icon <svg> <size> <output.png>\n".data(using: .utf8)!)
    exit(2)
}
let svgPath = CommandLine.arguments[1]
let size = Int(CommandLine.arguments[2]) ?? 0
let outPath = CommandLine.arguments[3]
guard size > 0 else { exit(2) }

let svgURL = URL(fileURLWithPath: svgPath)
guard let svg = NSImage(contentsOf: svgURL) else {
    FileHandle.standardError.write("failed to load svg\n".data(using: .utf8)!)
    exit(1)
}

let dim = NSSize(width: size, height: size)
let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: size,
    pixelsHigh: size,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSGraphicsContext.current?.imageInterpolation = .high
NSColor.clear.setFill()
NSRect(origin: .zero, size: dim).fill()
svg.draw(in: NSRect(origin: .zero, size: dim))
NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("failed to encode png\n".data(using: .utf8)!)
    exit(1)
}
try png.write(to: URL(fileURLWithPath: outPath))
