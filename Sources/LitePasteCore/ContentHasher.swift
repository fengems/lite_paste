import CryptoKit
import Foundation

public enum ContentHasher {
  private static let separator = Data([0])

  public static func hash(kind: ClipboardKind, text: String) -> String {
    let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
    let bytes = Data("\(kind.rawValue):\(normalized)".utf8)
    return hash(data: bytes)
  }

  public static func hash(kind: ClipboardKind, data: Data) -> String {
    var bytes = Data(kind.rawValue.utf8)
    bytes.append(0)
    bytes.append(data)
    return hash(data: bytes)
  }

  public static func hash(kind: ClipboardKind, typedData: [(pasteboardType: String, data: Data)]) -> String {
    var hasher = SHA256()
    hasher.update(data: Data(kind.rawValue.utf8))
    hasher.update(data: separator)

    for item in typedData {
      hasher.update(data: Data(item.pasteboardType.utf8))
      hasher.update(data: separator)
      hasher.update(data: Data(String(item.data.count).utf8))
      hasher.update(data: separator)
      hasher.update(data: item.data)
      hasher.update(data: separator)
    }

    return digestString(hasher.finalize())
  }

  private static func hash(data: Data) -> String {
    let digest = SHA256.hash(data: data)
    return digestString(digest)
  }

  private static func digestString<Digest: Sequence>(_ digest: Digest) -> String where Digest.Element == UInt8 {
    return digest.map { String(format: "%02x", $0) }.joined()
  }
}
