import Foundation

enum ClipboardHistoryPagination {
  static func slice(_ records: [ClipboardRecord], limit: Int?, offset: Int) -> [ClipboardRecord] {
    let offset = min(max(offset, 0), records.count)
    let records = records.dropFirst(offset)
    guard let limit else {
      return Array(records)
    }

    return Array(records.prefix(max(limit, 0)))
  }
}
