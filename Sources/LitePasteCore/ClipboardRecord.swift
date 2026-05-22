import Foundation

public struct ClipboardRecord: Identifiable, Codable, Equatable, Sendable {
  public var id: UUID
  public var kind: ClipboardKind
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
  public var plainText: String?

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
    plainText: String? = nil
  ) {
    self.id = id
    self.kind = kind
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
    self.plainText = plainText
  }
}

