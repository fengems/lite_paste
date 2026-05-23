#!/usr/bin/env swift

import AppKit
import Foundation

guard (2...3).contains(CommandLine.arguments.count) else {
  fputs("Usage: generate_app_icon.swift <output.icns> [output.appiconset]\n", stderr)
  exit(64)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let appIconSetURL = CommandLine.arguments.count == 3
  ? URL(fileURLWithPath: CommandLine.arguments[2])
  : nil
let fileManager = FileManager.default
let iconsetURL = fileManager.temporaryDirectory
  .appendingPathComponent("LitePaste-\(UUID().uuidString).iconset", isDirectory: true)

defer {
  try? fileManager.removeItem(at: iconsetURL)
}

struct IconVariant {
  let name: String
  let pixels: Int
  let size: String
  let scale: String
}

let variants: [IconVariant] = [
  IconVariant(name: "icon_16x16.png", pixels: 16, size: "16x16", scale: "1x"),
  IconVariant(name: "icon_16x16@2x.png", pixels: 32, size: "16x16", scale: "2x"),
  IconVariant(name: "icon_32x32.png", pixels: 32, size: "32x32", scale: "1x"),
  IconVariant(name: "icon_32x32@2x.png", pixels: 64, size: "32x32", scale: "2x"),
  IconVariant(name: "icon_128x128.png", pixels: 128, size: "128x128", scale: "1x"),
  IconVariant(name: "icon_128x128@2x.png", pixels: 256, size: "128x128", scale: "2x"),
  IconVariant(name: "icon_256x256.png", pixels: 256, size: "256x256", scale: "1x"),
  IconVariant(name: "icon_256x256@2x.png", pixels: 512, size: "256x256", scale: "2x"),
  IconVariant(name: "icon_512x512.png", pixels: 512, size: "512x512", scale: "1x"),
  IconVariant(name: "icon_512x512@2x.png", pixels: 1024, size: "512x512", scale: "2x")
]

try writeIconset(at: iconsetURL, includeContentsJSON: false)

try? fileManager.removeItem(at: outputURL)
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = [
  "-c", "icns",
  iconsetURL.path,
  "-o", outputURL.path
]
try process.run()
process.waitUntilExit()

guard process.terminationStatus == 0 else {
  fputs("iconutil failed with status \(process.terminationStatus)\n", stderr)
  exit(process.terminationStatus)
}

if let appIconSetURL {
  try writeAssetCatalogRootIfNeeded(containing: appIconSetURL)
  try writeIconset(at: appIconSetURL, includeContentsJSON: true)
}

func writeAssetCatalogRootIfNeeded(containing appIconSetURL: URL) throws {
  let catalogURL = appIconSetURL.deletingLastPathComponent()
  guard catalogURL.pathExtension == "xcassets" else {
    return
  }

  try fileManager.createDirectory(at: catalogURL, withIntermediateDirectories: true)
  let contentsURL = catalogURL.appendingPathComponent("Contents.json")
  guard !fileManager.fileExists(atPath: contentsURL.path) else {
    return
  }

  let contents: [String: Any] = [
    "info": [
      "author": "xcode",
      "version": 1
    ]
  ]
  let data = try JSONSerialization.data(
    withJSONObject: contents,
    options: [.prettyPrinted, .sortedKeys]
  )
  try data.write(to: contentsURL, options: .atomic)
}

func writeIconset(at url: URL, includeContentsJSON: Bool) throws {
  try? fileManager.removeItem(at: url)
  try fileManager.createDirectory(at: url, withIntermediateDirectories: true)

  for variant in variants {
    let image = drawIcon(pixels: variant.pixels)
    let destination = url.appendingPathComponent(variant.name)
    try writePNG(image, to: destination)
  }

  if includeContentsJSON {
    let images = variants.map { variant in
      [
        "filename": variant.name,
        "idiom": "mac",
        "scale": variant.scale,
        "size": variant.size
      ]
    }
    let contents: [String: Any] = [
      "images": images,
      "info": [
        "author": "xcode",
        "version": 1
      ]
    ]
    let data = try JSONSerialization.data(
      withJSONObject: contents,
      options: [.prettyPrinted, .sortedKeys]
    )
    try data.write(to: url.appendingPathComponent("Contents.json"), options: .atomic)
  }
}

func drawIcon(pixels: Int) -> NSImage {
  let size = NSSize(width: pixels, height: pixels)
  let image = NSImage(size: size)

  image.lockFocus()
  defer { image.unlockFocus() }

  let rect = NSRect(origin: .zero, size: size)
  NSColor.clear.setFill()
  rect.fill()

  let cornerRadius = CGFloat(pixels) * 0.22
  let background = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
  let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.10, green: 0.20, blue: 0.28, alpha: 1.0),
    NSColor(calibratedRed: 0.07, green: 0.42, blue: 0.48, alpha: 1.0)
  ])
  gradient?.draw(in: background, angle: 135)

  let shadowColor = NSColor(calibratedWhite: 0.0, alpha: 0.28)
  shadowColor.setFill()
  let shadowOffset = CGFloat(pixels) * 0.025
  let paperRect = rect.insetBy(dx: CGFloat(pixels) * 0.22, dy: CGFloat(pixels) * 0.19)
    .offsetBy(dx: shadowOffset, dy: -shadowOffset)
  NSBezierPath(
    roundedRect: paperRect,
    xRadius: CGFloat(pixels) * 0.07,
    yRadius: CGFloat(pixels) * 0.07
  ).fill()

  let boardRect = rect.insetBy(dx: CGFloat(pixels) * 0.20, dy: CGFloat(pixels) * 0.18)
  let boardPath = NSBezierPath(
    roundedRect: boardRect,
    xRadius: CGFloat(pixels) * 0.07,
    yRadius: CGFloat(pixels) * 0.07
  )
  NSColor(calibratedRed: 0.95, green: 0.98, blue: 0.96, alpha: 1.0).setFill()
  boardPath.fill()

  NSColor(calibratedRed: 0.11, green: 0.31, blue: 0.34, alpha: 0.12).setStroke()
  boardPath.lineWidth = max(1, CGFloat(pixels) * 0.012)
  boardPath.stroke()

  let clipRect = NSRect(
    x: rect.midX - CGFloat(pixels) * 0.16,
    y: boardRect.maxY - CGFloat(pixels) * 0.08,
    width: CGFloat(pixels) * 0.32,
    height: CGFloat(pixels) * 0.12
  )
  let clipPath = NSBezierPath(
    roundedRect: clipRect,
    xRadius: CGFloat(pixels) * 0.035,
    yRadius: CGFloat(pixels) * 0.035
  )
  NSColor(calibratedRed: 0.11, green: 0.34, blue: 0.36, alpha: 1.0).setFill()
  clipPath.fill()

  let topHighlight = NSBezierPath(
    roundedRect: clipRect.insetBy(dx: CGFloat(pixels) * 0.055, dy: CGFloat(pixels) * 0.04),
    xRadius: CGFloat(pixels) * 0.02,
    yRadius: CGFloat(pixels) * 0.02
  )
  NSColor(calibratedRed: 0.75, green: 0.96, blue: 0.86, alpha: 1.0).setFill()
  topHighlight.fill()

  let lineColor = NSColor(calibratedRed: 0.14, green: 0.35, blue: 0.36, alpha: 0.42)
  lineColor.setStroke()
  for index in 0..<3 {
    let y = boardRect.maxY - CGFloat(pixels) * (0.23 + CGFloat(index) * 0.12)
    let line = NSBezierPath()
    line.move(to: NSPoint(x: boardRect.minX + CGFloat(pixels) * 0.12, y: y))
    line.line(to: NSPoint(x: boardRect.maxX - CGFloat(pixels) * 0.12, y: y))
    line.lineWidth = max(1, CGFloat(pixels) * 0.018)
    line.lineCapStyle = .round
    line.stroke()
  }

  let badgeRect = NSRect(
    x: boardRect.maxX - CGFloat(pixels) * 0.23,
    y: boardRect.minY + CGFloat(pixels) * 0.08,
    width: CGFloat(pixels) * 0.25,
    height: CGFloat(pixels) * 0.25
  )
  let badge = NSBezierPath(ovalIn: badgeRect)
  NSColor(calibratedRed: 0.80, green: 0.95, blue: 0.43, alpha: 1.0).setFill()
  badge.fill()

  NSColor(calibratedRed: 0.08, green: 0.24, blue: 0.25, alpha: 1.0).setStroke()
  let mark = NSBezierPath()
  mark.move(to: NSPoint(x: badgeRect.minX + badgeRect.width * 0.25, y: badgeRect.midY))
  mark.line(to: NSPoint(x: badgeRect.minX + badgeRect.width * 0.43, y: badgeRect.minY + badgeRect.height * 0.32))
  mark.line(to: NSPoint(x: badgeRect.minX + badgeRect.width * 0.74, y: badgeRect.minY + badgeRect.height * 0.68))
  mark.lineWidth = max(1.5, CGFloat(pixels) * 0.028)
  mark.lineCapStyle = .round
  mark.lineJoinStyle = .round
  mark.stroke()

  return image
}

func writePNG(_ image: NSImage, to url: URL) throws {
  guard let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let png = bitmap.representation(using: .png, properties: [:]) else {
    throw CocoaError(.fileWriteUnknown)
  }

  try png.write(to: url, options: .atomic)
}
