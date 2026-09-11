# 手动切换线路 / BT 释出版本设计

日期：2026-09-11
状态：已批准（Approved）

## 背景与问题

用户提出两个看似独立的需求：

1. "视频播放源的线路切换" —— 即 Xifan 等非 BT 数据源在同一集下有多条 CDN 线路时，希望能手动选择用哪一条，而不是完全依赖播放器的自动回退。
2. "BT 播放源的 vendor 切换" —— 经与用户确认（用户原话："就是我选了 Mikan，可以切换里面的源，比如绿茶字幕组，ANi 字幕组等"），这**不是**指在 mikan/xifan/anime1 等不同 `MediaSource`（vendor）之间切换（那个已有完整 UI，见下文"不涉及的范围"），而是指在**同一个 Mikan BT 源内部**，针对同一集，在不同**字幕组发布的版本**（release）之间切换。

调研后确认：这两个需求本质上是同一个抽象的两种展现形式。`MediaSource.resolvePlayback(episode)` 已经返回一个有序的 `List<MediaPlaybackSource>`（由 [2026-09-06-multiline-playback-fallback-design.md](./2026-09-06-multiline-playback-fallback-design.md) 引入，用于播放失败时的自动静默回退），但目前完全没有手动选择的 UI——该文档明确将其列为范围外（"不新增手动选择线路的 UI"）。本设计正是要补上这个手动选择层，且用**同一套 UI/状态机**同时覆盖两类候选：

- 非 BT 源（Xifan，以及未注册的 Yinghua/Dilidili）：候选是不同 CDN"线路"，无描述性元数据，只能按下标编号展示为"线路 N"。
- BT 源（Mikan/`RssMediaSource`）：候选是 `TorrentPlaybackSource`，携带 `release: RssRelease` 字段，其 `release.parsed`（`ParsedTitle`）含字幕组名（`alliance`）、分辨率（`resolution`）、字幕语言（`subtitleLanguages`），足以拼出"绿茶字幕组 1080p 简体"这类可读标签。

## 设计目标（范围）

**范围内：**

- 在 `MediaPlaybackSource` 抽象上新增一个通用的展示用 `label` getter，使 UI 层不需要对具体子类做 `instanceof` 特判。
- `TorrentPlaybackSource` 覆写 `label`，拼接字幕组/分辨率/字幕语言。
- 其余候选类型（Xifan/Anime1/Yinghua/Dilidili 的 PlaybackSource）不覆写，UI 侧对 `label == null` 的情况统一回退为按列表位置的"线路 N"（1-indexed）。
- 在 `PlayerBottomBar` 新增一个"线路"图标按钮，点击弹出 BottomSheet 展示当前候选列表，支持手动选择。
- 手动切换候选时：保留当前播放进度（seek 到切换前的实时位置）；先 `dispose()` 旧候选再 `prepare()` 新候选（串行，避免 BT 场景下遗留 rqbit torrent）。
- 手动选择后，若该候选后续播放失败或缓冲超时，自动回退从手动选中的下标继续往后尝试（不回到下标 0）。
- 当候选数 ≤ 1 时，"线路"按钮仍显示但处于禁用（灰底）状态，不隐藏。

**范围外：**

- 不改动跨 vendor（mikan/xifan/anime1 等 `MediaSource.id`）之间的选择 UI —— `EpisodePlaybackSheet`（`lib/ui/subject/episode_playback_sheet.dart`）、`EpisodeSourceGrid`/`EpisodeSourceSheet`、播放器内的选集抽屉（`PlayerScreen._buildDrawer()`）均已存在且与本设计正交，不做修改。
- 不改动 rqbit BT 引擎（`lib/data/torrent/rqbit_engine.dart`）、RSS 解析（`lib/data/rss/`）、标题解析（`lib/domain/media/title_parser.dart`）。
- 不引入新的 Riverpod provider 或独立的状态管理抽象 —— 手动切换逻辑直接添加到现有 `_PlayerScreenState`，复用其已有的 `_candidates`/`_candidateIndex`/`_openCandidate` 字段与方法。
- "重试"按钮（`_retry()`）行为不变：仍重置到下标 0 并完整重新 `invalidate` 解析，不保留用户此前的手动选择（因为源页面内容可能已变化，与自动回退耗尽后的既有语义一致）。
- 不做候选可达性预检，不引入超时/数量上限——沿用 2026-09-06 设计已确立的原则。

## 架构与接口变更

### 1. `MediaPlaybackSource` 新增 `label`

```dart
// lib/domain/media/media_source.dart
abstract class MediaPlaybackSource {
  const MediaPlaybackSource();
  String get url;
  Map<String, String> get headers;

  /// 供 UI 展示的候选描述文本（如字幕组/分辨率）。
  /// 返回 null 时 UI 回退为按列表位置的"线路 N"（N 为 1-indexed）。
  String? get label => null;

  Future<String> prepare() async => url;
  Future<void> dispose() async {}
}
```

### 2. `TorrentPlaybackSource` 覆写 `label`

```dart
// lib/data/torrent/torrent_playback_source.dart
@override
String? get label {
  final parsed = release.parsed;
  final parts = <String>[
    if (parsed.alliance.isNotEmpty) parsed.alliance,
    if (parsed.resolution != null) parsed.resolution!,
    if (parsed.subtitleLanguages.isNotEmpty) parsed.subtitleLanguages.join('/'),
  ];
  return parts.isEmpty ? null : parts.join(' ');
}
```

`alliance` 由 `_extractAlliance()`（`lib/domain/media/title_parser.dart`）解析，找不到方括号时返回空字符串（非 null）而非 null，因此必须显式判空过滤，而不能依赖 `??`；三个字段全部为空/缺失的极端情况下整体返回 `null`，UI 自然回退为"线路 N"。

### 3. `PlayerScreen` 状态机改动

不引入新抽象，直接在 `_PlayerScreenState`（`lib/ui/player/player_screen.dart`）内新增：

```dart
Future<void> _switchToCandidate(int newIndex) async {
  if (_candidates == null || newIndex == _candidateIndex) return;
  final capturedPosition = _player.state.position;
  final previous = _candidates![_candidateIndex];
  unawaited(previous.dispose());
  _candidateIndex = newIndex;
  await _openCandidate(_candidates![newIndex]);
  await _player.seek(capturedPosition);
}

void _showLineSwitchSheet() {
  final candidates = _candidates;
  if (candidates == null) return;
  showModalBottomSheet(
    context: context,
    builder: (ctx) => _LineSwitchSheet(
      candidates: candidates,
      currentIndex: _candidateIndex,
      onSelect: (i) {
        Navigator.pop(ctx);
        _switchToCandidate(i);
      },
    ),
  );
}
```

关键点：

- `unawaited(previous.dispose())` 与现有的自动回退错误监听器、`_handleBufferTimeout()`、`_retry()` 中的 dispose 调用模式保持一致（fire-and-forget，dispose 失败不阻塞新候选打开）。
- `_openCandidate()` 内部会调用 `_maybeResumePosition()`，从 SharedPreferences 读取上次持久化保存的位置并 seek——这是磁盘记忆位置，不是本次切换前的内存实时位置。为满足"保留当前播放进度"的要求，在 `_openCandidate()` 之后再执行一次 `_player.seek(capturedPosition)`，用切换前捕获的实时位置覆盖磁盘位置；由于全程 `await` 串行执行，最后一次 seek 保证生效，无竞态。
- 自动回退（错误监听器 / `_handleBufferTimeout()`）本身就是从当前 `_candidateIndex` 继续往后尝试，完全不需要改动——手动切换只是改变了这个字段的起点。
- `_retry()` 不改动，其现有逻辑（重置 `_candidateIndex = 0`、`_candidates = null`、`ref.invalidate(...)`）已经满足"重试不保留手动选择"的要求。

`_LineSwitchSheet` 是一个新的私有 widget（可放在 `player_screen.dart` 同文件内，或拆一个小文件 `lib/ui/player/line_switch_sheet.dart`，视实现时代码量决定），渲染逻辑：

- `ListView` 遍历 `candidates`，每项一个 `ListTile`：
  - 主标题：`candidate.label ?? '线路 ${index + 1}'`
  - 若 `candidate is TorrentPlaybackSource`：副标题展示 `candidate.release.item.title`（原始 RSS 条目标题）；否则无副标题。
  - `index == currentIndex` 时：整行高亮背景色 + trailing `Icon(Icons.check)`。
  - `onTap: () => onSelect(index)`。

### 4. `PlayerBottomBar` 新增按钮

```dart
// lib/ui/player/player_bottom_bar.dart
class PlayerBottomBar extends StatelessWidget {
  const PlayerBottomBar({
    // ...existing required fields...
    required this.onLineSwitch,   // VoidCallback?，null 时按钮自动置灰禁用
  });

  final VoidCallback? onLineSwitch;

  // build() 中，速度 PopupMenuButton 之后、选集 IconButton 之前插入：
  IconButton(
    icon: const Icon(Icons.alt_route),
    tooltip: '线路',
    onPressed: onLineSwitch,
  ),
}
```

调用处（`PlayerScreen` 内实例化 `PlayerBottomBar` 的位置）：

```dart
onLineSwitch: (_candidates?.length ?? 0) > 1 ? _showLineSwitchSheet : null,
```

`onPressed: null` 时 Flutter 的 `IconButton` 自动渲染为禁用（灰底）样式，天然满足"候选数 ≤1 时按钮仍显示但禁用"的要求，无需额外的 `enabled` 布尔字段。

### 5. 测试要求

- `test/domain/media/media_source_test.dart`：新增用例验证基类 `MediaPlaybackSource.label` 默认返回 `null`。
- `test/data/torrent/torrent_playback_source_test.dart`：新增 `label` 覆写用例，覆盖：`alliance` 为空字符串时被跳过、`resolution` 为 `null` 时被跳过、`subtitleLanguages` 为空列表时被跳过、三者全部有值时的拼接顺序与分隔符、三者全部缺失时整体返回 `null`。
- `test/ui/player/player_bottom_bar_test.dart`：新增用例验证"线路"按钮渲染（图标 `Icons.alt_route`，tooltip 文案）、`onLineSwitch` 为 `null` 时按钮处于禁用态。
- `test/ui/player/player_screen_test.dart`（若不存在则视实现情况决定是否新建 widget test）：覆盖手动切换后旧候选 `dispose()` 被调用、`_candidateIndex` 正确更新、切换后自动回退从新下标继续、切换后播放位置与切换前一致（mock `MediaPlaybackSource.prepare()`/`dispose()` 并断言调用顺序）。

## 风险与已知限制

- `_maybeResumePosition()` 读取磁盘持久化位置与本次新增的"用内存实时位置覆盖"之间存在短暂的双重 seek（先 seek 到磁盘位置，再 seek 到实时位置），在网络较慢的 BT 场景下 `_openCandidate()` 本身耗时较长，用户可能会短暂看到进度条跳动两次；因为全程 `await` 顺序执行不存在竞态，只是视觉上的轻微跳动，设计上认为可接受，不做特殊处理。
- `TorrentPlaybackSource.label` 依赖 `title_parser.dart` 的解析质量；若字幕组标题不规范（如缺少方括号）导致 `alliance` 解析为空，且分辨率/语言也解析失败，该候选会退化显示为"线路 N"，与非 BT 候选无法区分——这是可接受的优雅降级，不视为缺陷。
- BT 候选手动切换时 `dispose()` 会调用 `engine.deleteTorrent()`，若用户来回快速切换多个 BT 候选，会连续触发 rqbit 的 add/delete torrent 操作；rqbit 单进程串行处理请求，设计上认为此频率下无性能问题，不做防抖处理（范围外）。
