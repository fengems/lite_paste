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
  // Legacy field kept so older history databases/backups can still be decoded.
  public var pinShortcut: String?
  public var contentHash: String
  public var plainText: String?
  public var ocrText: String?
  public var contents: [ClipboardContentSnapshot]
  public var previewFilePath: String?

  private enum CodingKeys: String, CodingKey {
    case id
    case kind
    case title
    case searchText
    case note
    case sourceAppBundleId
    case sourceAppName
    case createdAt
    case lastCopiedAt
    case lastUsedAt
    case copyCount
    case isFavorite
    case isPinned
    case pinShortcut
    case contentHash
    case plainText
    case ocrText
    case contents
    case previewFilePath
  }

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
    plainText: String? = nil,
    ocrText: String? = nil,
    contents: [ClipboardContentSnapshot] = [],
    previewFilePath: String? = nil
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
    self.ocrText = ocrText
    self.contents = contents
    self.previewFilePath = previewFilePath
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(UUID.self, forKey: .id)
    kind = try container.decode(ClipboardKind.self, forKey: .kind)
    title = try container.decode(String.self, forKey: .title)
    searchText = try container.decode(String.self, forKey: .searchText)
    note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
    sourceAppBundleId = try container.decodeIfPresent(String.self, forKey: .sourceAppBundleId)
    sourceAppName = try container.decodeIfPresent(String.self, forKey: .sourceAppName)
    createdAt = try container.decode(Date.self, forKey: .createdAt)
    lastCopiedAt = try container.decode(Date.self, forKey: .lastCopiedAt)
    lastUsedAt = try container.decodeIfPresent(Date.self, forKey: .lastUsedAt)
    copyCount = try container.decodeIfPresent(Int.self, forKey: .copyCount) ?? 1
    isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
    isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
    pinShortcut = try container.decodeIfPresent(String.self, forKey: .pinShortcut)
    contentHash = try container.decode(String.self, forKey: .contentHash)
    plainText = try container.decodeIfPresent(String.self, forKey: .plainText)
    ocrText = try container.decodeIfPresent(String.self, forKey: .ocrText)
    contents = try container.decodeIfPresent([ClipboardContentSnapshot].self, forKey: .contents) ?? []
    previewFilePath = try container.decodeIfPresent(String.self, forKey: .previewFilePath)
  }
}
