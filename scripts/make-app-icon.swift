#!/usr/bin/env swift
// Draws the app icon from plain shapes (no text, no SF Symbols, no third-party art) and writes
// the three iOS 18 appearances into App/Resources/Assets.xcassets/AppIcon.appiconset/.
// Run from anywhere: `swift scripts/make-app-icon.swift`. See specs/002-app-icons/research.md D1–D3.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024

enum Variant: CaseIterable {
    case standard, dark, tinted

    var fileName: String {
        switch self {
        case .standard: "AppIcon.png"
        case .dark: "AppIcon-Dark.png"
        case .tinted: "AppIcon-Tinted.png"
        }
    }

    /// Only the default icon is opaque; Dark and Tinted let iOS supply the backdrop.
    var isOpaque: Bool { self == .standard }
}

/// Colours per element. Tinted uses luminance only (white = strongest) so iOS can apply the tint.
struct Palette {
    let sun, mountain, snow, sea, foam: CGColor

    static func make(for variant: Variant) -> Palette {
        func rgb(_ hex: UInt32) -> CGColor {
            CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                    green: CGFloat((hex >> 8) & 0xFF) / 255,
                    blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
        }
        func gray(_ white: CGFloat) -> CGColor { CGColor(srgbRed: white, green: white, blue: white, alpha: 1) }

        switch variant {
        case .standard:
            return Palette(sun: rgb(0xFFC83D), mountain: rgb(0x2F4A6B), snow: rgb(0xFFFFFF),
                           sea: rgb(0x38A3F1), foam: rgb(0xFFFFFF))
        case .dark:
            // Lighter mountain so it stays visible on the system's dark backdrop.
            return Palette(sun: rgb(0xFFC83D), mountain: rgb(0x6F87A8), snow: rgb(0xF2F6FA),
                           sea: rgb(0x2F8FD8), foam: rgb(0xE6F4FF))
        case .tinted:
            return Palette(sun: gray(1.0), mountain: gray(0.42), snow: gray(0.92),
                           sea: gray(0.66), foam: gray(1.0))
        }
    }
}

func draw(_ variant: Variant, in ctx: CGContext) {
    let s = CGFloat(size)
    let palette = Palette.make(for: variant)

    // Background: sky gradient, default icon only.
    if variant.isOpaque {
        let colors = [CGColor(srgbRed: 0.31, green: 0.70, blue: 1.0, alpha: 1),
                      CGColor(srgbRed: 0.11, green: 0.31, blue: 0.61, alpha: 1)] as CFArray
        let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                  colors: colors, locations: [0, 1])!
        ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: s), end: .zero, options: [])
    }

    // Sun (upper right), drawn first so the mountain overlaps it.
    ctx.setFillColor(palette.sun)
    ctx.fillEllipse(in: CGRect(x: 560, y: 560, width: 320, height: 320))

    // Mountain with a jagged snow cap. Coordinates are y-up.
    let apex = CGPoint(x: 450, y: 800)
    let left = CGPoint(x: 40, y: 260)
    let right = CGPoint(x: 900, y: 260)
    ctx.setFillColor(palette.mountain)
    ctx.beginPath()
    ctx.move(to: left); ctx.addLine(to: apex); ctx.addLine(to: right); ctx.closePath()
    ctx.fillPath()

    // Snow cap: the top ~30% of the peak, lower edge zig-zags.
    func onLeftSlope(_ y: CGFloat) -> CGFloat { apex.x - (apex.y - y) * (apex.x - left.x) / (apex.y - left.y) }
    func onRightSlope(_ y: CGFloat) -> CGFloat { apex.x + (apex.y - y) * (right.x - apex.x) / (apex.y - right.y) }
    let capLow: CGFloat = 610, capHigh: CGFloat = 660
    ctx.setFillColor(palette.snow)
    ctx.beginPath()
    ctx.move(to: apex)
    ctx.addLine(to: CGPoint(x: onLeftSlope(capLow), y: capLow))
    let x0 = onLeftSlope(capLow), x1 = onRightSlope(capLow)
    let teeth = 4
    for i in 1...(teeth * 2) {
        let x = x0 + (x1 - x0) * CGFloat(i) / CGFloat(teeth * 2)
        ctx.addLine(to: CGPoint(x: x, y: i.isMultiple(of: 2) ? capLow : capHigh))
    }
    ctx.closePath()
    ctx.fillPath()

    // Sea with a wavy top edge across the bottom, plus a foam line on the crest.
    func waveY(_ x: CGFloat) -> CGFloat { 300 + 42 * sin(x / s * 2 * .pi * 2) }
    let wave = CGMutablePath()
    wave.move(to: CGPoint(x: 0, y: waveY(0)))
    for x in stride(from: 0, through: s, by: 4) { wave.addLine(to: CGPoint(x: x, y: waveY(x))) }
    let sea = wave.mutableCopy()!
    sea.addLine(to: CGPoint(x: s, y: 0)); sea.addLine(to: .zero); sea.closeSubpath()
    ctx.setFillColor(palette.sea)
    ctx.addPath(sea); ctx.fillPath()

    ctx.setStrokeColor(palette.foam)
    ctx.setLineWidth(28)
    ctx.setLineCap(.round)
    ctx.addPath(wave); ctx.strokePath()
}

func render(_ variant: Variant, to url: URL) throws {
    let alpha: CGImageAlphaInfo = variant.isOpaque ? .noneSkipLast : .premultipliedLast
    guard let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpace(name: CGColorSpace.sRGB)!,
                              bitmapInfo: alpha.rawValue) else {
        throw NSError(domain: "make-app-icon", code: 1, userInfo: [NSLocalizedDescriptionKey: "No bitmap context"])
    }
    ctx.setShouldAntialias(true)
    draw(variant, in: ctx)

    guard let image = ctx.makeImage(),
          let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
    else {
        throw NSError(domain: "make-app-icon", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot write \(url.path)"])
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw NSError(domain: "make-app-icon", code: 3, userInfo: [NSLocalizedDescriptionKey: "Cannot finalise \(url.path)"])
    }
}

let iconSet = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()          // scripts/
    .deletingLastPathComponent()          // repository root
    .appendingPathComponent("App/Resources/Assets.xcassets/AppIcon.appiconset")

for variant in Variant.allCases {
    let url = iconSet.appendingPathComponent(variant.fileName)
    try render(variant, to: url)
    print("wrote \(url.path)")
}
