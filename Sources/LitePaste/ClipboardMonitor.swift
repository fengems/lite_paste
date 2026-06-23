import AppKit
import Foundation
import LitePasteCore

@MainActor
final class ClipboardMonitor {
  private let pasteboard: NSPasteboard
  private let store: HistoryStore
  private let writeTracker: ClipboardWriteTracker
  private let pasteboardReader: ClipboardPasteboardReader
  private let imageOCRService: ImageOCRService
  private var captureGate: ClipboardCaptureGate
  private var preserveLargeRichTextFormats: Bool
  private var copySoundEnabled: Bool
  private var imageOCREnabled: Bool
  private var imageOCRTasks: [ClipboardRecord.ID: Task<Void, Never>] = [:]
  private var timer: Timer?
  private var lastChangeCount: Int

  init(
    pasteboard: NSPasteboard = .general,
    store: HistoryStore,
    blobStorage: any BlobStorage = LocalBlobStorage(),
    writeTracker: ClipboardWriteTracker,
    payloadResolver: ClipboardPayloadResolver? = nil,
    monitoringPolicy: ClipboardMonitoringPolicy = ClipboardMonitoringPolicy(),
    preserveLargeRichTextFormats: Bool = false,
    copySoundEnabled: Bool = false,
    imageOCREnabled: Bool = false,
    imageOCRService: ImageOCRService = ImageOCRService()
  ) {
    self.pasteboard = pasteboard
    self.store = store
    self.writeTracker = writeTracker
    self.imageOCRService = imageOCRService
    let payloadResolver = payloadResolver ?? ClipboardPayloadResolver(
      mediaPayloadBuilder: ClipboardMediaPayloadBuilder(blobStorage: blobStorage)
    )
    self.pasteboardReader = ClipboardPasteboardReader(
      pasteboard: pasteboard,
      payloadResolver: payloadResolver
    )
    self.captureGate = ClipboardCaptureGate(monitoringPolicy: monitoringPolicy)
    self.preserveLargeRichTextFormats = preserveLargeRichTextFormats
    self.copySoundEnabled = copySoundEnabled
    self.imageOCREnabled = imageOCREnabled
    self.lastChangeCount = pasteboard.changeCount
  }

  func start() {
    guard timer == nil else {
      return
    }
    lastChangeCount = pasteboard.changeCount
    timer = Timer.scheduledTimer(withTimeInterval: 0.55, repeats: true) { [weak self] _ in
      Task { @MainActor in
        self?.captureIfNeeded()
      }
    }
  }

  func stop() {
    timer?.invalidate()
    timer = nil
    cancelImageOCRTasks()
  }

  func updateMonitoringPolicy(_ monitoringPolicy: ClipboardMonitoringPolicy) {
    captureGate.monitoringPolicy = monitoringPolicy
  }

  func updatePreserveLargeRichTextFormats(_ enabled: Bool) {
    preserveLargeRichTextFormats = enabled
  }

  func updateCopySoundEnabled(_ enabled: Bool) {
    copySoundEnabled = enabled
  }

  func updateImageOCREnabled(_ enabled: Bool) {
    imageOCREnabled = enabled
    if !enabled {
      cancelImageOCRTasks()
    }
  }

  private func captureIfNeeded() {
    let changeCount = pasteboard.changeCount
    guard changeCount != lastChangeCount else {
      return
    }

    lastChangeCount = changeCount

    guard !writeTracker.shouldIgnore(changeCount: changeCount) else {
      return
    }

    guard captureGate.monitoringPolicy.shouldRecord() else {
      return
    }

    let types = pasteboardReader.readTypes()
    let sourceApp = NSWorkspace.shared.frontmostApplication
    let bundleId = sourceApp?.bundleIdentifier

    guard let resolvedPayload = pasteboardReader.readPayload(
      pasteboardTypes: types,
      sourceAppBundleId: bundleId,
      preserveLargeRichTextFormats: preserveLargeRichTextFormats,
      imageOCREnabled: imageOCREnabled
    ) else {
      return
    }
    let payload = resolvedPayload.payload

    guard captureGate.shouldRecord(payload: payload) else {
      return
    }

    let record = store.ingest(
      payload,
      sourceAppBundleId: bundleId,
      sourceAppName: sourceApp?.localizedName
    )
    playCopySoundIfNeeded(for: record)
    scheduleImageOCRIfNeeded(record: record, imageData: resolvedPayload.imageOCRData)
  }

  private func playCopySoundIfNeeded(for record: ClipboardRecord) {
    guard copySoundEnabled, record.copyCount == 1 else {
      return
    }

    NSSound(named: "Tink")?.play()
  }

  private func scheduleImageOCRIfNeeded(record: ClipboardRecord, imageData: Data?) {
    guard imageOCREnabled, record.kind == .image, record.copyCount == 1, let imageData else {
      return
    }

    guard imageOCRTasks.isEmpty else {
      return
    }

    let recordID = record.id
    imageOCRTasks[recordID] = Task { [weak self] in
      guard let self else {
        return
      }

      let recognizedText = await imageOCRService.recognizeText(in: imageData)
      guard !Task.isCancelled else {
        return
      }

      if let recognizedText {
        store.updateOCRText(recordID, text: recognizedText)
      }
      imageOCRTasks[recordID] = nil
    }
  }

  private func cancelImageOCRTasks() {
    imageOCRTasks.values.forEach { $0.cancel() }
    imageOCRTasks.removeAll()
  }
}
