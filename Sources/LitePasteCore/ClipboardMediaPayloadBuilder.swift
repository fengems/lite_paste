import Foundation

public struct ClipboardMediaPayloadBuilder: Sendable {
  private let blobStorage: any BlobStorage
  private let textPayloadBuilder: ClipboardTextPayloadBuilder

  public init(
    blobStorage: any BlobStorage = LocalBlobStorage(),
    textPayloadBuilder: ClipboardTextPayloadBuilder = ClipboardTextPayloadBuilder()
  ) {
    self.blobStorage = blobStorage
    self.textPayloadBuilder = textPayloadBuilder
  }

  public func imagePayload(
    data: Data,
    pasteboardType: String,
    preferredExtension: String,
    pasteboardTypes: Set<String>
  ) throws -> ClipboardPayload {
    let snapshot = try blobStorage.snapshot(
      data: data,
      pasteboardType: pasteboardType,
      preferredExtension: preferredExtension,
      displayOrder: 0
    )

    return ClipboardPayload(
      kind: .image,
      title: "图片",
      searchText: "图片 image",
      contentHashBasis: ContentHasher.hash(kind: .image, data: data),
      pasteboardTypes: pasteboardTypes,
      contents: [snapshot],
      previewFilePath: snapshot.externalFilePath
    )
  }

  public func richTextPayload(
    kind: ClipboardKind,
    data: Data,
    pasteboardType: String,
    preferredExtension: String,
    fallbackTitle: String,
    plainText: String?,
    pasteboardTypes: Set<String>
  ) throws -> ClipboardPayload {
    let snapshot = try blobStorage.snapshot(
      data: data,
      pasteboardType: pasteboardType,
      preferredExtension: preferredExtension,
      displayOrder: 0
    )
    let title = plainText.map(textPayloadBuilder.makeTitle(from:)) ?? fallbackTitle

    return ClipboardPayload(
      kind: kind,
      title: title,
      searchText: plainText ?? fallbackTitle,
      plainText: plainText,
      contentHashBasis: ContentHasher.hash(kind: kind, data: data),
      pasteboardTypes: pasteboardTypes,
      contents: [snapshot]
    )
  }
}
