#!/usr/bin/env swift

import AppKit
import Foundation

struct IconVariant {
    let points: Int
    let scale: Int

    var pixels: Int { points * scale }
    var filename: String {
        scale == 1
            ? "icon_\(points)x\(points).png"
            : "icon_\(points)x\(points)@2x.png"
    }
}

let variants = [
    IconVariant(points: 16, scale: 1),
    IconVariant(points: 16, scale: 2),
    IconVariant(points: 32, scale: 1),
    IconVariant(points: 32, scale: 2),
    IconVariant(points: 128, scale: 1),
    IconVariant(points: 128, scale: 2),
    IconVariant(points: 256, scale: 1),
    IconVariant(points: 256, scale: 2),
    IconVariant(points: 512, scale: 1),
    IconVariant(points: 512, scale: 2)
]

let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
let projectURL = scriptURL
    .deletingLastPathComponent()
    .deletingLastPathComponent()
let resourcesURL = projectURL.appendingPathComponent("Resources", isDirectory: true)
let iconsetURL = resourcesURL.appendingPathComponent("AppIcon.iconset", isDirectory: true)
let outputURL = resourcesURL.appendingPathComponent("AppIcon.icns")
let fileManager = FileManager.default

try? fileManager.removeItem(at: iconsetURL)
try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

func renderIcon(pixels: Int) throws -> Data {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw NSError(domain: "ShiftGridIcon", code: 1)
    }

    let side = CGFloat(pixels)
    let canvas = NSRect(x: 0, y: 0, width: side, height: side)
    let iconRect = canvas.insetBy(dx: side * 0.075, dy: side * 0.075)
    let cornerRadius = side * 0.205

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.shouldAntialias = true

    NSColor.clear.setFill()
    canvas.fill(using: .copy)

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.24)
    shadow.shadowBlurRadius = side * 0.045
    shadow.shadowOffset = NSSize(width: 0, height: -side * 0.025)
    shadow.set()

    let backgroundPath = NSBezierPath(
        roundedRect: iconRect,
        xRadius: cornerRadius,
        yRadius: cornerRadius
    )
    backgroundPath.addClip()
    NSGradient(
        starting: NSColor(calibratedRed: 0.36, green: 0.64, blue: 1.0, alpha: 1),
        ending: NSColor(calibratedRed: 0.12, green: 0.28, blue: 0.78, alpha: 1)
    )?.draw(in: iconRect, angle: -62)

    NSGraphicsContext.restoreGraphicsState()
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.shouldAntialias = true

    let gridRect = NSRect(
        x: side * 0.195,
        y: side * 0.245,
        width: side * 0.61,
        height: side * 0.51
    )
    let gridPath = NSBezierPath(
        roundedRect: gridRect,
        xRadius: side * 0.055,
        yRadius: side * 0.055
    )
    NSColor.white.withAlphaComponent(0.97).setStroke()
    gridPath.lineWidth = max(1, side * 0.047)
    gridPath.stroke()

    let dividers = NSBezierPath()
    let firstDividerX = gridRect.minX + gridRect.width / 3
    let secondDividerX = gridRect.minX + gridRect.width * 2 / 3
    let dividerInset = side * 0.028
    dividers.move(to: NSPoint(x: firstDividerX, y: gridRect.minY + dividerInset))
    dividers.line(to: NSPoint(x: firstDividerX, y: gridRect.maxY - dividerInset))
    dividers.move(to: NSPoint(x: secondDividerX, y: gridRect.minY + dividerInset))
    dividers.line(to: NSPoint(x: secondDividerX, y: gridRect.maxY - dividerInset))
    dividers.lineWidth = max(1, side * 0.039)
    dividers.stroke()

    let highlight = NSBezierPath(
        roundedRect: NSRect(
            x: gridRect.minX + side * 0.022,
            y: gridRect.minY + side * 0.022,
            width: gridRect.width * 2 / 3 - side * 0.044,
            height: gridRect.height - side * 0.044
        ),
        xRadius: side * 0.025,
        yRadius: side * 0.025
    )
    NSColor.white.withAlphaComponent(0.20).setFill()
    highlight.fill()

    NSGraphicsContext.restoreGraphicsState()

    guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "ShiftGridIcon", code: 2)
    }
    return pngData
}

for variant in variants {
    let data = try renderIcon(pixels: variant.pixels)
    try data.write(to: iconsetURL.appendingPathComponent(variant.filename))
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetURL.path, "-o", outputURL.path]
try process.run()
process.waitUntilExit()

guard process.terminationStatus == 0 else {
    throw NSError(domain: "ShiftGridIcon", code: Int(process.terminationStatus))
}

try fileManager.removeItem(at: iconsetURL)
print("Created \(outputURL.path)")
