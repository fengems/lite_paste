import Foundation

public struct ClipboardFilePayloadBuilder: Sendable {
  public static let fileURLPasteboardType = "public.file-url"

  public init() {}

  public func payload(from fileURLs: [URL], pasteboardTypes: Set<String>) -> ClipboardPayload? {
    let fileURLs = fileURLs.filter(\.isFileURL)
    guard !fileURLs.isEmpty else {
      return nil
    }

    let paths = fileURLs.map(\.path)
    let text = paths.joined(separator: "\n")

    return ClipboardPayload(
      kind: .files,
      title: title(for: fileURLs),
      searchText: text,
      plainText: text,
      contentHashBasis: text,
      pasteboardTypes: pasteboardTypes,
      contents: paths.enumerated().map { index, path in
        let data = Data(path.utf8)
        return ClipboardContentSnapshot(
          pasteboardType: Self.fileURLPasteboardType,
          storageMode: .inline,
          inlineData: data,
          byteSize: data.count,
          displayOrder: index
        )
      }
    )
  }

  public func title(for fileURLs: [URL]) -> String {
    let fileURLs = fileURLs.filter(\.isFileURL)
    guard !fileURLs.isEmpty else {
      return ""
    }

    let names = fileURLs.map(\.lastPathComponent)
    if names.count == 1 {
      return names[0]
    }

    return "\(names.count) 个文件: \(names.prefix(3).joined(separator: ", "))"
  }
}
