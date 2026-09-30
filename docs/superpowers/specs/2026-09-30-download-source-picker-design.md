# 下载来源选择器 设计文档

**日期：** 2026-09-30
**状态：** 已批准

## 背景

`lib/ui/download/episode_selection_tab.dart` 在每一集的下载选择行里，会把该集所有可下载来源按优先级 join 成一行文字展示（例如 "xifan / agedm / omofun"），但这行文字目前只是**展示**用的——用户无法点选。实际下载时永远使用 `EpisodeDownloadOption.preferred`（即 `candidates.first`，按 `download_source_resolver.dart:9` 中硬编码的 `downloadableSourcePriority = ['anime1', 'xifan', 'agedm', 'omofun']` 顺序自动选出）。

用户希望能手动选择某一集从哪个来源下载。

## 现状确认（已调研）

- `DownloadQueueController.enqueue({required episode, ...})`（`lib/domain/download/download_queue_controller.dart:82`）已经接受任意 `MergedEpisode`，内部不做二次来源解析——`episode.sourceId` 直接进入 `DownloadRequest`。**下载队列/worker 完全不需要改动**，改动范围仅在 UI 层。
- 在线播放侧已有现成的"切换线路"底部弹窗组件 `LineSwitchSheet`（`lib/ui/player/line_switch_sheet.dart`），交互模式（列表 + 当前项打勾 + 点击回调）可直接参考复用（不共享代码，因为类型不同：`MediaPlaybackSource` vs `MergedEpisode`）。

## 设计

### 交互

1. 每一集的下载选择行里，"xifan / agedm / omofun" 这行文字：
   - 当 `option.candidates.length > 1` 时可点击（`InkWell`/`GestureDetector` 包裹），点击后弹出底部选择框。
   - 当只有 1 个候选来源时，保持原样不可点击（无变化）。
2. 底部选择框（新组件 `DownloadSourcePickerSheet`，放在 `lib/ui/download/` 下，结构参考 `LineSwitchSheet`）：列出 `option.candidates`，每项显示 `sourceId`；当前生效来源（见下）打勾；点击某项后关闭弹窗并记录选择。
3. 收起状态下的文字展示：当前生效来源（用户手动选的，或默认的 `preferred`）在 join 的文字里做视觉区分（加粗）。

### 状态

- 在 `_EpisodeSelectionTabState` 中新增：
  ```dart
  final Map<String, MergedEpisode> _sourceOverride = {};
  ```
  key 为集标题（`option.title`）。
- 某一集"当前生效来源" = `_sourceOverride[option.title] ?? option.preferred`。
- 用户在选择框里点选后：`setState(() => _sourceOverride[option.title] = chosen);`。
- 多集勾选批量下载时，各集分别使用自己的 `_sourceOverride` 值（未手动选过的集继续用自动优先级）——即"每集分别记忆"，不做全局统一应用。
- `_sourceOverride` 只是本页面（本次进入下载选择 Tab 期间）的临时 UI 状态，不做持久化，不影响 `downloadableSourcePriority` 的默认排序逻辑。

### 下载触发处改动

`episode_selection_tab.dart` 现有下载按钮的循环里（约第 158-170 行），把：
```dart
episode: option.preferred!,
```
改为：
```dart
episode: _sourceOverride[option.title] ?? option.preferred!,
```
其余逻辑（哪些集被选中、enqueue 调用参数的其他字段）不变。

### 范围外

- 不做"全局默认来源偏好"设置（不持久化用户对某来源的偏好，也不影响其他集/其他番剧的自动选择逻辑）。
- 不影响 `resolvePreferredDownloadSource`（仍只被 `DownloadQueueController.retry()` 使用，retry 场景本设计不涉及）。
- 不改动下载队列/worker/allow-list 任何逻辑。

## 测试

- `test/ui/download/episode_selection_tab_test.dart`：
  - 新增一个有 2+ 个可下载来源的测试集（当前 fixture 里每集只有 1 个来源，需要补充一个多来源用例）。
  - 验证多来源时文字可点击、弹出选择框、点选后触发下载时使用了选中的来源（而不是默认 `preferred`）。
  - 验证未手动选择时，默认行为不变（仍使用 `preferred`）。
  - 验证单来源集不可点击（不弹出选择框）。

## 验收

- `flutter analyze` 无新增错误。
- `flutter test` 全量通过。
- 手动验证（`flutter run -d macos`）：进入一个有多来源的番剧的下载选择页，点击来源文字能弹出选择框并切换，下载时确实用了选中的来源（可在下载管理页确认 `sourceId`）。
