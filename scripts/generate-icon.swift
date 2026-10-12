#!/usr/bin/env swift
import AppKit
import Foundation

// Run from the repository root:
// CLANG_MODULE_CACHE_PATH=.build/module-cache swift scripts/generate-icon.swift
// All artwork is drawn locally; sips and iconutil are included with macOS.

enum IconError: Error {
    case bitmapCreationFailed
    case pngEncodingFailed
    case commandFailed(String)
}

func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255,
            green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 230) / 230,
            alpha: alpha)
}

@MainActor
func drawIcon(to url: URL) throws {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
        isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    ), let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw IconError.bitmapCreationFailed
    }

    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    NSGraphicsContext.current = graphics
    graphics.shouldAntialias = true
    graphics.imageInterpolation = .high
    let context = graphics.cgContext

    let tile = NSBezierPath(roundedRect: NSRect(x: 82, y: 82, width: 860, height: 860),
                            xRadius: 190, yRadius: 190)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.24)
    shadow.shadowBlurRadius = 25
    shadow.shadowOffset = NSSize(width: 0, height: -12)
    shadow.set()
    color(0x272D2C).setFill()
    tile.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    tile.addClip()
    NSGradient(starting: color(0x303634), ending: color(0x242A29))?.draw(in: tile, angle: -80)
    let ambient = NSGradient(colors: [color(0xC6BBED, alpha: 0.065), color(0xC6BBED, alpha: 0)])
    ambient?.draw(fromCenter: NSPoint(x: 380, y: 690), radius: 0,
                  toCenter: NSPoint(x: 380, y: 690), radius: 490, options: [])
    NSGraphicsContext.restoreGraphicsState()

    color(0xFFFFFF, alpha: 0.07).setStroke()
    tile.lineWidth = 1.5
    tile.stroke()

    let center = CGPoint(x: 512, y: 518)

    // The barely visible outer orbit echoes the timer's gentle breathing halo.
    let orbit = NSBezierPath(ovalIn: NSRect(x: center.x - 278, y: center.y - 278,
                                           width: 556, height: 556))
    orbit.lineWidth = 2
    color(0xC6BBED, alpha: 0.17).setStroke()
    orbit.stroke()

    context.saveGState()
    context.addEllipse(in: CGRect(x: center.x - 247, y: center.y - 247,
                                  width: 494, height: 494))
    context.setLineWidth(13)
    context.replacePathWithStrokedPath()
    context.clip()
    NSGradient(colors: [color(0x99B8AD), color(0xB2B9CB), color(0xD0C3ED)])?
        .draw(in: NSRect(x: 252, y: 258, width: 520, height: 520), angle: 90)
    context.restoreGState()

    // A single, softly glowing marker makes the circular time motif recognizable.
    let marker = NSPoint(x: center.x, y: center.y + 247)
    NSGradient(colors: [color(0xD9CEF6, alpha: 0.21), color(0xD9CEF6, alpha: 0)])?
        .draw(fromCenter: marker, radius: 0, toCenter: marker, radius: 43, options: [])
    color(0xE8DFFC).setFill()
    NSBezierPath(ovalIn: NSRect(x: marker.x - 11, y: marker.y - 11,
                               width: 22, height: 22)).fill()

    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw IconError.pngEncodingFailed
    }
    try png.write(to: url, options: .atomic)
}

func run(_ executable: String, _ arguments: [String]) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    process.standardOutput = FileHandle.nullDevice
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else { throw IconError.commandFailed(executable) }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let work = root.appendingPathComponent("build/icon-work", isDirectory: true)
let iconset = work.appendingPathComponent("Still.iconset", isDirectory: true)
let resources = root.appendingPathComponent("Resources", isDirectory: true)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
let master = work.appendingPathComponent("Still-1024.png")
try MainActor.assumeIsolated { try drawIcon(to: master) }

for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = String(size * scale)
        let suffix = scale == 2 ? "@2x" : ""
        let output = iconset.appendingPathComponent("icon_\(size)x\(size)\(suffix).png")
        try run("/usr/bin/sips", ["-z", pixels, pixels, master.path, "--out", output.path])
    }
}

let output = resources.appendingPathComponent("AppIcon.icns")
try run("/usr/bin/iconutil", ["-c", "icns", iconset.path, "-o", output.path])
print("Generated \(output.path)")
