import Foundation
import LitePasteCore

func checkTablePlainTextFormatter() {
  let source = "  A\u{200B}\t\u{00A0}B  \t\tC \n\r\n\t \t\n1\t 2 \t3"
  let disabledFormatter = TablePlainTextFormatter()
  expect(
    disabledFormatter.formatIfTable(source) == source,
    "Table formatter should leave text unchanged when disabled"
  )
  expect(
    TablePlainTextFormatter(isEnabled: true).formatIfTable("A B") == "A B",
    "Table formatter should leave non-tabular text unchanged"
  )

  let formatter = TablePlainTextFormatter(isEnabled: true)
  expect(
    formatter.formatIfTable(source) == "A、B、C\n1、2、3",
    "Table formatter should trim fields, skip empty cells, and preserve rows"
  )
  expect(
    formatter.formatIfTable(" A  B \tC ") == "A  B、C",
    "Table formatter should preserve spaces inside fields"
  )

  let commaFormatter = TablePlainTextFormatter(
    isEnabled: true,
    separator: ", ",
    wrapper: .doubleQuote
  )
  expect(
    commaFormatter.formatIfTable(" A \"x\" \tB ") == "\"A \"\"x\"\"\", \"B\"",
    "Table formatter should support custom separators and escape quote wrappers"
  )

  let wrappedFields = "A\tB"
  let expectedWrappedValues: [TablePlainTextWrapper: String] = [
    .none: "A、B",
    .doubleQuote: "\"A\"、\"B\"",
    .singleQuote: "'A'、'B'",
    .chineseQuote: "“A”、“B”",
    .squareBracket: "[A]、[B]",
    .curlyBrace: "{A}、{B}"
  ]
  for wrapper in TablePlainTextWrapper.allCases {
    let wrappedFormatter = TablePlainTextFormatter(
      isEnabled: true,
      wrapper: wrapper
    )
    expect(
      wrappedFormatter.formatIfTable(wrappedFields) == expectedWrappedValues[wrapper],
      "Table formatter should support \(wrapper.rawValue) wrapper"
    )
  }

  expect(
    TablePlainTextFormatter.normalizedSeparator(" \n ") == "、",
    "Table formatter should reject empty separators"
  )
  expect(
    TablePlainTextFormatter.normalizedSeparator("a\nb") == "、",
    "Table formatter should reject multiline separators"
  )

  let record = ClipboardRecord(
    kind: .text,
    title: "table",
    searchText: "table",
    contentHash: "table",
    plainText: source,
    contents: [
      ClipboardContentSnapshot(
        pasteboardType: PasteboardRestorePlanner.plainTextPasteboardType,
        storageMode: .inline,
        inlineData: Data(source.utf8),
        byteSize: source.utf8.count,
        displayOrder: 0
      )
    ]
  )
  expect(
    PasteboardRestorePlanner().plan(
      for: record,
      asPlainText: true,
      tablePlainTextFormatter: formatter
    ) == .plainText("A、B、C\n1、2、3"),
    "Restore planner should use table formatting for plain-text output"
  )
}
