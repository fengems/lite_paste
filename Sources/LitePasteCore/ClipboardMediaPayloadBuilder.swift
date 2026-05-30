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
    pasteboardTypes: Set<String>,
    representations: [ClipboardRichTextRepresentation] = []
  ) throws -> ClipboardPayload {
    let resolvedRepresentations = richTextRepresentations(
      data: data,
      pasteboardType: pasteboardType,
      preferredExtension: preferredExtension,
      representations: representations
    )
    let snapshots = try resolvedRepresentations.map { representation in
      try blobStorage.snapshot(
        data: representation.data,
        pasteboardType: representation.pasteboardType,
        preferredExtension: representation.preferredExtension,
        displayOrder: representation.displayOrder
      )
    }
    let title = plainText.map(textPayloadBuilder.makeTitle(from:)) ?? fallbackTitle
    let contentHashBasis = representations.isEmpty
      ? ContentHasher.hash(kind: kind, data: data)
      : ContentHasher.hash(
        kind: kind,
        typedData: resolvedRepresentations.map { (pasteboardType: $0.pasteboardType, data: $0.data) }
      )

    return ClipboardPayload(
      kind: kind,
      title: title,
      searchText: plainText.map(textPayloadBuilder.makeSearchText(from:)) ?? fallbackTitle,
      plainText: plainText,
      contentHashBasis: contentHashBasis,
      pasteboardTypes: pasteboardTypes,
      contents: snapshots
    )
  }

  private func richTextRepresentations(
    data: Data,
    pasteboardType: String,
    preferredExtension: String,
    representations: [ClipboardRichTextRepresentation]
  ) -> [ClipboardRichTextRepresentation] {
    let sortedRepresentations = representations.sorted { first, second in
      first.displayOrder < second.displayOrder
    }
    guard !sortedRepresentations.isEmpty else {
      return [
        ClipboardRichTextRepresentation(
          data: data,
          pasteboardType: pasteboardType,
          preferredExtension: preferredExtension,
          displayOrder: 0
        )
      ]
    }

    guard !sortedRepresentations.contains(where: { $0.pasteboardType == pasteboardType }) else {
      return sortedRepresentations
    }

    return [
      ClipboardRichTextRepresentation(
        data: data,
        pasteboardType: pasteboardType,
        preferredExtension: preferredExtension,
        displayOrder: 0
      )
    ] + sortedRepresentations.enumerated().map { offset, representation in
      var shifted = representation
      shifted.displayOrder = offset + 1
      return shifted
    }
  }
}
