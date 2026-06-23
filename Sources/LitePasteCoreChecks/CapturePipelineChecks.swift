import Foundation
import LitePasteCore

func checkClipboardMediaPayloadBuilder() {
  do {
    try withTemporaryDirectory(prefix: "LitePasteMediaPayloadChecks") { directory in
      let storage = LocalBlobStorage(directory: directory)
      let builder = ClipboardMediaPayloadBuilder(blobStorage: storage)

      let imageData = Data("png-data".utf8)
      let imagePayload = try builder.imagePayload(
        data: imageData,
        pasteboardType: "public.png",
        preferredExtension: "png",
        pasteboardTypes: ["public.png"]
      )

      expect(imagePayload.kind == .image, "Media payload builder should create image payloads")
      expect(imagePayload.title == "图片", "Image payload should use localized image title")
      expect(
        imagePayload.searchText == "图片 image", "Image payload should include searchable image terms"
      )
      expect(
        imagePayload.contentHashBasis == ContentHasher.hash(kind: .image, data: imageData),
        "Image payload should hash from original image data"
      )
      expect(imagePayload.contents.count == 1, "Image payload should include one blob snapshot")
      expect(
        imagePayload.contents.first?.pasteboardType == "public.png",
        "Image payload should preserve pasteboard type")
      expect(
        imagePayload.previewFilePath == imagePayload.contents.first?.externalFilePath,
        "Image payload should use blob path for preview")
      if let previewFilePath = imagePayload.previewFilePath {
        expect(
          FileManager.default.fileExists(atPath: previewFilePath),
          "Image payload should persist preview blob")
      } else {
        fatalError("Image payload should include preview path")
      }

      let htmlData = Data("<b>Hello</b>".utf8)
      let htmlPayload = try builder.richTextPayload(
        kind: .html,
        data: htmlData,
        pasteboardType: "public.html",
        preferredExtension: "html",
        fallbackTitle: "HTML",
        plainText: "Hello\nWorld",
        pasteboardTypes: ["public.html", "public.utf8-plain-text"]
      )

      expect(htmlPayload.kind == .html, "Media payload builder should create HTML payloads")
      expect(htmlPayload.title == "Hello World", "Rich payload should compact plain-text titles")
      expect(
        htmlPayload.searchText == "Hello\nWorld",
        "Rich payload should search by plain text when available")
      expect(
        htmlPayload.plainText == "Hello\nWorld", "Rich payload should preserve plain text fallback")
      expect(
        htmlPayload.contentHashBasis == ContentHasher.hash(kind: .html, data: htmlData),
        "Rich payload should hash from rich data"
      )
      expect(
        htmlPayload.contents.first?.pasteboardType == "public.html",
        "Rich payload should preserve pasteboard type")

      let excelPrivateData = Data("formula".utf8)
      let highFidelityPayload = try builder.richTextPayload(
        kind: .html,
        data: htmlData,
        pasteboardType: "public.html",
        preferredExtension: "html",
        fallbackTitle: "HTML",
        plainText: "1",
        pasteboardTypes: ["public.html", "public.utf8-plain-text", "com.microsoft.Excel"],
        representations: [
          ClipboardRichTextRepresentation(
            data: excelPrivateData,
            pasteboardType: "com.microsoft.Excel",
            preferredExtension: "pbdata",
            displayOrder: 0
          ),
          ClipboardRichTextRepresentation(
            data: htmlData,
            pasteboardType: "public.html",
            preferredExtension: "html",
            displayOrder: 1
          ),
        ]
      )

      expect(
        highFidelityPayload.contents.count == 2,
        "Rich payload should preserve original representations")
      expect(
        highFidelityPayload.contents.map(\.pasteboardType) == [
          "com.microsoft.Excel", "public.html",
        ],
        "Rich payload should keep original representation order"
      )
      expect(
        highFidelityPayload.contentHashBasis
          == ContentHasher.hash(
            kind: .html,
            typedData: [
              (pasteboardType: "com.microsoft.Excel", data: excelPrivateData),
              (pasteboardType: "public.html", data: htmlData),
            ]
          ),
        "Rich payload should hash from every original representation"
      )

      let rtfData = Data("{\\rtf1 text}".utf8)
      let rtfPayload = try builder.richTextPayload(
        kind: .richText,
        data: rtfData,
        pasteboardType: "public.rtf",
        preferredExtension: "rtf",
        fallbackTitle: "富文本",
        plainText: nil,
        pasteboardTypes: ["public.rtf"]
      )

      expect(rtfPayload.kind == .richText, "Media payload builder should create RTF payloads")
      expect(rtfPayload.title == "富文本", "Rich payload should use fallback title without plain text")
      expect(
        rtfPayload.searchText == "富文本",
        "Rich payload should use fallback search text without plain text")
      expect(rtfPayload.plainText == nil, "Rich payload should allow missing plain text")
    }
  } catch {
    fatalError("Media payload builder check failed: \(error)")
  }
}
