#!/usr/bin/env swift
//
// Renders Afterburner's layered tvOS app icon and Top Shelf images into the
// asset catalog. Run from the repository root:
//
//   swift scripts/make-icons.swift
//
// Everything is drawn with Core Graphics — no Boosteroid artwork and no SF
// Symbols (Apple's license doesn't allow those in app icons).

import AppKit

let catalog = CommandLine.arguments.dropFirst().first
    ?? "Afterburner/Assets.xcassets/App Icon & Top Shelf Image.brandassets"

// MARK: Palette (matches BoosteroidTheme in the app)

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: a)
}

let night = rgb(9, 10, 22)
let violet = rgb(125, 59, 237)
let indigo = rgb(79, 69, 230)
let blue = rgb(59, 130, 245)
let flameHot = rgb(255, 214, 102)
let flameOrange = rgb(255, 128, 48)
let flamePink = rgb(245, 58, 128)

// MARK: Rendering

func render(_ width: Int, _ height: Int, to path: String, opaque: Bool = false,
            draw: (CGContext, CGSize) -> Void) {
    let context = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: (opaque ? CGImageAlphaInfo.noneSkipLast : CGImageAlphaInfo.premultipliedLast).rawValue
    )!
    // Top-left origin, like UIKit/SwiftUI, so the coordinates below read naturally.
    context.translateBy(x: 0, y: CGFloat(height))
    context.scaleBy(x: 1, y: -1)
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
    draw(context, CGSize(width: width, height: height))
    let rep = NSBitmapImageRep(cgImage: context.makeImage()!)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
    print("wrote \(path)")
}

func linear(_ context: CGContext, _ colors: [CGColor], _ locations: [CGFloat], from: CGPoint, to: CGPoint) {
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!, colors: colors as CFArray, locations: locations)!
    context.drawLinearGradient(gradient, start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
}

func radial(_ context: CGContext, _ colors: [CGColor], center: CGPoint, radius: CGFloat) {
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!, colors: colors as CFArray, locations: nil)!
    context.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
}

// MARK: Artwork

/// Deep night-to-violet sky with a blue sheen — the back (opaque) layer.
func drawBackground(_ context: CGContext, _ size: CGSize) {
    linear(context, [night, rgb(38, 22, 92), indigo, rgb(24, 52, 120)], [0, 0.45, 0.75, 1],
           from: CGPoint(x: 0, y: size.height), to: CGPoint(x: size.width, y: 0))
    radial(context, [violet.copy(alpha: 0.55)!, violet.copy(alpha: 0)!],
           center: CGPoint(x: size.width * 0.5, y: size.height * 0.62), radius: size.width * 0.55)
}

/// Warm glow the flame sits in — the middle layer, so it drifts between the
/// sky and the flame on focus.
func drawGlow(_ context: CGContext, _ size: CGSize, center: CGPoint, radius: CGFloat) {
    radial(context, [flameOrange.copy(alpha: 0.55)!, flamePink.copy(alpha: 0.25)!, flamePink.copy(alpha: 0)!],
           center: center, radius: radius)
}

/// A flame in a unit square (0...1, top-left origin), mapped into `rect`.
func flamePath(in rect: CGRect, inner: Bool = false) -> CGPath {
    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
    }
    let path = CGMutablePath()
    if inner {
        path.move(to: p(0.5, 0.98))
        path.addCurve(to: p(0.30, 0.74), control1: p(0.38, 0.98), control2: p(0.30, 0.88))
        path.addCurve(to: p(0.52, 0.40), control1: p(0.30, 0.60), control2: p(0.44, 0.52))
        path.addCurve(to: p(0.70, 0.74), control1: p(0.56, 0.54), control2: p(0.70, 0.60))
        path.addCurve(to: p(0.5, 0.98), control1: p(0.70, 0.88), control2: p(0.62, 0.98))
    } else {
        path.move(to: p(0.5, 1.0))
        path.addCurve(to: p(0.10, 0.64), control1: p(0.26, 1.0), control2: p(0.10, 0.84))
        path.addCurve(to: p(0.32, 0.26), control1: p(0.10, 0.46), control2: p(0.22, 0.38))
        path.addCurve(to: p(0.40, 0.46), control1: p(0.32, 0.36), control2: p(0.35, 0.43))
        path.addCurve(to: p(0.58, 0.0), control1: p(0.42, 0.24), control2: p(0.50, 0.08))
        path.addCurve(to: p(0.90, 0.60), control1: p(0.66, 0.20), control2: p(0.90, 0.36))
        path.addCurve(to: p(0.5, 1.0), control1: p(0.90, 0.84), control2: p(0.74, 1.0))
    }
    path.closeSubpath()
    return path
}

/// The emblem: an outer flame in orange-to-pink with a hot inner core.
func drawFlame(_ context: CGContext, in rect: CGRect) {
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: rect.height * 0.03), blur: rect.height * 0.08,
                      color: rgb(0, 0, 0, 0.35))
    context.addPath(flamePath(in: rect))
    context.setFillColor(flamePink)
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(flamePath(in: rect))
    context.clip()
    linear(context, [flameHot, flameOrange, flamePink], [0, 0.45, 1],
           from: CGPoint(x: rect.midX, y: rect.maxY), to: CGPoint(x: rect.midX, y: rect.minY))
    context.restoreGState()

    context.saveGState()
    context.addPath(flamePath(in: rect, inner: true))
    context.clip()
    linear(context, [rgb(255, 255, 255), flameHot], [0.2, 1],
           from: CGPoint(x: rect.midX, y: rect.maxY), to: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.4))
    context.restoreGState()
}

func flameRect(in size: CGSize, heightFraction: CGFloat, centerX: CGFloat) -> CGRect {
    let height = size.height * heightFraction
    let width = height * 0.78
    return CGRect(x: centerX - width / 2, y: (size.height - height) / 2, width: width, height: height)
}

// MARK: App icon layers

func iconLayers(_ width: Int, _ height: Int, stack: String, suffix: String) {
    let base = "\(catalog)/\(stack)"
    render(width, height, to: "\(base)/Back.imagestacklayer/Content.imageset/bg_\(suffix).png", opaque: true) { c, s in
        drawBackground(c, s)
    }
    render(width, height, to: "\(base)/Middle.imagestacklayer/Content.imageset/mid_\(suffix).png") { c, s in
        drawGlow(c, s, center: CGPoint(x: s.width / 2, y: s.height * 0.56), radius: s.height * 0.5)
    }
    render(width, height, to: "\(base)/Front.imagestacklayer/Content.imageset/icon_\(suffix).png") { c, s in
        drawFlame(c, in: flameRect(in: s, heightFraction: 0.56, centerX: s.width / 2))
    }
}

iconLayers(400, 240, stack: "App Icon.imagestack", suffix: "400x240")
iconLayers(800, 480, stack: "App Icon.imagestack", suffix: "800x480")
iconLayers(1280, 768, stack: "App Icon - App Store.imagestack", suffix: "1280x768")

// MARK: Top Shelf

func topShelf(_ width: Int, _ height: Int, name: String) {
    render(width, height, to: "\(catalog)/\(name).imageset/top_\(width)x\(height).png", opaque: true) { c, s in
        drawBackground(c, s)
        let title = NSAttributedString(string: "AFTERBURNER", attributes: [
            .font: NSFont(name: "AvenirNext-Heavy", size: s.height * 0.16) ?? NSFont.systemFont(ofSize: s.height * 0.16, weight: .black),
            .foregroundColor: NSColor.white,
            .kern: s.height * 0.012,
        ])
        let flameHeight = s.height * 0.42
        let gap = s.height * 0.07
        let groupWidth = flameHeight * 0.78 + gap + title.size().width
        let startX = (s.width - groupWidth) / 2
        let flameCenterX = startX + flameHeight * 0.39
        drawGlow(c, s, center: CGPoint(x: flameCenterX, y: s.height * 0.54), radius: s.height * 0.42)
        drawFlame(c, in: flameRect(in: s, heightFraction: 0.42, centerX: flameCenterX))
        title.draw(at: CGPoint(x: startX + flameHeight * 0.78 + gap, y: (s.height - title.size().height) / 2))
    }
}

topShelf(1920, 720, name: "Top Shelf Image")
topShelf(2320, 720, name: "Top Shelf Image Wide")
