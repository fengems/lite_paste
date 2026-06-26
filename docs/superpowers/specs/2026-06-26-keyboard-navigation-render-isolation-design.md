# 键盘导航渲染隔离设计

## 背景

剪贴板面板用键盘方向键切换选中卡片时明显"不跟手"。经系统化排查，根因不在数据层（导航不触发任何数据库查询），而在 SwiftUI 渲染：

- `selectedRecordID` 是 `ClipboardPanelView` 的 `@State`。导航只改这一个值，但会触发整个父级 `body` 重算。
- 该值经 `contentArea` → `ForEach` → `card(for:)`/`row(for:)` 闭包透传，闭包内用 `isSelected: selectedRecordID == record.id` 计算每张卡的选中态。
- 父级 body 重算导致 `ForEach` 重建所有卡片闭包，当前可见的全部卡片（卡片网格一屏约 6–12 张，列表一屏约 10–15 行）的 `body` 都重算。
- 单张卡片 `body` 重算成本高：10+ 个计算属性读取 `isSelected`（背景色、glow 模糊、双层 stroke、shadow 颜色/半径、accentStrip 透明度、quickActions 显隐）；富文本卡片的 `RichClipboardPreview.previewText` 还会每次同步解析 HTML/RTF（`NSAttributedString(data:)`）并做 `contents.sorted(...)`。
- 叠加滚动 `withAnimation(.easeOut(duration: 0.16))`，连按方向键时动画未结束即进入下一次，感知上掉帧。

## 目标

导航时只重绘视觉真正变化的两张卡片（旧选中、新选中），其余卡片跳过 body 重算。不改交互行为、不改选中态语义、不改数据层。

## 非目标

- 不重构选中态的所有权（不引入新 ObservableObject）。
- 不改动 `ClipboardPanelSelection` 的纯计算逻辑。
- 不调整数据加载/分页/搜索流程。

## 方案：EquatableView 阻断卡片自身重算

### 原理

SwiftUI 的 `EquatableView` 在父级传递新值时，先调用 `==` 判断；若相等，跳过该视图的 `body`。父级 `body` 仍会重算、`ForEach` 仍会重建闭包，但每张卡片被 `==` 拦截——只有 `isSelected`（或 `record`）真正变化的两张才进入 `body`，其余直接复用上一帧。

这把"整屏卡片 body 重算"降为"两张卡片 body 重算"，预览的重复解析、装饰层重绘都随之消除。

### 约束与已确认前提

- `ClipboardRecord` 已是 `Equatable`（`ClipboardRecord.swift:3`）。`ID` 为 `Identifiable` 自动推导。
- 卡片/行持有 8 个闭包，闭包无法用 `==` 比较。因此 `==` **只比较驱动渲染的字段**，忽略闭包。
- 闭包忽略是安全的：闭包捕获的是动作目标，不参与渲染像素；若闭包语义变化（极少，如设置变更导致动作重建），由于 `record` 通常也会变化或父级 `id` 不变，不会出现"该重绘而未重绘"的渲染错误。唯一需注意：`visibleQuickActions` 变化必须纳入 `==`，否则切换设置后快捷按钮不刷新。

### `==` 比较字段

`ClipboardCard` 与 `ClipboardRow` 的 `==` 比较：

| 字段 | 含义 | 必须比较 |
|------|------|----------|
| `record.id` | 记录身份/内容变化 | ✅ |
| `isSelected` | 选中态，导航热路径 | ✅ |
| `visibleQuickActions` | 快捷操作设置 | ✅ |

闭包（`primaryAction` 等 8 个）一律忽略。

`externalAction`（`ClipboardExternalAction?`）是无关联值的纯 case 枚举，自动合成 `Equatable`，纳入比较。

### 改动清单

**文件 1：`Sources/LitePaste/ClipboardCard.swift`**

1. 新增 `extension ClipboardCard: Equatable`，实现 `static func ==`，按上表比较。
2. 在 `ClipboardPanelView.card(for:)` 返回处加 `.equatable()`（SwiftUI 的 `View.equatable()` 修饰符，要求视图符合 `Equatable`）。

**文件 2：`Sources/LitePaste/ClipboardRow.swift`**

1. 新增 `extension ClipboardRow: Equatable`，同样规则。
2. 在 `ClipboardPanelView.row(for:)` 返回处加 `.equatable()`。

**文件 3：`Sources/LitePaste/ClipboardPanelView.swift`**

- `card(for:)`（约 `:120`）返回的 `ClipboardCard(...)` 链上加 `.equatable()`。
- `row(for:)`（约 `:139`）返回的 `ClipboardRow(...)` 链上加 `.equatable()`。
- 其余逻辑（导航、选中计算、滚动）不动。

### 不改动的部分

- `ClipboardPanelContentArea` 的 `onChange(of: selectedRecordID)` 滚动逻辑保留——它订阅的是透传进来的 `selectedRecordID` 值，导航时本就该滚动，不属于"多余重绘"。
- 卡片内的 `.onHover`/`withAnimation`、装饰层结构保持不变。
- `selectedRecordID` 继续作为父级 `@State`，选中态语义不变。

## 风险与缓解

| 风险 | 缓解 |
|------|------|
| `==` 漏掉某驱动渲染字段，导致该重绘时不重绘（视觉错误） | `==` 仅忽略闭包；`record`、`isSelected`、`visibleQuickActions` 全覆盖。`externalAction` 视其 `Equatable` 能力决定 |
| `EquatableView` 在 macOS 15 SwiftUI 上未达预期跳过 | 构建后手动 QA：方向键连按观察流畅度；必要时用 Instruments 确认 body 调用次数 |
| 闭包忽略在极特殊场景下漏更新 | 闭包变化场景（设置改动）通常伴随 `visibleQuickActions` 变化，已被 `==` 覆盖；动作目标（copy/paste）逻辑不变，无需重绘 |

## 验证

1. `swift build` 通过。
2. `swift run LitePasteCoreChecks` 通过（核心逻辑未动，作回归基线）。
3. `Scripts/check_worktree_hygiene.sh` 通过。
4. 手动 QA（`Scripts/prepare_manual_check.sh` 或 `swift run LitePaste`）：
   - 卡片模式：方向键上下左右快速连按，观察选中切换是否跟手、滚动是否顺滑。
   - 列表模式：同上。
   - 选中态视觉（高亮、glow、stroke、shadow、快捷按钮显隐）与改动前一致。
   - 点击卡片选中、`Command+1..9` 快速粘贴、复制/粘贴/删除/收藏/置顶/备注等动作正常。
   - 切换 `visibleQuickActions` 设置后，快捷按钮正确刷新。

## 后续可选优化（不在本次范围）

- 富文本/HTML 预览解析结果缓存（按 record id），进一步消除首次/滚动时的解析开销。
- 卡片装饰层（多重 shadow、material、blur）合并，降低单次重绘成本。
- 选中态下沉到独立 ObservableObject，从结构上彻底避免父级 body 重算（更重的重构）。
