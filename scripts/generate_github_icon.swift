#!/usr/bin/env swift
//
// Generates a transparent PNG of the GitHub Octocat mark at multiple sizes for
// the asset catalog. Renders the official SVG path data via NSBezierPath, so
// the result is crisp and has a real alpha channel (the previous PNG download
// was an indexed-color image with no transparency, which broke template mode).
//

import AppKit

// The official GitHub mark, viewBox 0 0 16 16. Path data taken from
// https://github.githubassets.com/favicons/favicon.svg.
let svgPath = "M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0016 8c0-4.42-3.58-8-8-8z"

// Tiny SVG-path tokenizer that supports M/m/L/l/H/h/V/v/C/c/S/s/Z/z (enough
// for the GitHub mark).
struct SVGPathParser {
    let source: String
    var i: String.Index
    var current = NSPoint.zero
    var subpathStart = NSPoint.zero
    var lastControl: NSPoint?  // for smooth-curve continuation
    var lastCommand: Character = " "

    init(_ s: String) {
        self.source = s
        self.i = s.startIndex
    }

    mutating func skipWhitespaceAndCommas() {
        while i < source.endIndex {
            let c = source[i]
            if c.isWhitespace || c == "," {
                i = source.index(after: i)
            } else { break }
        }
    }

    mutating func readNumber() -> CGFloat? {
        skipWhitespaceAndCommas()
        guard i < source.endIndex else { return nil }
        let start = i
        if source[i] == "-" || source[i] == "+" {
            i = source.index(after: i)
        }
        var seenDot = false
        while i < source.endIndex {
            let c = source[i]
            if c.isNumber {
                i = source.index(after: i)
            } else if c == "." && !seenDot {
                seenDot = true
                i = source.index(after: i)
            } else { break }
        }
        let token = String(source[start..<i])
        return Double(token).map { CGFloat($0) }
    }

    mutating func readPoint(relative: Bool) -> NSPoint? {
        guard let x = readNumber(), let y = readNumber() else { return nil }
        return relative ? NSPoint(x: current.x + x, y: current.y + y)
                        : NSPoint(x: x, y: y)
    }

    mutating func parse(into path: NSBezierPath) {
        while i < source.endIndex {
            skipWhitespaceAndCommas()
            guard i < source.endIndex else { break }
            let c = source[i]
            if c.isLetter {
                lastCommand = c
                i = source.index(after: i)
                continue
            }
            // No new command letter — keep using lastCommand (implicit repeat).
            switch lastCommand {
            case "M":
                if let p = readPoint(relative: false) {
                    path.move(to: p); current = p; subpathStart = p
                    lastCommand = "L"
                }
            case "m":
                if let p = readPoint(relative: true) {
                    path.move(to: p); current = p; subpathStart = p
                    lastCommand = "l"
                }
            case "L":
                if let p = readPoint(relative: false) {
                    path.line(to: p); current = p
                }
            case "l":
                if let p = readPoint(relative: true) {
                    path.line(to: p); current = p
                }
            case "H":
                if let x = readNumber() {
                    let p = NSPoint(x: x, y: current.y)
                    path.line(to: p); current = p
                }
            case "h":
                if let dx = readNumber() {
                    let p = NSPoint(x: current.x + dx, y: current.y)
                    path.line(to: p); current = p
                }
            case "V":
                if let y = readNumber() {
                    let p = NSPoint(x: current.x, y: y)
                    path.line(to: p); current = p
                }
            case "v":
                if let dy = readNumber() {
                    let p = NSPoint(x: current.x, y: current.y + dy)
                    path.line(to: p); current = p
                }
            case "C":
                if let c1 = readPoint(relative: false),
                   let c2 = readPoint(relative: false),
                   let p  = readPoint(relative: false) {
                    path.curve(to: p, controlPoint1: c1, controlPoint2: c2)
                    lastControl = c2; current = p
                }
            case "c":
                if let c1 = readPoint(relative: true),
                   let c2 = readPoint(relative: true),
                   let p  = readPoint(relative: true) {
                    path.curve(to: p, controlPoint1: c1, controlPoint2: c2)
                    lastControl = c2; current = p
                }
            case "S":
                if let c2 = readPoint(relative: false),
                   let p  = readPoint(relative: false) {
                    let c1 = NSPoint(x: 2*current.x - (lastControl?.x ?? current.x),
                                     y: 2*current.y - (lastControl?.y ?? current.y))
                    path.curve(to: p, controlPoint1: c1, controlPoint2: c2)
                    lastControl = c2; current = p
                }
            case "s":
                if let c2 = readPoint(relative: true),
                   let p  = readPoint(relative: true) {
                    let c1 = NSPoint(x: 2*current.x - (lastControl?.x ?? current.x),
                                     y: 2*current.y - (lastControl?.y ?? current.y))
                    path.curve(to: p, controlPoint1: c1, controlPoint2: c2)
                    lastControl = c2; current = p
                }
            case "Z", "z":
                path.close()
                current = subpathStart
                lastCommand = " "
            default:
                // Unknown / unsupported command — skip a number to avoid spinning.
                _ = readNumber()
            }
        }
    }
}

func renderGitHubMark(pixelSize px: Int) -> Data {
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: px, pixelsHigh: px,
        bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    )!
    bitmap.size = NSSize(width: px, height: px)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

    // Build the mark path in 16x16 SVG coordinates, then transform.
    let path = NSBezierPath()
    var parser = SVGPathParser(svgPath)
    parser.parse(into: path)
    path.windingRule = .evenOdd

    // SVG y-axis is top-down; AppKit is bottom-up. Flip + scale to fit.
    let scale = CGFloat(px) / 16.0
    let xform = AffineTransform(translationByX: 0, byY: CGFloat(px))
    var t = xform
    t.scale(x: scale, y: -scale)
    path.transform(using: t)

    NSColor.black.setFill()  // template mode reads alpha only, so any color works
    path.fill()

    NSGraphicsContext.restoreGraphicsState()

    return bitmap.representation(using: .png, properties: [:])!
}

let outputDir = "mutify/Assets.xcassets/GitHubMark.imageset"

let sizes: [(name: String, px: Int)] = [
    ("github_mark_16.png", 16),
    ("github_mark_32.png", 32),
    ("github_mark_48.png", 48),
]

for (name, px) in sizes {
    let data = renderGitHubMark(pixelSize: px)
    let url = URL(fileURLWithPath: "\(outputDir)/\(name)")
    try! data.write(to: url)
    print("✔︎ \(url.path) (\(px)×\(px), \(data.count) bytes)")
}
print("Done.")
