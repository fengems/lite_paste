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
