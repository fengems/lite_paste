import Foundation

public struct PasteboardRestorePlanner: Sendable {
  public static let plainTextPasteboardType = "public.utf8-plain-text"

  private let readExternalData: @Sendable (String) -> Data?

  public init(
    readExternalData: @escaping @Sendable (String) -> Data? = {
      try? Data(contentsOf: URL(fileURLWithPath: $0))
    }
  ) {
    self.readExternalData = readExternalData
  }

  public func plan(
    for record: ClipboardRecord,
    asPlainText: Bool = false,
    tablePlainTextFormatter: TablePlainTextFormatter? = nil
  ) -> PasteboardRestorePlan? {
    if asPlainText {
      return plainTextPlan(
        for: record,
        tablePlainTextFormatter: tablePlainTextFormatter
      )
    }

    if let filePlan = fileURLPlan(for: record) {
      return filePlan
    }

    if let itemPlan = itemPlan(for: record) {
      return itemPlan
    }

    guard record.contents.isEmpty else {
      return nil
    }

    return plainTextPlan(for: record)
  }

  private func plainTextPlan(
    for record: ClipboardRecord,
    tablePlainTextFormatter: TablePlainTextFormatter? = nil
  ) -> PasteboardRestorePlan? {
    guard let plainText = firstNonBlankText(record.plainText, record.ocrText) else {
      return nil
    }

    return .plainText(tablePlainTextFormatter?.formatIfTable(plainText) ?? plainText)
  }

  private func firstNonBlankText(_ candidates: String?...) -> String? {
    candidates.first { candidate in
      guard let candidate else {
        return false
      }
      return !candidate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    } ?? nil
  }

  private func fileURLPlan(for record: ClipboardRecord) -> PasteboardRestorePlan? {
    guard record.kind == .files else {
      return nil
    }

    if !record.contents.isEmpty {
      var contentFileURLs: [URL] = []
      for snapshot in record.contents.sorted(by: { $0.displayOrder < $1.displayOrder }) {
        guard let url = fileURL(from: snapshot) else {
          return nil
        }

        contentFileURLs.append(url)
      }

      return contentFileURLs.isEmpty ? nil : .fileURLs(contentFileURLs)
    }

    let fileURLs = fileURLs(from: record.plainText)

    guard !fileURLs.isEmpty else {
      return nil
    }

    return .fileURLs(fileURLs)
  }

  private func fileURL(from snapshot: ClipboardContentSnapshot) -> URL? {
    guard let data = data(for: snapshot),
          let path = String(data: data, encoding: .utf8),
          !path.isEmpty else {
      return nil
    }

    return URL(fileURLWithPath: path)
  }

  private func fileURLs(from plainText: String?) -> [URL] {
    guard let plainText else {
      return []
    }

    return plainText
      .split(separator: "\n")
      .map { URL(fileURLWithPath: String($0)) }
  }

  private func itemPlan(for record: ClipboardRecord) -> PasteboardRestorePlan? {
    var items: [PasteboardRestoreItem] = []
    for snapshot in record.contents.sorted(by: { $0.displayOrder < $1.displayOrder }) {
      guard let item = restoreItem(from: snapshot) else {
        return nil
      }

      items.append(item)
    }

    var restoredItems = items
    if let plainText = record.plainText,
       !plainText.isEmpty,
       !restoredItems.contains(where: { $0.pasteboardType == Self.plainTextPasteboardType }) {
      restoredItems.append(
        PasteboardRestoreItem(
          pasteboardType: Self.plainTextPasteboardType,
          data: Data(plainText.utf8)
        )
      )
    }

    guard !restoredItems.isEmpty else {
      return nil
    }

    return .items(restoredItems)
  }

  private func restoreItem(from snapshot: ClipboardContentSnapshot) -> PasteboardRestoreItem? {
    guard let data = data(for: snapshot) else {
      return nil
    }

    return PasteboardRestoreItem(pasteboardType: snapshot.pasteboardType, data: data)
  }

  private func data(for snapshot: ClipboardContentSnapshot) -> Data? {
    switch snapshot.storageMode {
    case .inline:
      snapshot.inlineData
    case .external:
      snapshot.externalFilePath.flatMap(readExternalData)
    }
  }
}
