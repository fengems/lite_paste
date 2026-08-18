import Foundation
import LitePasteCore

func checkSystemClipboardPlainTextPolicy() {
  let payload = ClipboardPayload(
    kind: .html,
    title: "table",
    searchText: "table",
    plainText: "A\tB",
    pasteboardTypes: ["public.html", PasteboardRestorePlanner.plainTextPasteboardType]
  )

  expect(
    SystemClipboardPlainTextPolicy(
      sanitizesSystemClipboardOnCopy: true,
      copyPlainTextByDefault: true
    ).shouldRewrite(payload: payload),
    "System clipboard sanitization should rewrite rich text for plain-text copy"
  )
  expect(
    SystemClipboardPlainTextPolicy(
      sanitizesSystemClipboardOnCopy: true,
      copyPlainTextByDefault: false,
      pastePlainTextByDefault: true
    ).shouldRewrite(payload: payload),
    "System clipboard sanitization should rewrite rich text for plain-text paste"
  )
  expect(
    !SystemClipboardPlainTextPolicy(
      sanitizesSystemClipboardOnCopy: false,
      copyPlainTextByDefault: true
    ).shouldRewrite(payload: payload),
    "System clipboard sanitization should stay off when its setting is off"
  )
  expect(
    !SystemClipboardPlainTextPolicy(
      sanitizesSystemClipboardOnCopy: true,
      copyPlainTextByDefault: false
    ).shouldRewrite(payload: payload),
    "System clipboard sanitization should stay off without plain-text copy or paste"
  )

  let nonTextPayload = ClipboardPayload(
    kind: .files,
    title: "files",
    searchText: "/tmp/a.txt",
    plainText: "/tmp/a.txt",
    pasteboardTypes: ["public.file-url"]
  )
  expect(
    !SystemClipboardPlainTextPolicy(
      sanitizesSystemClipboardOnCopy: true,
      copyPlainTextByDefault: true
    ).shouldRewrite(payload: nonTextPayload),
    "System clipboard sanitization should preserve file payloads"
  )

  let blankRichTextPayload = ClipboardPayload(
    kind: .richText,
    title: "blank",
    searchText: "blank",
    plainText: " \n ",
    pasteboardTypes: ["public.rtf"]
  )
  expect(
    !SystemClipboardPlainTextPolicy(
      sanitizesSystemClipboardOnCopy: true,
      copyPlainTextByDefault: true
    ).shouldRewrite(payload: blankRichTextPayload),
    "System clipboard sanitization should not create an empty clipboard"
  )
}
