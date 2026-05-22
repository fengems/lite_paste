import CryptoKit
import Foundation

public enum ContentHasher {
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

  private static func hash(data: Data) -> String {
    let digest = SHA256.hash(data: data)
    return digest.map { String(format: "%02x", $0) }.joined()
  }
}
