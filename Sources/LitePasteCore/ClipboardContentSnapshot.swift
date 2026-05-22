import Foundation

public struct ClipboardContentSnapshot: Codable, Equatable, Sendable {
  public var pasteboardType: String
  public var storageMode: ClipboardStorageMode
  public var inlineData: Data?
  public var externalFilePath: String?
  public var byteSize: Int
  public var displayOrder: Int

  public init(
    pasteboardType: String,
    storageMode: ClipboardStorageMode,
    inlineData: Data? = nil,
    externalFilePath: String? = nil,
    byteSize: Int,
    displayOrder: Int
  ) {
    self.pasteboardType = pasteboardType
    self.storageMode = storageMode
    self.inlineData = inlineData
    self.externalFilePath = externalFilePath
    self.byteSize = byteSize
    self.displayOrder = displayOrder
  }
}

