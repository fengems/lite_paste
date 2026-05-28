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
    VStack(alignment: .leading, spacing: 22) {
      header
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
        Text("完成权限设置")
          .font(.system(size: 24, weight: .bold))

        Text("Lite Paste 需要辅助功能权限来执行自动粘贴和置顶快捷粘贴。")
          .font(.system(size: 13))
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
          Text("辅助功能权限")
            .font(.system(size: 15, weight: .semibold))

          Text(accessibilityDescription)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }

        Spacer(minLength: 20)

        Text(accessibilityTrusted ? "已授权" : "需要授权")
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
      Button("稍后") {
        dismissForSession()
      }
      .keyboardShortcut(.cancelAction)

      Spacer()

      Button {
        openSystemSettings()
      } label: {
        Label("打开系统设置", systemImage: "gearshape")
      }

      Button {
        requestPermission()
        refreshStatusAfterDelay()
      } label: {
        Label("请求权限", systemImage: "hand.raised")
      }
      .buttonStyle(.borderedProminent)
      .disabled(accessibilityTrusted)

      Button {
        refreshStatus()
      } label: {
        Label("刷新", systemImage: "arrow.clockwise")
      }
    }
    .controlSize(.regular)
  }

  private var accessibilityDescription: String {
    if accessibilityTrusted {
      return "权限已就绪，可以直接使用自动粘贴。"
    }

    return "macOS 会要求你在系统设置中允许 Lite Paste 控制本机，用于发送粘贴快捷键。"
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
