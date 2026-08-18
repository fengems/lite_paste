import Foundation
import LitePasteCore

func checkClipboardPayloadResolver() {
  do {
    try withTemporaryDirectory(prefix: "LitePastePayloadResolverChecks") { directory in
      let resolver = ClipboardPayloadResolver(
        mediaPayloadBuilder: ClipboardMediaPayloadBuilder(
          blobStorage: LocalBlobStorage(directory: directory)
        )
      )
      let pasteboardTypes: Set<String> = [
        ClipboardFilePayloadBuilder.fileURLPasteboardType,
        "public.png",
        "public.html",
        ClipboardTextPayloadBuilder.plainTextPasteboardType,
      ]

      let filePayload = resolver.resolve(
        pasteboardTypes: pasteboardTypes,
        fileURLs: [URL(fileURLWithPath: "/tmp/report.pdf")],
        imageCandidates: [
          ClipboardImageCandidate(
            data: Data("image".utf8), pasteboardType: "public.png", preferredExtension: "png")
        ],
        richTextCandidates: [
          ClipboardRichTextCandidate(
            kind: .html,
            data: Data("<b>Hello</b>".utf8),
            pasteboardType: "public.html",
            preferredExtension: "html",
            fallbackTitle: "HTML"
          )
        ],
        plainText: "hello"
      )
      expect(
        filePayload?.kind == .files, "Payload resolver should prefer files over other candidates")

      let imagePayload = resolver.resolve(
        pasteboardTypes: pasteboardTypes,
        fileURLs: [],
        imageCandidates: [
          ClipboardImageCandidate(
            data: Data("image".utf8), pasteboardType: "public.png", preferredExtension: "png")
        ],
        richTextCandidates: [
          ClipboardRichTextCandidate(
            kind: .html,
            data: Data("<b>Hello</b>".utf8),
            pasteboardType: "public.html",
            preferredExtension: "html",
            fallbackTitle: "HTML"
          )
        ],
        plainText: "hello"
      )
      expect(
        imagePayload?.kind == .image,
        "Payload resolver should prefer images over rich text and text")

      let tabularRichPayload = resolver.resolve(
        pasteboardTypes: pasteboardTypes,
        fileURLs: [],
        imageCandidates: [
          ClipboardImageCandidate(
            data: Data("image".utf8), pasteboardType: "public.png", preferredExtension: "png")
        ],
        richTextCandidates: [
          ClipboardRichTextCandidate(
            kind: .html,
            data: Data("<table><tr><td>A</td><td>B</td></tr></table>".utf8),
            pasteboardType: "public.html",
            preferredExtension: "html",
            fallbackTitle: "HTML"
          )
        ],
        plainText: "A\tB\n1\t2"
      )
      expect(
        tabularRichPayload?.kind == .html,
        "Payload resolver should prefer tabular rich text over image previews")

      let singleRowTabularRichPayload = resolver.resolve(
        pasteboardTypes: pasteboardTypes,
        fileURLs: [],
        imageCandidates: [
          ClipboardImageCandidate(
            data: Data("image".utf8), pasteboardType: "public.png", preferredExtension: "png")
        ],
        richTextCandidates: [
          ClipboardRichTextCandidate(
            kind: .html,
            data: Data("<table><tr><td>A</td><td>B</td></tr></table>".utf8),
            pasteboardType: "public.html",
            preferredExtension: "html",
            fallbackTitle: "HTML"
          )
        ],
        plainText: "A\tB"
      )
      expect(
        singleRowTabularRichPayload?.kind == .html,
        "Payload resolver should prefer single-row tabular rich text over image previews")

      let tabularTextPayload = resolver.resolve(
        pasteboardTypes: pasteboardTypes,
        fileURLs: [],
        imageCandidates: [
          ClipboardImageCandidate(
            data: Data("image".utf8), pasteboardType: "public.png", preferredExtension: "png")
        ],
        richTextCandidates: [],
        plainText: "A\tB\n1\t2"
      )
      expect(
        tabularTextPayload?.kind == .text,
        "Payload resolver should keep tabular plain text out of image history")

      let singleRowTabularTextPayload = resolver.resolve(
        pasteboardTypes: pasteboardTypes,
        fileURLs: [],
        imageCandidates: [
          ClipboardImageCandidate(
            data: Data("image".utf8), pasteboardType: "public.png", preferredExtension: "png")
        ],
        richTextCandidates: [],
        plainText: "A\tB"
      )
      expect(
        singleRowTabularTextPayload?.kind == .text,
        "Payload resolver should keep single-row tabular plain text out of image history")

      let richPayload = resolver.resolve(
        pasteboardTypes: pasteboardTypes,
        fileURLs: [],
        imageCandidates: [],
        richTextCandidates: [
          ClipboardRichTextCandidate(
            kind: .html,
            data: Data("<b>Hello</b>".utf8),
            pasteboardType: "public.html",
            preferredExtension: "html",
            fallbackTitle: "HTML"
          ),
          ClipboardRichTextCandidate(
            kind: .richText,
            data: Data("{\\rtf1 Hello}".utf8),
            pasteboardType: "public.rtf",
            preferredExtension: "rtf",
            fallbackTitle: "富文本"
          ),
        ],
        plainText: "hello"
      )
      expect(
        richPayload?.kind == .html, "Payload resolver should prefer the first rich text candidate")

      let highFidelityRichPayload = resolver.resolve(
        pasteboardTypes: ["public.html", "com.microsoft.Excel"],
        fileURLs: [],
        imageCandidates: [],
        richTextCandidates: [
          ClipboardRichTextCandidate(
            kind: .html,
            data: Data("<b>1</b>".utf8),
            pasteboardType: "public.html",
            preferredExtension: "html",
            fallbackTitle: "HTML",
            representations: [
              ClipboardRichTextRepresentation(
                data: Data("formula".utf8),
                pasteboardType: "com.microsoft.Excel",
                preferredExtension: "pbdata",
                displayOrder: 0
              ),
              ClipboardRichTextRepresentation(
                data: Data("<b>1</b>".utf8),
                pasteboardType: "public.html",
                preferredExtension: "html",
                displayOrder: 1
              ),
            ]
          )
        ],
        plainText: "1"
      )
      expect(
        highFidelityRichPayload?.contents.map(\.pasteboardType) == [
          "com.microsoft.Excel", "public.html",
        ],
        "Payload resolver should pass through original rich text representations"
      )

      let textPayload = resolver.resolve(
        pasteboardTypes: [ClipboardTextPayloadBuilder.plainTextPasteboardType],
        fileURLs: [],
        imageCandidates: [],
        richTextCandidates: [],
        plainText: "hello"
      )
      expect(textPayload?.kind == .text, "Payload resolver should fall back to plain text")

      let emptyPayload = resolver.resolve(
        pasteboardTypes: [],
        fileURLs: [],
        imageCandidates: [],
        richTextCandidates: [],
        plainText: " \n "
      )
      expect(emptyPayload == nil, "Payload resolver should ignore blank fallback text")
    }
  } catch {
    fatalError("Payload resolver check failed: \(error)")
  }
}
