import AppKit
import SwiftUI

struct PermissionGuideView: View {
  let isAccessibilityTrusted: () -> Bool
  let requestPermission: () -> Void
  let openSystemSettings: () -> Void
  let dismissForSession: () -> Void
  let completeGuide: () -> Void

  @State private var accessibilityTrusted = false

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      header
      essentials
      permissionCard
      actions
    }
    .padding(28)
    .frame(width: 520)
    .background(Color(nsColor: .windowBackgroundColor))
    .onAppear(perform: refreshStatus)
  }

  private var header: some View {
    HStack(spacing: 14) {
      Image(systemName: "hand.raised.circle.fill")
        .font(.system(size: 38, weight: .semibold))
        .foregroundStyle(Color.accentColor)

      VStack(alignment: .leading, spacing: 6) {
        Text(AppText.value("欢迎使用 Lite Paste", "Welcome to Lite Paste"))
          .font(.system(size: 24, weight: .bold))

        Text(AppText.value(
          "完成一次设置后，就可以用菜单栏和快捷键管理剪贴板。",
          "Finish this quick setup to manage your clipboard from the menu bar and keyboard."
        ))
          .font(.system(size: 13))
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var essentials: some View {
    VStack(spacing: 10) {
      guideRow(
        icon: "command",
        title: AppText.value("快速打开", "Open Quickly"),
        description: AppText.value(
          "默认使用 ⌘⇧V 呼出面板，面板内支持搜索、筛选和数字快捷选择。",
          "Press ⌘⇧V to open the panel, then search, filter, or choose items with number shortcuts."
        )
      )
      guideRow(
        icon: "lock.shield",
        title: AppText.value("本地优先", "Local First"),
        description: AppText.value(
          "历史记录默认保存在本机，支持停止监听和按应用忽略。",
          "History is stored on this Mac by default. You can pause monitoring or ignore specific apps."
        )
      )
      guideRow(
        icon: "arrow.turn.down.left",
        title: AppText.value("自动粘贴", "Auto Paste"),
        description: AppText.value(
          "授予辅助功能权限后，选择记录即可回到上一个应用并粘贴。",
          "After Accessibility permission is granted, selecting an item can return to the previous app and paste."
        )
      )
    }
  }

  private func guideRow(icon: String, title: String, description: String) -> some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: icon)
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(Color.accentColor)
        .frame(width: 24, height: 24)

      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(.system(size: 13, weight: .semibold))
        Text(description)
          .font(.system(size: 12))
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var permissionCard: some View {
    VStack(spacing: 0) {
      HStack(alignment: .center, spacing: 12) {
        Image(systemName: accessibilityTrusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
          .font(.system(size: 18, weight: .semibold))
          .foregroundStyle(accessibilityTrusted ? Color.green : Color.orange)

        VStack(alignment: .leading, spacing: 5) {
          Text(AppText.value("辅助功能权限", "Accessibility Permission"))
            .font(.system(size: 15, weight: .semibold))

          Text(accessibilityDescription)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }

        Spacer(minLength: 20)

        Text(accessibilityTrusted ? AppText.value("已授权", "Allowed") : AppText.value("需要授权", "Required"))
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(accessibilityTrusted ? .green : .orange)
      }
      .padding(16)
    }
    .background(Color(nsColor: .controlBackgroundColor).opacity(0.72), in: RoundedRectangle(cornerRadius: 12))
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(Color.primary.opacity(0.09), lineWidth: 1)
    )
  }

  private var actions: some View {
    HStack(spacing: 10) {
      Button(AppText.value("稍后", "Later")) {
        dismissForSession()
      }
      .keyboardShortcut(.cancelAction)

      Spacer()

      Button {
        openSystemSettings()
      } label: {
        Label(AppText.value("打开系统设置", "Open System Settings"), systemImage: "gearshape")
      }

      Button {
        requestPermission()
        refreshStatusAfterDelay()
      } label: {
        Label(AppText.value("请求权限", "Request Permission"), systemImage: "hand.raised")
      }
      .buttonStyle(.borderedProminent)
      .disabled(accessibilityTrusted)

      Button {
        refreshStatus()
      } label: {
        Label(AppText.value("刷新", "Refresh"), systemImage: "arrow.clockwise")
      }
    }
    .controlSize(.regular)
  }

  private var accessibilityDescription: String {
    if accessibilityTrusted {
      return AppText.value("权限已就绪，可以直接使用自动粘贴。", "Permission is ready. Auto paste can be used now.")
    }

    return AppText.value(
      "macOS 会要求你在系统设置中允许 Lite Paste 控制本机，用于发送粘贴快捷键。",
      "macOS will ask you to allow Lite Paste in System Settings so it can send the paste shortcut."
    )
  }

  private func refreshStatus() {
    accessibilityTrusted = isAccessibilityTrusted()
    if accessibilityTrusted {
      completeGuide()
    }
  }

  private func refreshStatusAfterDelay() {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
      refreshStatus()
    }
  }
}
