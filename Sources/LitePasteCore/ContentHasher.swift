import CryptoKit
import Foundation

public enum ContentHasher {
  public static func hash(kind: ClipboardKind, text: String) -> String {
    let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
    let bytes = Data("\(kind.rawValue):\(normalized)".utf8)
    let digest = SHA256.hash(data: bytes)
    return digest.map { String(format: "%02x", $0) }.joined()
  }
}

