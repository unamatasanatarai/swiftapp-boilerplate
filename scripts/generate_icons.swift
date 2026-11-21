#!/usr/bin/env swift
// Regenerates the app icon and status bar icons in Resources/.
// Usage: swift scripts/generate_icons.swift [ResourcesDir]

import AppKit

let label = "st"
let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Resources"

func italicBoldFont(size: CGFloat) -> NSFont {
    let base = NSFont.systemFont(ofSize: size, weight: .bold)
    let desc = base.fontDescriptor.withSymbolicTraits([.bold, .italic])
    return NSFont(descriptor: desc, size: size) ?? base
}

/// Draws a rounded badge with centred italic text into a bitmap of `pixels` x `pixels`.
func renderBadge(pixels: Int, inset: CGFloat, radius: CGFloat, fontSize: CGFloat,
                 yOffset: CGFloat, bg: NSColor, fg: NSColor) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: pixels, height: pixels)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let rect = NSRect(x: 0, y: 0, width: pixels, height: pixels)
    bg.setFill()
    NSBezierPath(roundedRect: rect.insetBy(dx: inset, dy: inset), xRadius: radius, yRadius: radius).fill()

    let str = NSAttributedString(string: label, attributes: [
        .font: italicBoldFont(size: fontSize),
        .foregroundColor: fg,
    ])
    let s = str.size()
    str.draw(at: NSPoint(x: (rect.width - s.width) / 2, y: (rect.height - s.height) / 2 + yOffset))

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

func write(_ data: Data, _ name: String) {
    let url = URL(fileURLWithPath: outDir).appendingPathComponent(name)
    try! data.write(to: url)
    print("wrote \(url.path)")
}

// App icon (512 px)
write(renderBadge(pixels: 512, inset: 26, radius: 92, fontSize: 210, yOffset: -6,
                  bg: .black, fg: .white), "AppIcon.png")

// Status bar icons (18 pt, @1x and @2x)
for scale in [1, 2] {
    let s = CGFloat(scale)
    let suffix = scale == 2 ? "@2x" : ""
    // "_Dark" = black badge (for light menu bars), "_Light" = white badge (for dark menu bars)
    let black = renderBadge(pixels: 18 * scale, inset: s, radius: 3.5 * s, fontSize: 10 * s,
                            yOffset: -0.5 * s, bg: .black, fg: .white)
    let white = renderBadge(pixels: 18 * scale, inset: s, radius: 3.5 * s, fontSize: 10 * s,
                            yOffset: -0.5 * s, bg: .white, fg: .black)
    write(black, "StatusBarIcon\(suffix).png")
    write(black, "StatusBarIcon_Dark\(suffix).png")
    write(white, "StatusBarIcon_Light\(suffix).png")
}
