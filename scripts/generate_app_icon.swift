#!/usr/bin/env swift
//
// One-shot script to generate AppIcon PNGs for Mutify.
// Draws a dark squircle background + white mic glyph at every required size.
//
// Usage:  swift scripts/generate_app_icon.swift
//

import AppKit

let outputDir = "mutify/Assets.xcassets/AppIcon.appiconset"

let sizes: [(filename: String, px: Int)] = [
    ("icon_16.png",       16),
    ("icon_16@2x.png",    32),
    ("icon_32.png",       32),
    ("icon_32@2x.png",    64),
    ("icon_128.png",     128),
    ("icon_128@2x.png",  256),
    ("icon_256.png",     256),
    ("icon_256@2x.png",  512),
    ("icon_512.png",     512),
    ("icon_512@2x.png", 1024),
]

for (filename, px) in sizes {
    // Create a bitmap at the EXACT pixel size we want — no DPI doubling.
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: px,
        pixelsHigh: px,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        FileHandle.standardError.write("Failed to allocate bitmap for \(filename)\n".data(using: .utf8)!)
        exit(1)
    }
    bitmap.size = NSSize(width: px, height: px)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

    let pxF = CGFloat(px)
    let bgRect = NSRect(x: 0, y: 0, width: pxF, height: pxF)
    let radius = pxF * 0.2237  // Apple-standard squircle corner radius.
    let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: radius, yRadius: radius)

    // Background gradient.
    let gradient = NSGradient(
        starting: NSColor(calibratedRed: 0.20, green: 0.22, blue: 0.28, alpha: 1.0),
        ending:   NSColor(calibratedRed: 0.07, green: 0.08, blue: 0.11, alpha: 1.0)
    )!
    gradient.draw(in: bgPath, angle: -90)

    // Subtle inner highlight at the top half.
    NSGraphicsContext.saveGraphicsState()
    bgPath.addClip()
    NSColor.white.withAlphaComponent(0.06).setFill()
    NSBezierPath(rect: NSRect(x: 0, y: pxF * 0.55, width: pxF, height: pxF * 0.45)).fill()
    NSGraphicsContext.restoreGraphicsState()

    // Mic symbol (hierarchical white tint, macOS 12+).
    let symbolPointSize = pxF * 0.55
    let baseConfig  = NSImage.SymbolConfiguration(pointSize: symbolPointSize, weight: .semibold)
    let colorConfig = NSImage.SymbolConfiguration(hierarchicalColor: .white)
    let merged      = baseConfig.applying(colorConfig)

    if let symbol = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(merged) {
        let symbolSize = symbol.size
        let symbolRect = NSRect(
            x: (pxF - symbolSize.width)  / 2,
            y: (pxF - symbolSize.height) / 2,
            width:  symbolSize.width,
            height: symbolSize.height
        )
        symbol.draw(in: symbolRect)
    }

    NSGraphicsContext.restoreGraphicsState()

    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        FileHandle.standardError.write("Failed to encode \(filename)\n".data(using: .utf8)!)
        exit(1)
    }

    let url = URL(fileURLWithPath: "\(outputDir)/\(filename)")
    do {
        try png.write(to: url)
        print("✔︎ Wrote \(url.path) (\(px)×\(px))")
    } catch {
        FileHandle.standardError.write("Failed to write \(url.path): \(error)\n".data(using: .utf8)!)
        exit(1)
    }
}

print("Done.")
