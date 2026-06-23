enum SQLiteClipboardRecordColumns {
  static let selected = SQLiteClipboardRecordColumn.selected.map(\.rawValue)
  static let writable = SQLiteClipboardRecordColumn.writable.map(\.rawValue)

  static let selectedList = selected.joined(separator: ", ")
  static let writableList = writable.joined(separator: ", ")
  static let writablePlaceholders = placeholders(count: writable.count)
  static let upsertAssignments = writable
    .dropFirst()
    .map { "\($0) = excluded.\($0)" }
    .joined(separator: ",\n      ")

  static func placeholders(count: Int) -> String {
    Array(repeating: "?", count: count).joined(separator: ", ")
  }
}

enum SQLiteClipboardRecordColumn: String, CaseIterable {
  case id = "id"
  case kind = "kind"
  case title = "title"
  case searchText = "search_text"
  case note = "note"
  case sourceAppBundleId = "source_app_bundle_id"
  case sourceAppName = "source_app_name"
  case createdAt = "created_at"
  case lastCopiedAt = "last_copied_at"
  case lastUsedAt = "last_used_at"
  case copyCount = "copy_count"
  case isFavorite = "is_favorite"
  case isPinned = "is_pinned"
  case pinShortcut = "pin_shortcut"
  case contentHash = "content_hash"
  case plainText = "plain_text"
  case ocrText = "ocr_text"
  case contentsJSON = "contents_json"
  case previewFilePath = "preview_file_path"
  case position = "position"

  static let selected = allCases.filter { $0 != .position }
  static let writable = allCases

  var selectedIndex: Int32 {
    guard let index = Self.selected.firstIndex(of: self) else {
      preconditionFailure("\(rawValue) is not part of the selected clipboard record columns")
    }

    return Int32(index)
  }

  var bindingIndex: Int32 {
    guard let index = Self.writable.firstIndex(of: self) else {
      preconditionFailure("\(rawValue) is not part of the writable clipboard record columns")
    }

    return Int32(index + 1)
  }
}
