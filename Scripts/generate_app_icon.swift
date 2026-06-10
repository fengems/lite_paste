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

let appIconSource = try RasterIconSource.load(named: "AppIconSource.png")

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
  ) else {
    return NSImage(size: size)
  }

  bitmap.size = size
  let image = NSImage(size: size)

  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
  defer {
    NSGraphicsContext.restoreGraphicsState()
    image.addRepresentation(bitmap)
  }

  let rect = NSRect(origin: .zero, size: size)
  NSColor.clear.setFill()
  rect.fill()

  NSGraphicsContext.current?.imageInterpolation = .high
  appIconSource.image.draw(
    in: rect,
    from: appIconSource.cropRect,
    operation: .sourceOver,
    fraction: 1.0
  )

  return image
}

struct RasterIconSource {
  let image: NSImage
  let cropRect: NSRect

  static func load(named fileName: String) throws -> RasterIconSource {
    let sourceURL = try resolveBrandAsset(named: fileName)
    guard let sourceImage = NSImage(contentsOf: sourceURL),
          let cgImage = sourceImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
      throw CocoaError(.fileReadCorruptFile)
    }

    let processed = try makeEdgeBackgroundTransparent(cgImage)
    let nsImage = NSImage(cgImage: processed.image, size: NSSize(width: processed.width, height: processed.height))
    let cropRect = NSRect(
      x: processed.crop.minX,
      y: CGFloat(processed.height) - processed.crop.maxY,
      width: processed.crop.width,
      height: processed.crop.height
    )
    return RasterIconSource(image: nsImage, cropRect: cropRect)
  }
}

struct ProcessedRasterIcon {
  let image: CGImage
  let width: Int
  let height: Int
  let crop: CGRect
}

func resolveBrandAsset(named fileName: String) throws -> URL {
  let cwdURL = URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
  let cwdCandidate = cwdURL.appendingPathComponent("Assets/Brand/\(fileName)")
  if fileManager.fileExists(atPath: cwdCandidate.path) {
    return cwdCandidate
  }

  let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0])
  let scriptCandidate = scriptURL
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .appendingPathComponent("Assets/Brand/\(fileName)")
  if fileManager.fileExists(atPath: scriptCandidate.path) {
    return scriptCandidate
  }

  throw CocoaError(.fileReadNoSuchFile)
}

func makeEdgeBackgroundTransparent(_ image: CGImage) throws -> ProcessedRasterIcon {
  let width = image.width
  let height = image.height
  let bytesPerPixel = 4
  let bytesPerRow = width * bytesPerPixel
  var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)

  guard let context = CGContext(
    data: &pixels,
    width: width,
    height: height,
    bitsPerComponent: 8,
    bytesPerRow: bytesPerRow,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
  ) else {
    throw CocoaError(.coderInvalidValue)
  }

  context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
  removeEdgeBackground(from: &pixels, width: width, height: height)
  let baseRect = iconBaseRect(from: pixels, width: width, height: height)
  removeOuterArtworkShadow(from: &pixels, width: width, height: height, baseRect: baseRect)

  guard let outputContext = CGContext(
    data: &pixels,
    width: width,
    height: height,
    bitsPerComponent: 8,
    bytesPerRow: bytesPerRow,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
  ),
  let outputImage = outputContext.makeImage() else {
    throw CocoaError(.coderInvalidValue)
  }

  return ProcessedRasterIcon(
    image: outputImage,
    width: width,
    height: height,
    crop: iconCropRect(from: pixels, width: width, height: height)
  )
}

func removeEdgeBackground(from pixels: inout [UInt8], width: Int, height: Int) {
  var visited = [Bool](repeating: false, count: width * height)
  var queue: [Int] = []
  queue.reserveCapacity((width + height) * 2)

  func enqueue(_ x: Int, _ y: Int) {
    guard x >= 0, x < width, y >= 0, y < height else {
      return
    }

    let index = y * width + x
    guard !visited[index], isBackgroundPixel(pixels, index: index) else {
      return
    }

    visited[index] = true
    queue.append(index)
  }

  for x in 0..<width {
    enqueue(x, 0)
    enqueue(x, height - 1)
  }
  for y in 0..<height {
    enqueue(0, y)
    enqueue(width - 1, y)
  }

  var cursor = 0
  while cursor < queue.count {
    let index = queue[cursor]
    cursor += 1

    let offset = index * 4
    pixels[offset] = 0
    pixels[offset + 1] = 0
    pixels[offset + 2] = 0
    pixels[offset + 3] = 0

    let x = index % width
    let y = index / width
    enqueue(x - 1, y)
    enqueue(x + 1, y)
    enqueue(x, y - 1)
    enqueue(x, y + 1)
  }
}

func isBackgroundPixel(_ pixels: [UInt8], index: Int) -> Bool {
  let offset = index * 4
  let red = Int(pixels[offset])
  let green = Int(pixels[offset + 1])
  let blue = Int(pixels[offset + 2])
  let alpha = Int(pixels[offset + 3])
  let minimum = min(red, green, blue)
  let maximum = max(red, green, blue)
  return alpha > 0 && minimum >= 232 && maximum - minimum <= 18
}

func iconBaseRect(from pixels: [UInt8], width: Int, height: Int) -> CGRect {
  var minX = width
  var minY = height
  var maxX = 0
  var maxY = 0

  for y in 0..<height {
    for x in 0..<width {
      guard isBlueBasePixel(pixels, index: y * width + x) else {
        continue
      }

      minX = min(minX, x)
      minY = min(minY, y)
      maxX = max(maxX, x + 1)
      maxY = max(maxY, y + 1)
    }
  }

  guard minX < maxX, minY < maxY else {
    return CGRect(x: 0, y: 0, width: width, height: height)
  }

  let padding = max(2, min(width, height) / 300)
  let originX = max(0, minX - padding)
  let originY = max(0, minY - padding)
  let rectMaxX = min(width, maxX + padding)
  let rectMaxY = min(height, maxY + padding)
  return CGRect(
    x: CGFloat(originX),
    y: CGFloat(originY),
    width: CGFloat(rectMaxX - originX),
    height: CGFloat(rectMaxY - originY)
  )
}

func isBlueBasePixel(_ pixels: [UInt8], index: Int) -> Bool {
  let offset = index * 4
  let red = Int(pixels[offset])
  let green = Int(pixels[offset + 1])
  let blue = Int(pixels[offset + 2])
  let alpha = Int(pixels[offset + 3])
  let maximum = max(red, green, blue)
  let minimum = min(red, green, blue)
  return alpha > 8 && blue >= 170 && green >= 105 && red <= 110 && maximum - minimum >= 55
}

func removeOuterArtworkShadow(from pixels: inout [UInt8], width: Int, height: Int, baseRect: CGRect) {
  let artworkRect = baseRect.insetBy(dx: max(4, baseRect.width * 0.018), dy: max(4, baseRect.height * 0.018))
  let radius = min(artworkRect.width, artworkRect.height) * 0.22
  for y in 0..<height {
    for x in 0..<width {
      let point = CGPoint(x: CGFloat(x) + 0.5, y: CGFloat(y) + 0.5)
      if isInsideRoundedRect(point, rect: artworkRect, radius: radius) {
        continue
      }

      let offset = (y * width + x) * 4
      pixels[offset] = 0
      pixels[offset + 1] = 0
      pixels[offset + 2] = 0
      pixels[offset + 3] = 0
    }
  }
}

func isInsideRoundedRect(_ point: CGPoint, rect: CGRect, radius: CGFloat) -> Bool {
  guard rect.contains(point) else {
    return false
  }

  let minX = rect.minX + radius
  let maxX = rect.maxX - radius
  let minY = rect.minY + radius
  let maxY = rect.maxY - radius
  if (point.x >= minX && point.x <= maxX) || (point.y >= minY && point.y <= maxY) {
    return true
  }

  let cornerX = point.x < minX ? minX : maxX
  let cornerY = point.y < minY ? minY : maxY
  let dx = point.x - cornerX
  let dy = point.y - cornerY
  return dx * dx + dy * dy <= radius * radius
}

func iconCropRect(from pixels: [UInt8], width: Int, height: Int) -> CGRect {
  var minX = width
  var minY = height
  var maxX = 0
  var maxY = 0

  for y in 0..<height {
    for x in 0..<width {
      let alpha = pixels[(y * width + x) * 4 + 3]
      guard alpha > 8 else {
        continue
      }

      minX = min(minX, x)
      minY = min(minY, y)
      maxX = max(maxX, x + 1)
      maxY = max(maxY, y + 1)
    }
  }

  guard minX < maxX, minY < maxY else {
    return CGRect(x: 0, y: 0, width: width, height: height)
  }

  let contentWidth = maxX - minX
  let contentHeight = maxY - minY
  let side = min(max(contentWidth, contentHeight), min(width, height))
  let centerX = (minX + maxX) / 2
  let centerY = (minY + maxY) / 2
  let originX = min(max(0, centerX - side / 2), width - side)
  let originY = min(max(0, centerY - side / 2), height - side)

  return CGRect(
    x: CGFloat(originX),
    y: CGFloat(originY),
    width: CGFloat(side),
    height: CGFloat(side)
  )
}

func writePNG(_ image: NSImage, to url: URL) throws {
  guard let bitmap = image.representations.compactMap({ $0 as? NSBitmapImageRep }).first,
        let png = bitmap.representation(using: .png, properties: [:]) else {
    throw CocoaError(.fileWriteUnknown)
  }

  try png.write(to: url, options: .atomic)
}
