import Foundation
import LitePasteCore

@MainActor
final class PanelImageTextResolver {
  private let store: HistoryStore
  private let presentationState: PanelPresentationState
  private let imageOCRService: ImageOCRService
  private var actionRevision = 0
  private var runningTasks: [ClipboardRecord.ID: Int] = [:]

  init(
    store: HistoryStore,
    presentationState: PanelPresentationState,
    imageOCRService: ImageOCRService = ImageOCRService()
  ) {
    self.store = store
    self.presentationState = presentationState
    self.imageOCRService = imageOCRService
  }

  func needsRecognition(_ record: ClipboardRecord) -> Bool {
    guard record.kind == .image else {
      return false
    }

    return !hasUsableText(record.plainText) && !hasUsableText(record.ocrText)
  }

  func resolve(
    for record: ClipboardRecord,
    isPanelVisible: @escaping @MainActor () -> Bool,
    missingContent: @escaping @MainActor () -> Void,
    completion: @escaping @MainActor (ClipboardRecord) -> Void
  ) {
    if let currentRecord = store.record(id: record.id), !needsRecognition(currentRecord) {
      completion(currentRecord)
      return
    }

    guard runningTasks[record.id] == nil else {
      presentationState.showActionMessage(AppText.value("正在识别图片文字", "Recognizing image text"))
      return
    }

    guard let imageData = imageData(for: record) else {
      presentationState.showActionMessage(AppText.value("图片数据不可用", "Image data unavailable"))
      return
    }

    guard imageData.count <= ImageOCRService.maxInputBytes else {
      presentationState.showActionMessage(AppText.value("图片过大，已跳过识别", "Image too large for text recognition"))
      return
    }

    actionRevision += 1
    let revision = actionRevision
    runningTasks[record.id] = revision
    presentationState.showActionMessage(AppText.value("正在识别图片文字", "Recognizing image text"))

    Task { [weak self] in
      guard let self else {
        return
      }

      let text = await imageOCRService.recognizeText(in: imageData)
      if runningTasks[record.id] == revision {
        runningTasks[record.id] = nil
      }

      guard actionRevision == revision, isPanelVisible() else {
        return
      }

      guard let text, hasUsableText(text) else {
        presentationState.showActionMessage(AppText.value("未识别到图片文字", "No image text found"))
        return
      }

      store.updateOCRText(record.id, text: text)
      guard let updatedRecord = store.record(id: record.id) else {
        missingContent()
        return
      }

      completion(updatedRecord)
    }
  }

  func cancelPendingActions() {
    actionRevision += 1
    runningTasks.removeAll()
  }

  private func hasUsableText(_ text: String?) -> Bool {
    guard let text else {
      return false
    }

    return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private func imageData(for record: ClipboardRecord) -> Data? {
    for snapshot in record.contents.sorted(by: { $0.displayOrder < $1.displayOrder }) {
      if let data = data(from: snapshot) {
        return data
      }
    }

    guard let previewFilePath = record.previewFilePath else {
      return nil
    }
    return try? Data(contentsOf: URL(fileURLWithPath: previewFilePath))
  }

  private func data(from snapshot: ClipboardContentSnapshot) -> Data? {
    switch snapshot.storageMode {
    case .inline:
      snapshot.inlineData
    case .external:
      snapshot.externalFilePath.flatMap { try? Data(contentsOf: URL(fileURLWithPath: $0)) }
    }
  }
}
