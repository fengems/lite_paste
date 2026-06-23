@MainActor
enum ClipboardPanelConfirmations {
  static func confirmClearUnpinned(count: Int) -> Bool {
    guard count > 0 else {
      return false
    }

    return UserAlerts.confirm(
      title: AppText.value("清空未置顶历史？", "Clear Unpinned History?"),
      message: AppText.value(
        "将删除 \(count) 条未置顶记录，置顶记录会保留。此操作无法撤销。",
        "\(count) unpinned items will be deleted. Pinned items are kept. This cannot be undone."
      )
    )
  }

  static func confirmClearAll(count: Int) -> Bool {
    guard count > 0 else {
      return false
    }

    return UserAlerts.confirm(
      title: AppText.value("清空全部历史？", "Clear All History?"),
      message: AppText.value(
        "将删除全部 \(count) 条剪贴板历史，包含置顶记录。此操作无法撤销。",
        "All \(count) clipboard history items, including pinned items, will be deleted. This cannot be undone."
      )
    )
  }

  static func confirmDelete(recordTitle: String) -> Bool {
    UserAlerts.confirm(
      title: AppText.value("删除这条历史？", "Delete This Item?"),
      message: AppText.value(
        "“\(recordTitle)”会从剪贴板历史中移除。此操作无法撤销。",
        "\"\(recordTitle)\" will be removed from clipboard history. This cannot be undone."
      )
    )
  }
}
