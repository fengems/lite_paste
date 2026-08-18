# EcoPaste 参考设置第一版技术方案

本文档记录 Lite Paste 参考 EcoPaste 设置项时的第一版实现边界、数据结构和分阶段计划。

## 目标

第一版目标是把低风险、已有能力可直接承接的设置项落地，并避免出现只有 UI 开关但没有实际行为的“假设置”。

## 第一版范围

- 窗口设置：新增 `屏幕中心` 窗口位置。
- 音效设置：新增 `复制音效` 开关。第一版定义为“新内容成功进入历史记录时播放提示音”。
- 内容设置：拆分 `复制为纯文本` 和 `粘贴为纯文本` 两个独立开关。
- 内容设置：新增 `操作按钮` 自定义弹窗，用于选择卡片和列表右侧展示的快捷按钮。
- 内容设置：新增 `自动收藏`，保存备注后自动收藏该条记录。
- 应用设置：保留并整理 `登录时启动`。
- 应用设置：新增 `显示菜单栏图标` 和 `显示 Dock 图标`。至少保留一个可见入口，避免用户无法打开设置或退出应用。
- 外观设置：新增 `主题模式`，支持跟随系统、亮色模式、暗色模式。

## 后续阶段已实现

- 自动识别图片文字：新增开关，开启后对新复制图片异步识别文字，并缓存到历史记录。OCR 结果可用于搜索，也可在图片记录执行“复制图片文字 / 粘贴为文本”时作为文本内容。手动图片文字操作不受自动识别开关影响。
- 界面语言：新增 `跟随系统`、简中、繁中、日、韩、英设置。第一版保留现有 `AppText.value(中文, 英文)` 调用结构，通过统一语言解析和常用文案翻译表覆盖高频界面；后续可继续迁移到标准 `.lproj` 资源文件。

## 数据结构

`AppSettings` 新增字段：

- `copySoundEnabled: Bool`
- `copyPlainTextByDefault: Bool`
- `pastePlainTextByDefault: Bool`
- `sanitizesSystemClipboardOnCopy: Bool`
- `formatsTablePlainText: Bool`
- `tablePlainTextSeparator: String`
- `tablePlainTextWrapper: TablePlainTextWrapper`
- `visibleQuickActions: Set<ClipboardQuickAction>`
- `autoFavoriteAfterNote: Bool`
- `imageOCREnabled: Bool`
- `showMenuBarIcon: Bool`
- `showDockIcon: Bool`
- `interfaceLanguage: AppLanguage`
- `themeMode: AppThemeMode`

兼容策略：

- 旧字段 `pastePlainByDefault` 作为 legacy key 读取，不再写出。
- 读取旧设置时，`pastePlainByDefault = true` 同时迁移为 `copyPlainTextByDefault = true` 和 `pastePlainTextByDefault = true`，保持历史行为。
- `showMenuBarIcon` 和 `showDockIcon` 归一化时至少保留一个为 `true`。

## 行为设计

### 屏幕中心

新增 `PanelPosition.screenCenter`。面板在当前鼠标所在屏幕的 `visibleFrame` 中居中展示，不覆盖菜单栏和 Dock 区域。

### 纯文本复制和粘贴

- 默认复制：读取 `copyPlainTextByDefault`。
- 默认粘贴：读取 `pastePlainTextByDefault`。
- 剪贴板面板设置按钮左侧提供两个快捷开关，分别修改上述默认设置；开关状态与设置页保持同步。
- 普通复制/粘贴入口（主操作、回车、⌘C、快捷按钮和菜单）都读取默认设置。
- “复制纯文本”和“纯文本粘贴”仍保持为显式操作，不受默认开关影响。

### 系统剪贴板净化

- `sanitizesSystemClipboardOnCopy` 默认关闭。
- 开启后再开启“复制为纯文本”或“粘贴为纯文本”，Lite Paste 监听到其他应用复制富文本或 HTML 时，会把当前系统剪贴板重写为纯文本。
- 历史记录仍先保留原始富文本内容，之后可从卡片显式恢复原格式。
- 文件、图片和没有纯文本副本的内容不重写，避免破坏原始粘贴能力。
- macOS 不提供普通应用可可靠拦截其他应用剪贴板写入的前置钩子；本实现是复制后的自动净化，不是阻断式拦截。

### 表格纯文本整理

- `formatsTablePlainText` 默认关闭。
- 只在粘贴为纯文本的输出路径生效；历史记录保留原始 Tab 分隔文本。
- 单行或多行 Tab 分隔文本都会整理；每个字段去除首尾普通空白、不间断空格、零宽字符和对象替换符。
- 字段内部空白保留；空字段和空行跳过。
- `tablePlainTextSeparator` 支持自定义，但不能为空或包含换行。
- `tablePlainTextWrapper` 仅提供预设：不包裹、英文双引号、英文单引号、中文引号、方括号和花括号。
- 包裹符内出现同类型结束符时通过重复两次转义。

### 复制音效

在 `ClipboardMonitor` 成功写入新历史后播放系统提示音。重复内容只更新计数时不播放，避免高频复制时过度打扰。

### 操作按钮自定义

第一版支持以下按钮：

- 收藏
- 置顶
- 复制
- 复制为纯文本
- 粘贴
- 粘贴为纯文本
- 备注
- 删除
- 外部操作

`更多` 菜单始终保留，用于承载未显示为快捷按钮的操作。

第一版最多展示 4 个快捷按钮。超过 4 个时设置弹窗会禁止继续勾选，避免卡片和列表右侧按钮区域挤压内容。

### 自动收藏

备注编辑保存后，如果备注内容非空且 `autoFavoriteAfterNote = true`，该条记录自动设为收藏。

### 图片 OCR

- 自动识别默认关闭，避免未预期的 CPU 占用。
- 复制图片成功入库后启动异步 OCR，不阻塞剪贴板监听和面板打开。
- OCR 输入限制为 8 MB，超过限制时跳过识别。
- 表格纯文本、Excel、Numbers、WPS/Kingsoft 来源或表格类剪贴板类型会跳过 OCR，避免表格截图/预览触发额外资源占用。
- OCR 同时只运行一个后台任务；已有任务运行时，新图片不会继续排队做 OCR。
- 识别结果写入记录的 `ocrText`，同时追加到 `searchText`，用于搜索命中；不修改标题、预览或原始剪贴板数据。
- 图片记录执行“复制图片文字 / 粘贴为文本”时优先使用 `ocrText`；如果还没有缓存，会按需识别一次并写回缓存。若用户在识别完成前关闭面板或切换走，本次复制/粘贴动作会失效，避免延迟执行打断当前操作。
- OCR 文本和搜索索引追加会压缩空白、保留原搜索词，并按文本搜索字段上限截断。

### 菜单栏和 Dock 图标

- `showMenuBarIcon = false` 时移除菜单栏图标。
- `showDockIcon = true` 时设置 `NSApp.setActivationPolicy(.regular)`。
- `showDockIcon = false` 时设置 `NSApp.setActivationPolicy(.accessory)`。
- 如果用户试图同时关闭菜单栏和 Dock，设置会自动保留菜单栏图标。

### 主题模式

- 跟随系统：`NSApp.appearance = nil`
- 亮色模式：`NSApp.appearance = NSAppearance(named: .aqua)`
- 暗色模式：`NSApp.appearance = NSAppearance(named: .darkAqua)`

### 界面语言

- 默认 `跟随系统`，保持旧版本随系统语言展示中文或英文的行为。
- 支持固定选择：简中、繁中、日、韩、英。
- 当前第一版通过 `AppText` 统一读取 `AppSettings.interfaceLanguage` 并返回对应文案。
- 静态高频文案优先走翻译表；未覆盖的长段落和动态错误信息使用简中或英文兜底，避免显示空字符串。
- 后续如果要做完整国际化，应逐步迁移到标准 `.lproj` / `Localizable.strings` 资源。

## 验证

第一版完成后至少运行：

```bash
swift build
swift run LitePasteCoreChecks
git diff --check
```

涉及 App 外观和菜单栏/Dock 行为的设置，需要人工打开 App 验证。
