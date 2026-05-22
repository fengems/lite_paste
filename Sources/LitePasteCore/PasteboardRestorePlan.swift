import Foundation

public struct PasteboardRestoreItem: Equatable, Sendable {
  public var pasteboardType: String
  public var data: Data

  public init(pasteboardType: String, data: Data) {
    self.pasteboardType = pasteboardType
    self.data = data
  }
}

public enum PasteboardRestorePlan: Equatable, Sendable {
  case fileURLs([URL])
  case items([PasteboardRestoreItem])
  case plainText(String)
}

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

  public func plan(for record: ClipboardRecord, asPlainText: Bool = false) -> PasteboardRestorePlan? {
    if asPlainText {
      return plainTextPlan(for: record)
    }

    if let filePlan = fileURLPlan(for: record) {
      return filePlan
    }

    if let itemPlan = itemPlan(for: record) {
      return itemPlan
    }

    return plainTextPlan(for: record)
  }

  private func plainTextPlan(for record: ClipboardRecord) -> PasteboardRestorePlan? {
    guard let plainText = record.plainText else {
      return nil
    }

    return .plainText(plainText)
  }

  private func fileURLPlan(for record: ClipboardRecord) -> PasteboardRestorePlan? {
    guard record.kind == .files else {
      return nil
    }

    let contentFileURLs = record.contents
      .sorted { $0.displayOrder < $1.displayOrder }
      .compactMap(fileURL)
    let fileURLs = contentFileURLs.isEmpty ? fileURLs(from: record.plainText) : contentFileURLs

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
    let items = record.contents
      .sorted { $0.displayOrder < $1.displayOrder }
      .compactMap(restoreItem)

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
