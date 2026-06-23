import AppKit

struct ClipboardPanelKeyboardActions {
  var close: () -> Void
  var copySelected: (_ asPlainText: Bool) -> Bool
  var deleteSelected: () -> Bool
  var focusSearch: () -> Void
  var navigate: (PanelNavigationKey) -> Bool
  var pasteNumber: (Int) -> Bool
  var pasteSelected: (_ asPlainText: Bool) -> Bool
  var selectRowBoundary: (PanelRowBoundary) -> Bool

  func handle(_ event: NSEvent) -> Bool {
    guard let command = PanelKeyboardCommand.from(event) else {
      return false
    }

    switch command {
    case .close:
      close()
      return true
    case .copySelected:
      return copySelected(false)
    case .copySelectedPlainText:
      return copySelected(true)
    case .deleteSelected:
      return deleteSelected()
    case .focusSearch:
      focusSearch()
      return true
    case let .navigate(key):
      return navigate(key)
    case let .pasteNumber(number):
      return pasteNumber(number)
    case .pasteSelected:
      return pasteSelected(false)
    case .pasteSelectedPlainText:
      return pasteSelected(true)
    case let .rowBoundary(boundary):
      return selectRowBoundary(boundary)
    }
  }
}
