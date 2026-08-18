import LitePasteCore

func checkClipboardOCRPolicy() {
  expect(
    ClipboardOCRPolicy.shouldSkipImageOCR(
      pasteboardTypes: ["public.png"],
      sourceAppBundleId: "com.apple.Preview",
      plainText: "A\tB\n1\t2"
    ),
    "OCR policy should skip tabular plain text"
  )
  expect(
    ClipboardOCRPolicy.shouldSkipImageOCR(
      pasteboardTypes: ["public.png"],
      sourceAppBundleId: "com.apple.Preview",
      plainText: "A\tB"
    ),
    "OCR policy should skip single-row tabular plain text"
  )
  expect(
    ClipboardOCRPolicy.shouldSkipImageOCR(
      pasteboardTypes: ["public.png"],
      sourceAppBundleId: "com.microsoft.Excel",
      plainText: nil
    ),
    "OCR policy should skip Excel image payloads"
  )
  expect(
    ClipboardOCRPolicy.shouldSkipImageOCR(
      pasteboardTypes: ["public.png"],
      sourceAppBundleId: "com.apple.iWork.Numbers",
      plainText: nil
    ),
    "OCR policy should skip Numbers image payloads"
  )
  expect(
    ClipboardOCRPolicy.shouldSkipImageOCR(
      pasteboardTypes: ["public.png"],
      sourceAppBundleId: "com.kingsoft.wpsoffice.mac",
      plainText: nil
    ),
    "OCR policy should skip WPS image payloads"
  )
  expect(
    ClipboardOCRPolicy.shouldSkipImageOCR(
      pasteboardTypes: ["com.microsoft.Excel", "public.png"],
      sourceAppBundleId: "com.apple.Preview",
      plainText: nil
    ),
    "OCR policy should skip spreadsheet pasteboard types"
  )
  expect(
    !ClipboardOCRPolicy.shouldSkipImageOCR(
      pasteboardTypes: ["public.png"],
      sourceAppBundleId: "com.apple.Preview",
      plainText: nil
    ),
    "OCR policy should allow ordinary image payloads"
  )
}
