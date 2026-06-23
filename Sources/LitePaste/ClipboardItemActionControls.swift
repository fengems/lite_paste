import LitePasteCore
import SwiftUI

struct ClipboardItemActionContext {
  let record: ClipboardRecord
  let externalAction: ClipboardExternalAction?
  let copyAction: (ClipboardRecord) -> Void
  let copyPlainTextAction: (ClipboardRecord) -> Void
  let pasteAction: (ClipboardRecord) -> Void
  let pastePlainTextAction: (ClipboardRecord) -> Void
  let performExternalAction: (ClipboardExternalAction) -> Void
  let editNote: () -> Void
  let toggleFavorite: () -> Void
  let togglePinned: () -> Void
  let deleteAction: () -> Void

  var plainTextCopyLabel: String {
    record.kind == .image
      ? AppText.value("复制图片文字", "Copy Image Text")
      : AppText.value("复制纯文本", "Copy Plain Text")
  }

  var plainTextPasteLabel: String {
    record.kind == .image
      ? AppText.value("粘贴为文本", "Paste As Text")
      : AppText.value("纯文本粘贴", "Paste Plain Text")
  }
}

struct ClipboardQuickActionButtons: View {
  let context: ClipboardItemActionContext
  let visibleQuickActions: Set<ClipboardQuickAction>

  var body: some View {
    ForEach(Self.orderedActions(in: visibleQuickActions), id: \.self) { action in
      quickActionButton(action)
    }
  }

  static func hasActions(in visibleQuickActions: Set<ClipboardQuickAction>) -> Bool {
    !orderedActions(in: visibleQuickActions).isEmpty
  }

  private static func orderedActions(in visibleQuickActions: Set<ClipboardQuickAction>) -> [ClipboardQuickAction] {
    Array(ClipboardQuickAction.displayOrder.filter { visibleQuickActions.contains($0) }.prefix(4))
  }

  @ViewBuilder
  private func quickActionButton(_ action: ClipboardQuickAction) -> some View {
    switch action {
    case .favorite:
      IconButton(
        systemName: context.record.isFavorite ? "star.fill" : "star",
        accessibilityLabel: action.localizedDisplayName,
        isActive: context.record.isFavorite,
        tint: .yellow,
        showsInactiveBackground: false,
        action: context.toggleFavorite
      )
    case .pin:
      IconButton(
        systemName: context.record.isPinned ? "pin.fill" : "pin",
        accessibilityLabel: action.localizedDisplayName,
        isActive: context.record.isPinned,
        tint: .blue,
        showsInactiveBackground: false,
        action: context.togglePinned
      )
    case .copy:
      IconButton(
        systemName: action.iconName,
        accessibilityLabel: action.localizedDisplayName,
        action: { context.copyAction(context.record) }
      )
    case .copyPlainText:
      IconButton(
        systemName: action.iconName,
        accessibilityLabel: context.plainTextCopyLabel,
        action: { context.copyPlainTextAction(context.record) }
      )
    case .paste:
      IconButton(
        systemName: action.iconName,
        accessibilityLabel: action.localizedDisplayName,
        action: { context.pasteAction(context.record) }
      )
    case .pastePlainText:
      IconButton(
        systemName: action.iconName,
        accessibilityLabel: context.plainTextPasteLabel,
        action: { context.pastePlainTextAction(context.record) }
      )
    case .note:
      IconButton(
        systemName: context.record.note.isEmpty ? action.iconName : "note.text",
        accessibilityLabel: action.localizedDisplayName,
        isActive: !context.record.note.isEmpty,
        tint: .blue,
        action: context.editNote
      )
    case .delete:
      IconButton(
        systemName: action.iconName,
        accessibilityLabel: action.localizedDisplayName,
        tint: .red,
        action: context.deleteAction
      )
    case .external:
      if let externalAction = context.externalAction {
        IconButton(
          systemName: externalAction.iconName,
          accessibilityLabel: externalAction.accessibilityLabel,
          action: { context.performExternalAction(externalAction) }
        )
      }
    }
  }
}

struct ClipboardItemActionMenuItems: View {
  let context: ClipboardItemActionContext
  var showsSecondaryDivider = false

  var body: some View {
    Button {
      context.pasteAction(context.record)
    } label: {
      Label(AppText.value("粘贴", "Paste"), systemImage: "arrow.turn.down.left")
    }

    Button {
      context.copyAction(context.record)
    } label: {
      Label(AppText.value("复制", "Copy"), systemImage: "doc.on.doc")
    }

    Button {
      context.pastePlainTextAction(context.record)
    } label: {
      Label(context.plainTextPasteLabel, systemImage: ClipboardQuickAction.pastePlainText.iconName)
    }

    Button {
      context.copyPlainTextAction(context.record)
    } label: {
      Label(context.plainTextCopyLabel, systemImage: "doc.plaintext")
    }

    if let externalAction = context.externalAction {
      Button {
        context.performExternalAction(externalAction)
      } label: {
        Label(externalAction.accessibilityLabel, systemImage: externalAction.iconName)
      }
    }

    if showsSecondaryDivider {
      Divider()
    }

    Button(action: context.editNote) {
      Label(
        context.record.note.isEmpty ? AppText.value("添加备注", "Add Note") : AppText.value("编辑备注", "Edit Note"),
        systemImage: "note.text"
      )
    }

    Button(role: .destructive, action: context.deleteAction) {
      Label(AppText.value("删除", "Delete"), systemImage: "trash")
    }
  }
}
