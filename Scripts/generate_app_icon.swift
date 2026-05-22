#!/usr/bin/env swift

import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
  fputs("Usage: generate_app_icon.swift <output.icns>\n", stderr)
  exit(64)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let fileManager = FileManager.default
let iconsetURL = fileManager.temporaryDirectory
  .appendingPathComponent("LitePaste-\(UUID().uuidString).iconset", isDirectory: true)

try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)
defer {
  try? fileManager.removeItem(at: iconsetURL)
}

let variants: [(name: String, pixels: Int)] = [
  ("icon_16x16.png", 16),
  ("icon_16x16@2x.png", 32),
  ("icon_32x32.png", 32),
  ("icon_32x32@2x.png", 64),
  ("icon_128x128.png", 128),
  ("icon_128x128@2x.png", 256),
  ("icon_256x256.png", 256),
  ("icon_256x256@2x.png", 512),
  ("icon_512x512.png", 512),
  ("icon_512x512@2x.png", 1024)
]

for variant in variants {
  let image = drawIcon(pixels: variant.pixels)
  let destination = iconsetURL.appendingPathComponent(variant.name)
  try writePNG(image, to: destination)
}

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
