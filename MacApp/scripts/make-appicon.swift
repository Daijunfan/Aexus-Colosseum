#!/usr/bin/env swift
import AppKit
import Foundation

// Builds the Aexus Colosseum app icon from the operator-supplied artwork
// "The Pit AI Arena.png": the square artwork is clipped into a macOS-style
// rounded tile, given a transparent margin, a ground shadow and a hairline
// rim, then exported as a complete .iconset plus .icns.
//
// Usage: swift scripts/make-appicon.swift <art.png> [assets-dir] [resources-dir]

let args = CommandLine.arguments
guard args.count > 1 else {
    FileHandle.standardError.write(Data("usage: make-appicon.swift <art.png> [assets-dir] [resources-dir]\n".utf8))
    exit(2)
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let artURL = URL(fileURLWithPath: args[1])
let assetsDir = URL(fileURLWithPath: args.count > 2 ? args[2] : "Assets")
let resourcesDir = URL(fileURLWithPath: args.count > 3 ? args[3] : "Sources/AexusColosseum/Resources")

guard let art = NSImage(contentsOf: artURL) else {
    FileHandle.standardError.write(Data("could not read \(artURL.path)\n".utf8))
    exit(3)
}

let S: CGFloat = 1024
let space = CGColorSpaceCreateDeviceRGB()

func color(_ white: CGFloat, _ alpha: CGFloat) -> CGColor {
    CGColor(colorSpace: space, components: [white, white, white, alpha])!
}

func aspectFill(_ image: NSImage, in rect: CGRect) {
    let source = image.size
    guard source.width > 0, source.height > 0 else { return }
    let scale = max(rect.width / source.width, rect.height / source.height)
    let size = CGSize(width: source.width * scale, height: source.height * scale)
    let target = CGRect(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2,
                        width: size.width, height: size.height)
    image.draw(in: target, from: .zero, operation: .sourceOver, fraction: 1,
               respectFlipped: false,
               hints: [.interpolation: NSImageInterpolation.high.rawValue])
}

/// Full icon: Apple's macOS grid — 100pt transparent margin, an 824pt tile
/// with a 185pt corner radius. Matching the system grid keeps the Dock icon
/// the same visual size as every other icon (a smaller margin reads as a
/// larger, louder icon).
func drawAppIcon(in ctx: CGContext) {
    ctx.setShouldAntialias(true)
    let tile = CGRect(x: 100, y: 100, width: S - 200, height: S - 200)
    let tilePath = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -16), blur: 46, color: color(0, 0.55))
    ctx.addPath(tilePath)
    ctx.setFillColor(color(0, 1))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(tilePath)
    ctx.clip()
    ctx.setFillColor(color(0, 1))
    ctx.fill(tile)
    aspectFill(art, in: tile)

    // Keep the artwork's edges from meeting the rim flatly at large sizes.
    let vignette = CGGradient(
        colorsSpace: space,
        colors: [color(0, 0), color(0, 0.18)] as CFArray,
        locations: [0.62, 1]
    )!
    ctx.drawRadialGradient(
        vignette,
        startCenter: CGPoint(x: S / 2, y: S / 2), startRadius: 0,
        endCenter: CGPoint(x: S / 2, y: S / 2), endRadius: 560,
        options: [.drawsAfterEndLocation]
    )
    // A soft top-left sheen, like Apple's own dark icons.
    let sheen = CGGradient(
        colorsSpace: space,
        colors: [color(1, 0.055), color(1, 0)] as CFArray,
        locations: [0, 1]
    )!
    ctx.drawLinearGradient(sheen,
                           start: CGPoint(x: tile.minX, y: tile.maxY),
                           end: CGPoint(x: tile.midX, y: tile.midY),
                           options: [])
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(tilePath)
    ctx.setStrokeColor(color(1, 0.12))
    ctx.setLineWidth(2.5)
    ctx.strokePath()
    ctx.restoreGState()

    ctx.saveGState()
    let inner = CGPath(roundedRect: tile.insetBy(dx: 7, dy: 7),
                       cornerWidth: 178, cornerHeight: 178, transform: nil)
    ctx.addPath(inner)
    ctx.setStrokeColor(color(1, 0.05))
    ctx.setLineWidth(1)
    ctx.strokePath()
    ctx.restoreGState()
}

/// Brand mark: the tile only, edge to edge, no margin or shadow.
func drawMark(in ctx: CGContext) {
    ctx.setShouldAntialias(true)
    let tile = CGRect(x: 0, y: 0, width: S, height: S)
    let tilePath = CGPath(roundedRect: tile, cornerWidth: 224, cornerHeight: 224, transform: nil)
    ctx.saveGState()
    ctx.addPath(tilePath)
    ctx.clip()
    ctx.setFillColor(color(0, 1))
    ctx.fill(tile)
    aspectFill(art, in: tile)
    ctx.restoreGState()
}

func render(_ size: Int, draw: (CGContext) -> Void) throws -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    rep.size = NSSize(width: size, height: size)
    let g = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = g
    let ctx = g.cgContext
    ctx.scaleBy(x: CGFloat(size) / S, y: CGFloat(size) / S)
    draw(ctx)
    NSGraphicsContext.restoreGraphicsState()
    guard let data = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "icon", code: 1)
    }
    return data
}

try FileManager.default.createDirectory(at: assetsDir, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: resourcesDir, withIntermediateDirectories: true)

let iconset = assetsDir.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

let variants: [(String, Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]
for (name, size) in variants {
    try render(size, draw: drawAppIcon).write(to: iconset.appendingPathComponent(name))
}
try render(1024, draw: drawAppIcon).write(to: assetsDir.appendingPathComponent("AppIcon-1024.png"))
try render(512, draw: drawMark).write(to: resourcesDir.appendingPathComponent("AppMark.png"))

let icnsURL = assetsDir.appendingPathComponent("AppIcon.icns")
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", icnsURL.path]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else {
    FileHandle.standardError.write(Data("iconutil failed\n".utf8))
    exit(4)
}
print("Wrote \(icnsURL.path), AppIcon-1024.png and \(resourcesDir.appendingPathComponent("AppMark.png").path)")
_ = root
