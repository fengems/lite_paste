import Foundation

struct SQLiteHistoryQueryRequest {
  var sql: String
  var bindings: [String]
}

enum SQLiteClipboardHistoryQueryBuilder {
  static let selectColumns = SQLiteClipboardRecordColumns.selectedList

  static func recordsRequest(
    for query: ClipboardHistoryQuery,
    limit: Int?,
    offset: Int
  ) -> SQLiteHistoryQueryRequest {
    let predicate = predicateRequest(for: query)
    var sql = "SELECT \(selectColumns) FROM clipboard_records"
    sql += predicate.sql
    sql += " ORDER BY \(orderClause(for: query.sort))"

    if let limit {
      sql += " LIMIT \(max(limit, 0))"
    } else if offset > 0 {
      sql += " LIMIT -1"
    }

    if offset > 0 {
      sql += " OFFSET \(offset)"
    }

    return SQLiteHistoryQueryRequest(sql: sql, bindings: predicate.bindings)
  }

  static func countRequest(for query: ClipboardHistoryQuery) -> SQLiteHistoryQueryRequest {
    let predicate = predicateRequest(for: query)
    return SQLiteHistoryQueryRequest(
      sql: "SELECT COUNT(*) FROM clipboard_records\(predicate.sql)",
      bindings: predicate.bindings
    )
  }

  private static func predicateRequest(for query: ClipboardHistoryQuery) -> SQLiteHistoryQueryRequest {
    var clauses: [String] = []
    var bindings: [String] = []

    if let filterRequest = sqlClause(for: query.filter) {
      clauses.append(filterRequest.sql)
      bindings.append(contentsOf: filterRequest.bindings)
    }

    for term in searchTerms(for: query.text) {
      var termClauses = searchableColumns.map {
        "\($0) LIKE ? ESCAPE '\\' COLLATE NOCASE"
      }
      let pattern = "%\(escapedLikePattern(term))%"
      bindings.append(contentsOf: Array(repeating: pattern, count: termClauses.count))

      let displayNameKinds = ClipboardKind.allCases
        .filter { contains(term, in: $0.displayName) }
        .map(\.rawValue)
      if !displayNameKinds.isEmpty {
        termClauses.append(kindInClause(count: displayNameKinds.count))
        bindings.append(contentsOf: displayNameKinds)
      }

      clauses.append("(\(termClauses.joined(separator: " OR ")))")
    }

    var sql = ""
    if !clauses.isEmpty {
      sql = " WHERE \(clauses.joined(separator: " AND "))"
    }

    return SQLiteHistoryQueryRequest(sql: sql, bindings: bindings)
  }

  private static func sqlClause(for filter: ClipboardFilter) -> SQLiteHistoryQueryRequest? {
    switch filter {
    case .all:
      nil
    case .text:
      kindClause(textKinds)
    case .images:
      kindClause([.image])
    case .files:
      kindClause([.files])
    case .links:
      kindClause([.url, .email])
    case .colors:
      kindClause([.color])
    case .favorites:
      SQLiteHistoryQueryRequest(sql: "is_favorite = 1", bindings: [])
    case .pinned:
      SQLiteHistoryQueryRequest(sql: "is_pinned = 1", bindings: [])
    }
  }

  private static func orderClause(for sort: ClipboardHistorySort) -> String {
    switch sort {
    case .pinnedThenRecent:
      "is_pinned DESC, position ASC"
    case .recent:
      "last_copied_at DESC"
    case .mostUsed:
      "copy_count DESC, last_copied_at DESC"
    }
  }

  private static func searchTerms(for text: String) -> [String] {
    text
      .split(whereSeparator: \.isWhitespace)
      .map(String.init)
  }

  private static func escapedLikePattern(_ text: String) -> String {
    text
      .replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "%", with: "\\%")
      .replacingOccurrences(of: "_", with: "\\_")
  }

  private static func contains(_ term: String, in value: String) -> Bool {
    value.range(of: term, options: [.caseInsensitive, .diacriticInsensitive]) != nil
  }

  private static func kindClause(_ kinds: [ClipboardKind]) -> SQLiteHistoryQueryRequest {
    let rawValues = kinds.map(\.rawValue)
    return SQLiteHistoryQueryRequest(
      sql: kindInClause(count: rawValues.count),
      bindings: rawValues
    )
  }

  private static func kindInClause(count: Int) -> String {
    "kind IN (\(SQLiteClipboardRecordColumns.placeholders(count: count)))"
  }

  private static let textKinds: [ClipboardKind] = [
    .text,
    .richText,
    .html,
    .url,
    .email,
    .color
  ]

  private static let searchableColumns = [
    "title",
    "search_text",
    "ocr_text",
    "note",
    "source_app_name",
    "source_app_bundle_id",
    "kind"
  ]
}
