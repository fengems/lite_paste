import Foundation

public final class ClipboardItem: Identifiable, Codable {
  public var id: UUID
  public var kindRawValue: String
  public var title: String
  public var searchText: String
  public var note: String
  public var sourceAppBundleId: String?
  public var sourceAppName: String?
  public var createdAt: Date
  public var lastCopiedAt: Date
  public var lastUsedAt: Date?
  public var copyCount: Int
  public var isFavorite: Bool
  public var isPinned: Bool
  public var pinShortcut: String?
  public var contentHash: String
  public var contents: [ClipboardContent]

  public init(
    id: UUID = UUID(),
    kind: ClipboardKind,
    title: String,
    searchText: String,
    note: String = "",
    sourceAppBundleId: String? = nil,
    sourceAppName: String? = nil,
    createdAt: Date = .now,
    lastCopiedAt: Date = .now,
    lastUsedAt: Date? = nil,
    copyCount: Int = 1,
    isFavorite: Bool = false,
    isPinned: Bool = false,
    pinShortcut: String? = nil,
    contentHash: String,
    contents: [ClipboardContent] = []
  ) {
    self.id = id
    self.kindRawValue = kind.rawValue
    self.title = title
    self.searchText = searchText
    self.note = note
    self.sourceAppBundleId = sourceAppBundleId
    self.sourceAppName = sourceAppName
    self.createdAt = createdAt
    self.lastCopiedAt = lastCopiedAt
    self.lastUsedAt = lastUsedAt
    self.copyCount = copyCount
    self.isFavorite = isFavorite
    self.isPinned = isPinned
    self.pinShortcut = pinShortcut
    self.contentHash = contentHash
    self.contents = contents
  }

  public var kind: ClipboardKind {
    ClipboardKind(rawValue: kindRawValue) ?? .unknown
  }
}

public final class ClipboardContent: Identifiable, Codable {
  public var id: UUID
  public var pasteboardType: String
  public var storageModeRawValue: String
  public var inlineData: Data?
  public var externalFilePath: String?
  public var byteSize: Int
  public var displayOrder: Int

  public init(
    id: UUID = UUID(),
    pasteboardType: String,
    storageMode: ClipboardStorageMode,
    inlineData: Data? = nil,
    externalFilePath: String? = nil,
    byteSize: Int = 0,
    displayOrder: Int = 0
  ) {
    self.id = id
    self.pasteboardType = pasteboardType
    self.storageModeRawValue = storageMode.rawValue
    self.inlineData = inlineData
    self.externalFilePath = externalFilePath
    self.byteSize = byteSize
    self.displayOrder = displayOrder
  }

  public var storageMode: ClipboardStorageMode {
    ClipboardStorageMode(rawValue: storageModeRawValue) ?? .inline
  }
}

public enum ClipboardStorageMode: String, Codable, Sendable {
  case inline
  case external
}
