# Mikan BT 边下边播数据源 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 animeko-flutter 新增一个基于 Mikan RSS 的 BT/磁力数据源，实现"边下边播"，复用现有 MediaSource 抽象、播放降级/回退机制。

**Architecture:** 通用 RSS 数据源工厂（Mikan 为内建默认实例）+ MediaPlaybackSource 新增 `prepare()`/`dispose()` 生命周期钩子 + rqbit 作为 sidecar 子进程通过 HTTP API 提供种子下载/流式播放。

**Tech Stack:** Flutter/Dart, Riverpod 3.x (`@riverpod` codegen), Dio, `package:xml` 7.0.1, media_kit, rqbit (Rust 可执行文件，作为子进程调用，Apache-2.0)，mocktail 测试。

## Global Constraints

- v1 范围：仅在线边下边播，不做离线缓存/保留/做种（退出播放/切换线路时调用 rqbit `/torrents/{id}/delete` 彻底清除种子文件）。
- v1 不处理代理（BT 流量直连，不接入现有 `proxy_dio_config.dart`）。
- rqbit 仅接受 `.torrent` 原始字节直接 POST，**禁止使用 magnet URI**（已实测：POST magnet 会同步阻塞直到 DHT 解析超时，达到 120s 才返回）。
- 释出标题解析必须基于 RSS `<title>` 元素，绝对不能用 rqbit/种子内部报告的文件名（已实测证实两者可能不一致：RSS 标题含字幕组 A + 中文剧名，种子内部 name 字段是字幕组 B + 无中文名 + CRC 后缀）。
- `MediaPlaybackSource.prepare()`/`dispose()` 需有默认实现，现有 4 个 HTTP 数据源（anime1/xifan/yinghua/dilidili）行为不得回归。
- **Dart 语言限制（已用 `dart analyze` 实测验证）**：接口方法带默认实现时，实现类必须用 `extends` 而不能用 `implements`——`implements` 不会继承已有的方法体，仍会报 "Missing concrete implementation" 编译错误。因此本计划要求把 4 个现有 `XxxPlaybackSource` 类的 `implements MediaPlaybackSource` 全部改为 `extends MediaPlaybackSource`。
- 现有 435 个测试必须全部保持通过（仅 `test/domain/media/media_registry_test.dart` 需要修改断言以容纳新增的第三个数据源）。
- `flutter analyze` 必须 0 error（pre-existing 的 28 条 info 级提示可以保留）。
- `lib/ui/player/player_screen.dart` 目前没有专属测试文件（只有 `player_bottom_bar_test.dart`/`player_top_bar_test.dart`），对它的改动依靠 `flutter analyze` + 全量 `flutter test` 回归 + 手工验证，不得编造不存在的自动化回归测试。
- 所有向用户输出的沟通必须使用中文。

---

### Task 1: 新增 `xml` 依赖

**Files:**
- Modify: `pubspec.yaml`

**Interfaces:**
- Consumes: 无
- Produces: `package:xml` 包，供 Task 3 的 RSS 解析器使用

- [ ] **Step 1: 在 `pubspec.yaml` 的 `dependencies:` 块内新增一行**

在现有 `html: ^0.15.7` 那一行之后插入：

```yaml
  html: ^0.15.7
  xml: ^7.0.1
```

- [ ] **Step 2: 运行 `flutter pub get` 验证依赖解析成功**

Run: `flutter pub get`
Expected: 命令成功退出（exit code 0），输出中出现 `+ xml 7.0.1`（或兼容的更高补丁版本），无版本冲突报错。

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add xml dependency for RSS parsing"
```

---

### Task 2: 释出标题解析器 `TitleParser`

**Files:**
- Create: `lib/domain/media/title_parser.dart`
- Test: `test/domain/media/title_parser_test.dart`

**Interfaces:**
- Consumes: 无（纯 Dart，无外部依赖）
- Produces:
  - `class EpisodeRange { const EpisodeRange.single(int value); const EpisodeRange.range(int start, int end); bool contains(int value); Iterable<int> expand(); }`
  - `class ParsedTitle { final EpisodeRange? episodeRange; final String? resolution; final String alliance; final List<String> subtitleLanguages; const ParsedTitle({this.episodeRange, this.resolution, required this.alliance, this.subtitleLanguages = const []}); }`
  - `ParsedTitle parseTitle(String rawTitle)`

- [ ] **Step 1: 写失败的测试（覆盖真实 Mikan 标题样本）**

创建 `test/domain/media/title_parser_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:animeko_flutter/domain/media/title_parser.dart';

void main() {
  group('parseTitle', () {
    test('parses dash-separated single episode with bracket group', () {
      const title =
          '[黒ネズミたち] 魔法少女奈叶 EXCEEDS Gun Blaze Vengeance / '
          'Mahou Shoujo Lyrical Nanoha EXCEEDS - 10 '
          '(ABEMA 1920x1080 AVC AAC MKV)';
      final parsed = parseTitle(title);

      expect(parsed.episodeRange, isNotNull);
      expect(parsed.episodeRange!.contains(10), isTrue);
      expect(parsed.episodeRange!.contains(11), isFalse);
      expect(parsed.resolution, '1080P');
      expect(parsed.alliance, '黒ネズミたち');
    });

    test('parses fullwidth-bracket range episode with season marker', () {
      const title =
          '【澄空学园&动漫国字幕组】★07月新番[魔法少女奈叶 EXCEEDS 复仇枪焰]'
          '[07-10][1080P][简体][MP4]';
      final parsed = parseTitle(title);

      expect(parsed.episodeRange, isNotNull);
      expect(parsed.episodeRange!.contains(7), isTrue);
      expect(parsed.episodeRange!.contains(10), isTrue);
      expect(parsed.episodeRange!.contains(11), isFalse);
      expect(parsed.resolution, '1080P');
      expect(parsed.alliance, '澄空学园&动漫国字幕组');
      expect(parsed.subtitleLanguages, contains('简体'));
    });

    test('parses double-space group name with CHT language tag', () {
      const title =
          '[ANi]  魔法少女奈叶 EXCEEDS Gun Blaze Vengeance - 09 '
          '[1080P][Baha][WEB-DL][AAC AVC][CHT][MP4]';
      final parsed = parseTitle(title);

      expect(parsed.episodeRange, isNotNull);
      expect(parsed.episodeRange!.contains(9), isTrue);
      expect(parsed.resolution, '1080P');
      expect(parsed.alliance, 'ANi');
      expect(parsed.subtitleLanguages, contains('繁体'));
    });

    test('parses bracketed single episode with traditional chinese tag', () {
      const title =
          '[ExileSub][魔法少女奈叶EXCEEDS Gun Blaze Vengeance][10][繁体][1080P]';
      final parsed = parseTitle(title);

      expect(parsed.episodeRange, isNotNull);
      expect(parsed.episodeRange!.contains(10), isTrue);
      expect(parsed.resolution, '1080P');
      expect(parsed.alliance, 'ExileSub');
      expect(parsed.subtitleLanguages, contains('繁体'));
    });

    test('returns null episodeRange when no episode number is found', () {
      const title = '[SomeGroup][Some Show][1080P][MP4]';
      final parsed = parseTitle(title);

      expect(parsed.episodeRange, isNull);
    });

    test('does not mistake a resolution number for an episode number', () {
      const title = '[Group][Show][1080P]';
      final parsed = parseTitle(title);

      expect(parsed.episodeRange, isNull);
      expect(parsed.resolution, '1080P');
    });
  });

  group('EpisodeRange', () {
    test('single contains only its own value', () {
      const range = EpisodeRange.single(5);
      expect(range.contains(5), isTrue);
      expect(range.contains(4), isFalse);
      expect(range.expand(), [5]);
    });

    test('range expands to all values inclusive', () {
      const range = EpisodeRange.range(7, 10);
      expect(range.expand(), [7, 8, 9, 10]);
      expect(range.contains(7), isTrue);
      expect(range.contains(10), isTrue);
      expect(range.contains(11), isFalse);
    });
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `flutter test test/domain/media/title_parser_test.dart`
Expected: FAIL，报错 `Error: Couldn't resolve the package 'animeko_flutter' in 'package:animeko_flutter/domain/media/title_parser.dart'` 或 `title_parser.dart` 文件不存在。

- [ ] **Step 3: 实现 `lib/domain/media/title_parser.dart`**

```dart
/// A parsed episode number or inclusive range, e.g. "10" or "07-10".
class EpisodeRange {
  const EpisodeRange.single(int value)
      : start = value,
        end = value;

  const EpisodeRange.range(this.start, this.end);

  final int start;
  final int end;

  bool contains(int value) => value >= start && value <= end;

  Iterable<int> expand() => List<int>.generate(end - start + 1, (i) => start + i);

  @override
  String toString() => start == end ? '$start' : '$start-$end';
}

/// The result of parsing a single BT release title (e.g. an RSS `<item><title>`).
class ParsedTitle {
  const ParsedTitle({
    this.episodeRange,
    this.resolution,
    required this.alliance,
    this.subtitleLanguages = const [],
  });

  final EpisodeRange? episodeRange;
  final String? resolution;
  final String alliance;
  final List<String> subtitleLanguages;
}

const _resolutionNumbers = {360, 480, 848, 1080, 1440, 1920, 2160};

final _bracketPattern = RegExp(r'\[(.+?)\]|【(.+?)】');
final _rangeWordPattern =
    RegExp(r'^(\d{1,4})\s*[-~～]{1,2}\s*(\d{1,4})$');
final _singleEpisodeWordPattern = RegExp(r'^\d{1,4}$');
final _resolutionXPattern = RegExp(r'(\d{3,4})[xX](\d{3,4})');
final _resolutionPPattern = RegExp(r'(\d{3,4})[Pp]\b');

const _languageKeywords = <String, List<String>>{
  '繁体': ['繁体', '繁中', 'BIG5', 'CHT', 'TC', '繁'],
  '简体': ['简体', '简中', 'GB', 'CHS', '简', '中文', '中字'],
  '粤语': ['粤语', '粤', '粵', 'Cantonese', 'CHC'],
  '日语': ['日语', '日文', 'JPN'],
  '英语': ['英语', '英文', 'ENG'],
};

/// Parses a raw BT release title into episode/resolution/alliance/language
/// metadata. Mirrors (a small, project-scoped subset of) upstream Animeko's
/// `LabelFirstRawTitleParser`. Returns `episodeRange: null` when no episode
/// number could be confidently extracted (the caller should discard such
/// items, matching upstream behavior).
ParsedTitle parseTitle(String rawTitle) {
  final words = _splitWords(rawTitle);

  EpisodeRange? episodeRange;
  String? resolution;
  final subtitleLanguages = <String>[];

  for (final word in words) {
    resolution ??= _tryParseResolution(word);
    episodeRange ??= _tryParseEpisode(word);
    for (final entry in _languageKeywords.entries) {
      if (subtitleLanguages.contains(entry.key)) continue;
      if (entry.value.any((kw) => word.contains(kw))) {
        subtitleLanguages.add(entry.key);
      }
    }
  }

  return ParsedTitle(
    episodeRange: episodeRange,
    resolution: resolution,
    alliance: _extractAlliance(rawTitle),
    subtitleLanguages: subtitleLanguages,
  );
}

List<String> _splitWords(String title) {
  final words = <String>[];
  var lastEnd = 0;
  for (final match in _bracketPattern.allMatches(title)) {
    if (match.start > lastEnd) {
      words.addAll(_splitPlain(title.substring(lastEnd, match.start)));
    }
    final content = match.group(1) ?? match.group(2) ?? '';
    words.add(content);
    lastEnd = match.end;
  }
  if (lastEnd < title.length) {
    words.addAll(_splitPlain(title.substring(lastEnd)));
  }
  return words;
}

List<String> _splitPlain(String text) => text
    .split(RegExp(r'[/\\|\s]+'))
    .map((w) => w.trim())
    .where((w) => w.isNotEmpty)
    .toList();

String? _tryParseResolution(String word) {
  final xMatch = _resolutionXPattern.firstMatch(word);
  if (xMatch != null) {
    final height = int.tryParse(xMatch.group(2)!);
    if (height != null && _resolutionNumbers.contains(height)) {
      return '${height}P';
    }
  }
  final pMatch = _resolutionPPattern.firstMatch(word);
  if (pMatch != null) {
    final value = int.tryParse(pMatch.group(1)!);
    if (value != null && _resolutionNumbers.contains(value)) {
      return '${value}P';
    }
  }
  return null;
}

EpisodeRange? _tryParseEpisode(String rawWord) {
  final word = rawWord.startsWith('-') ? rawWord.substring(1).trim() : rawWord;
  if (word.isEmpty) return null;

  final rangeMatch = _rangeWordPattern.firstMatch(word);
  if (rangeMatch != null) {
    final start = int.tryParse(rangeMatch.group(1)!);
    final end = int.tryParse(rangeMatch.group(2)!);
    if (start != null &&
        end != null &&
        !_resolutionNumbers.contains(start) &&
        !_resolutionNumbers.contains(end)) {
      return EpisodeRange.range(start, end);
    }
    return null;
  }

  if (_singleEpisodeWordPattern.hasMatch(word)) {
    final value = int.tryParse(word);
    if (value != null && !_resolutionNumbers.contains(value)) {
      return EpisodeRange.single(value);
    }
  }
  return null;
}

String _extractAlliance(String rawTitle) {
  final trimmed = rawTitle.trim();
  final idx = _firstIndexOfAny(trimmed, [']', '】']);
  if (idx < 0) return '';
  var alliance = trimmed.substring(0, idx);
  alliance = alliance.replaceFirst('[', '').replaceFirst('【', '');
  return alliance.trim();
}

int _firstIndexOfAny(String text, List<String> needles) {
  for (var i = 0; i < text.length; i++) {
    for (final needle in needles) {
      if (text.startsWith(needle, i)) return i;
    }
  }
  return -1;
}
```

- [ ] **Step 4: 运行测试验证通过**

Run: `flutter test test/domain/media/title_parser_test.dart`
Expected: PASS，全部 test 用例通过。

- [ ] **Step 5: Commit**

```bash
git add lib/domain/media/title_parser.dart test/domain/media/title_parser_test.dart
git commit -m "feat(media): add BT release title parser"
```

---

### Task 3: Mikan RSS 解析器

**Files:**
- Create: `lib/data/rss/rss_parser.dart`
- Create: `test/fixtures/mikan_rss_search_sample.xml`
- Test: `test/data/rss/rss_parser_test.dart`

**Interfaces:**
- Consumes: `package:xml` (Task 1)
- Produces:
  - `class RssItem { final String title; final String torrentUrl; final int contentLength; final DateTime? pubDate; const RssItem({required this.title, required this.torrentUrl, required this.contentLength, this.pubDate}); }`
  - `List<RssItem> parseRssFeed(String xmlBody)`

- [ ] **Step 1: 创建测试 fixture**

创建 `test/fixtures/mikan_rss_search_sample.xml`（10 条 `<item>`，覆盖 MP4/MKV 混合、区间集数、【】分隔符、季度标记）：

```xml
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0">
<channel>
<title>Mikan Project - 搜索结果:魔法少女</title>
<link>http://mikan.tangbai.cc/RSS/Search?searchstr=%E9%AD%94%E6%B3%95%E5%B0%91%E5%A5%B3</link>
<description>Mikan Project - 搜索结果:魔法少女</description>
<item>
<guid isPermaLink="false">[黒ネズミたち] 魔法少女奈叶 EXCEEDS - 10 (ABEMA 1920x1080 AVC AAC MKV)</guid>
<link>https://mikan.tangbai.cc/Home/Episode/8e546894a881c5acc4d06c226849476af5d77ede</link>
<title>[黒ネズミたち] 魔法少女奈叶 EXCEEDS - 10 (ABEMA 1920x1080 AVC AAC MKV)</title>
<description>[黒ネズミたち] 魔法少女奈叶 EXCEEDS - 10 (ABEMA 1920x1080 AVC AAC MKV)[710.9 MB]</description>
<torrent xmlns="https://mikan.tangbai.cc/0.1/"><link>https://mikan.tangbai.cc/Home/Episode/8e546894a881c5acc4d06c226849476af5d77ede</link><contentLength>745432704</contentLength><pubDate>2026-09-09T01:31:11.524054</pubDate></torrent>
<enclosure type="application/x-bittorrent" length="745432704" url="https://mikan.tangbai.cc/Download/20260909/8e546894a881c5acc4d06c226849476af5d77ede.torrent" />
</item>
<item>
<guid isPermaLink="false">【澄空学园&amp;动漫国字幕组】★07月新番[魔法少女奈叶 EXCEEDS 复仇枪焰][07-10][1080P][简体][MP4]</guid>
<link>https://mikan.tangbai.cc/Home/Episode/8cb817c429c59a1c05c0de37e8f2b928fc4340dc</link>
<title>【澄空学园&amp;动漫国字幕组】★07月新番[魔法少女奈叶 EXCEEDS 复仇枪焰][07-10][1080P][简体][MP4]</title>
<description>【澄空学园&amp;动漫国字幕组】★07月新番[魔法少女奈叶 EXCEEDS 复仇枪焰][07-10][1080P][简体][MP4][500 MB]</description>
<torrent xmlns="https://mikan.tangbai.cc/0.1/"><link>https://mikan.tangbai.cc/Home/Episode/8cb817c429c59a1c05c0de37e8f2b928fc4340dc</link><contentLength>524288000</contentLength><pubDate>2026-09-08T23:24:00</pubDate></torrent>
<enclosure type="application/x-bittorrent" length="524288000" url="https://mikan.tangbai.cc/Download/20260908/8cb817c429c59a1c05c0de37e8f2b928fc4340dc.torrent" />
</item>
<item>
<guid isPermaLink="false">[ANi]  魔法少女奈叶 EXCEEDS - 09 [1080P][Baha][WEB-DL][AAC AVC][CHT][MP4]</guid>
<link>https://mikan.tangbai.cc/Home/Episode/aaaa1111aaaa1111aaaa1111aaaa1111aaaa1111</link>
<title>[ANi]  魔法少女奈叶 EXCEEDS - 09 [1080P][Baha][WEB-DL][AAC AVC][CHT][MP4]</title>
<description>[ANi]  魔法少女奈叶 EXCEEDS - 09 [1080P][Baha][WEB-DL][AAC AVC][CHT][MP4][600 MB]</description>
<torrent xmlns="https://mikan.tangbai.cc/0.1/"><link>https://mikan.tangbai.cc/Home/Episode/aaaa1111aaaa1111aaaa1111aaaa1111aaaa1111</link><contentLength>629145600</contentLength><pubDate>2026-09-08T21:00:00</pubDate></torrent>
<enclosure type="application/x-bittorrent" length="629145600" url="https://mikan.tangbai.cc/Download/20260908/aaaa1111aaaa1111aaaa1111aaaa1111aaaa1111.torrent" />
</item>
<item>
<guid isPermaLink="false">[ExileSub][魔法少女奈叶EXCEEDS][10][繁体][1080P]</guid>
<link>https://mikan.tangbai.cc/Home/Episode/bbbb2222bbbb2222bbbb2222bbbb2222bbbb2222</link>
<title>[ExileSub][魔法少女奈叶EXCEEDS][10][繁体][1080P]</title>
<description>[ExileSub][魔法少女奈叶EXCEEDS][10][繁体][1080P][550 MB]</description>
<torrent xmlns="https://mikan.tangbai.cc/0.1/"><link>https://mikan.tangbai.cc/Home/Episode/bbbb2222bbbb2222bbbb2222bbbb2222bbbb2222</link><contentLength>576716800</contentLength><pubDate>2026-09-08T20:00:00</pubDate></torrent>
<enclosure type="application/x-bittorrent" length="576716800" url="https://mikan.tangbai.cc/Download/20260908/bbbb2222bbbb2222bbbb2222bbbb2222bbbb2222.torrent" />
</item>
<item>
<guid isPermaLink="false">[黒ネズミたち] 魔法少女奈叶 EXCEEDS - 03 (CR 1920x1080 AVC AAC MKV)</guid>
<link>https://mikan.tangbai.cc/Home/Episode/cccc3333cccc3333cccc3333cccc3333cccc3333</link>
<title>[黒ネズミたち] 魔法少女奈叶 EXCEEDS - 03 (CR 1920x1080 AVC AAC MKV)</title>
<description>[黒ネズミたち] 魔法少女奈叶 EXCEEDS - 03 (CR 1920x1080 AVC AAC MKV)[700 MB]</description>
<torrent xmlns="https://mikan.tangbai.cc/0.1/"><link>https://mikan.tangbai.cc/Home/Episode/cccc3333cccc3333cccc3333cccc3333cccc3333</link><contentLength>734003200</contentLength><pubDate>2026-09-01T01:00:00</pubDate></torrent>
<enclosure type="application/x-bittorrent" length="734003200" url="https://mikan.tangbai.cc/Download/20260901/cccc3333cccc3333cccc3333cccc3333cccc3333.torrent" />
</item>
<item>
<guid isPermaLink="false">[SomeGroup][Some Show][1080P][MP4]</guid>
<link>https://mikan.tangbai.cc/Home/Episode/dddd4444dddd4444dddd4444dddd4444dddd4444</link>
<title>[SomeGroup][Some Show][1080P][MP4]</title>
<description>[SomeGroup][Some Show][1080P][MP4][400 MB]</description>
<torrent xmlns="https://mikan.tangbai.cc/0.1/"><link>https://mikan.tangbai.cc/Home/Episode/dddd4444dddd4444dddd4444dddd4444dddd4444</link><contentLength>419430400</contentLength><pubDate>2026-08-30T10:00:00</pubDate></torrent>
<enclosure type="application/x-bittorrent" length="419430400" url="https://mikan.tangbai.cc/Download/20260830/dddd4444dddd4444dddd4444dddd4444dddd4444.torrent" />
</item>
<item>
<guid isPermaLink="false">[黒ネズミたち] 魔法少女奈叶 EXCEEDS - 08 (ABEMA 1920x1080 AVC AAC MKV)</guid>
<link>https://mikan.tangbai.cc/Home/Episode/eeee5555eeee5555eeee5555eeee5555eeee5555</link>
<title>[黒ネズミたち] 魔法少女奈叶 EXCEEDS - 08 (ABEMA 1920x1080 AVC AAC MKV)</title>
<description>[黒ネズミたち] 魔法少女奈叶 EXCEEDS - 08 (ABEMA 1920x1080 AVC AAC MKV)[720 MB]</description>
<torrent xmlns="https://mikan.tangbai.cc/0.1/"><link>https://mikan.tangbai.cc/Home/Episode/eeee5555eeee5555eeee5555eeee5555eeee5555</link><contentLength>754974720</contentLength><pubDate>2026-08-25T01:00:00</pubDate></torrent>
<enclosure type="application/x-bittorrent" length="754974720" url="https://mikan.tangbai.cc/Download/20260825/eeee5555eeee5555eeee5555eeee5555eeee5555.torrent" />
</item>
<item>
<guid isPermaLink="false">【澄空学园&amp;动漫国字幕组】★07月新番[魔法少女奈叶 EXCEEDS 复仇枪焰][01-06][1080P][简体][MP4]</guid>
<link>https://mikan.tangbai.cc/Home/Episode/ffff6666ffff6666ffff6666ffff6666ffff6666</link>
<title>【澄空学园&amp;动漫国字幕组】★07月新番[魔法少女奈叶 EXCEEDS 复仇枪焰][01-06][1080P][简体][MP4]</title>
<description>【澄空学园&amp;动漫国字幕组】★07月新番[魔法少女奈叶 EXCEEDS 复仇枪焰][01-06][1080P][简体][MP4][3 GB]</description>
<torrent xmlns="https://mikan.tangbai.cc/0.1/"><link>https://mikan.tangbai.cc/Home/Episode/ffff6666ffff6666ffff6666ffff6666ffff6666</link><contentLength>3221225472</contentLength><pubDate>2026-08-01T00:00:00</pubDate></torrent>
<enclosure type="application/x-bittorrent" length="3221225472" url="https://mikan.tangbai.cc/Download/20260801/ffff6666ffff6666ffff6666ffff6666ffff6666.torrent" />
</item>
<item>
<guid isPermaLink="false">[ANi]  魔法少女奈叶 EXCEEDS - 07 [1080P][Baha][WEB-DL][AAC AVC][CHT][MP4]</guid>
<link>https://mikan.tangbai.cc/Home/Episode/11119999111199991111999911119999</link>
<title>[ANi]  魔法少女奈叶 EXCEEDS - 07 [1080P][Baha][WEB-DL][AAC AVC][CHT][MP4]</title>
<description>[ANi]  魔法少女奈叶 EXCEEDS - 07 [1080P][Baha][WEB-DL][AAC AVC][CHT][MP4][610 MB]</description>
<torrent xmlns="https://mikan.tangbai.cc/0.1/"><link>https://mikan.tangbai.cc/Home/Episode/11119999111199991111999911119999</link><contentLength>639631360</contentLength><pubDate>2026-07-28T21:00:00</pubDate></torrent>
<enclosure type="application/x-bittorrent" length="639631360" url="https://mikan.tangbai.cc/Download/20260728/11119999111199991111999911119999.torrent" />
</item>
<item>
<guid isPermaLink="false">[ExileSub][魔法少女奈叶EXCEEDS][09][繁体][1080P]</guid>
<link>https://mikan.tangbai.cc/Home/Episode/22228888222288882222888822228888</link>
<title>[ExileSub][魔法少女奈叶EXCEEDS][09][繁体][1080P]</title>
<description>[ExileSub][魔法少女奈叶EXCEEDS][09][繁体][1080P][560 MB]</description>
<torrent xmlns="https://mikan.tangbai.cc/0.1/"><link>https://mikan.tangbai.cc/Home/Episode/22228888222288882222888822228888</link><contentLength>587202560</contentLength><pubDate>2026-07-21T20:00:00</pubDate></torrent>
<enclosure type="application/x-bittorrent" length="587202560" url="https://mikan.tangbai.cc/Download/20260721/22228888222288882222888822228888.torrent" />
</item>
</channel>
</rss>
```

- [ ] **Step 2: 写失败的测试**

创建 `test/data/rss/rss_parser_test.dart`：

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:animeko_flutter/data/rss/rss_parser.dart';

void main() {
  late String xmlBody;

  setUpAll(() {
    xmlBody = File('test/fixtures/mikan_rss_search_sample.xml').readAsStringSync();
  });

  group('parseRssFeed', () {
    test('parses all items from the fixture', () {
      final items = parseRssFeed(xmlBody);
      expect(items, hasLength(10));
    });

    test('reads pubDate from the nested torrent element, not item level', () {
      final items = parseRssFeed(xmlBody);
      final first = items.first;
      expect(first.pubDate, isNotNull);
      expect(first.pubDate!.year, 2026);
      expect(first.pubDate!.month, 9);
      expect(first.pubDate!.day, 9);
    });

    test('extracts the .torrent enclosure url, never a magnet link', () {
      final items = parseRssFeed(xmlBody);
      for (final item in items) {
        expect(item.torrentUrl, startsWith('https://'));
        expect(item.torrentUrl, endsWith('.torrent'));
        expect(item.torrentUrl, isNot(contains('magnet:')));
      }
    });

    test('extracts real content length matching enclosure length', () {
      final items = parseRssFeed(xmlBody);
      expect(items.first.contentLength, 745432704);
    });

    test('preserves the raw RSS title verbatim (including entities)', () {
      final items = parseRssFeed(xmlBody);
      final secondItem = items[1];
      expect(secondItem.title, contains('澄空学园&动漫国字幕组'));
    });

    test('skips malformed items without throwing', () {
      const malformed = '''<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0"><channel><title>t</title><link>l</link><description>d</description>
<item><guid isPermaLink="false">bad</guid><link>l</link><title>bad item</title><description>d</description></item>
<item><guid isPermaLink="false">[G][Show][1][MP4]</guid><link>https://mikan.tangbai.cc/Home/Episode/x</link><title>[G][Show][1][MP4]</title><description>d</description>
<torrent xmlns="https://mikan.tangbai.cc/0.1/"><link>https://mikan.tangbai.cc/Home/Episode/x</link><contentLength>100</contentLength><pubDate>2026-01-01T00:00:00</pubDate></torrent>
<enclosure type="application/x-bittorrent" length="100" url="https://mikan.tangbai.cc/Download/20260101/x.torrent" /></item>
</channel></rss>''';

      final items = parseRssFeed(malformed);
      expect(items, hasLength(1));
      expect(items.first.title, '[G][Show][1][MP4]');
    });
  });
}
```

- [ ] **Step 3: 运行测试验证失败**

Run: `flutter test test/data/rss/rss_parser_test.dart`
Expected: FAIL，`rss_parser.dart` 不存在。

- [ ] **Step 4: 实现 `lib/data/rss/rss_parser.dart`**

```dart
import 'package:xml/xml.dart';

/// A single `<item>` from a Mikan-style RSS feed.
class RssItem {
  const RssItem({
    required this.title,
    required this.torrentUrl,
    required this.contentLength,
    this.pubDate,
  });

  final String title;
  final String torrentUrl;
  final int contentLength;
  final DateTime? pubDate;
}

/// Parses a Mikan-style RSS 2.0 feed body into a list of [RssItem].
///
/// Mikan nests `<pubDate>` inside a `<torrent>` child element (not directly
/// under `<item>`), and always publishes an HTTP `.torrent` enclosure URL
/// (never a magnet link). Items that fail to parse are skipped rather than
/// aborting the whole feed.
List<RssItem> parseRssFeed(String xmlBody) {
  final document = XmlDocument.parse(xmlBody);
  final items = <RssItem>[];

  for (final itemElement in document.findAllElements('item')) {
    try {
      final title = itemElement.getElement('title')?.innerText.trim();
      final enclosure = itemElement.getElement('enclosure');
      final torrentUrl = enclosure?.getAttribute('url');
      final lengthStr = enclosure?.getAttribute('length');

      if (title == null || torrentUrl == null || lengthStr == null) {
        continue;
      }

      final torrentElement = itemElement.getElement('torrent');
      final pubDateStr = torrentElement?.getElement('pubDate')?.innerText.trim();

      items.add(RssItem(
        title: title,
        torrentUrl: torrentUrl,
        contentLength: int.parse(lengthStr),
        pubDate: pubDateStr != null ? DateTime.tryParse(pubDateStr) : null,
      ));
    } catch (_) {
      continue;
    }
  }

  return items;
}
```

- [ ] **Step 5: 运行测试验证通过**

Run: `flutter test test/data/rss/rss_parser_test.dart`
Expected: PASS。

- [ ] **Step 6: Commit**

```bash
git add lib/data/rss/rss_parser.dart test/data/rss/rss_parser_test.dart test/fixtures/mikan_rss_search_sample.xml
git commit -m "feat(rss): add Mikan RSS feed parser"
```

---

### Task 4: `RssMediaSource` 主体（集数分组 + MediaSource 三段式接口）

**Files:**
- Create: `lib/data/rss/rss_media_source.dart`
- Test: `test/data/rss/episode_grouping_test.dart`
- Test: `test/data/rss/rss_media_source_test.dart`

**Interfaces:**
- Consumes: `ParsedTitle`/`parseTitle` (Task 2), `RssItem`/`parseRssFeed` (Task 3), `MediaCandidate`/`MediaEpisode`/`MediaSource`/`MediaPlaybackSource` (`lib/domain/media/media_source.dart`, 现有)
- Produces:
  - `class RssSourceConfig { final String name; final String searchUrl; final String iconUrl; const RssSourceConfig({required this.name, required this.searchUrl, required this.iconUrl}); }`
  - `const mikanRssSourceConfig = RssSourceConfig(name: 'mikan', searchUrl: 'https://mikan.tangbai.cc/RSS/Search?searchstr={keyword}', iconUrl: 'https://mikan.tangbai.cc/favicon.ico');`
  - `class RssRelease { final RssItem item; final ParsedTitle parsed; const RssRelease({required this.item, required this.parsed}); }`
  - `Map<int, List<RssRelease>> groupByEpisode(List<RssItem> items)`
  - `class RssSeriesCandidate implements MediaCandidate { final String sourceId; final String title; final Map<int, List<RssRelease>> groups; }`
  - `class RssEpisode implements MediaEpisode { final String sourceId; final String title; final int episodeNumber; final List<RssRelease> releases; }`
  - `class RssMediaSource implements MediaSource { RssMediaSource(this.config, this._dio, this._engine); }`
  - `@riverpod Dio mikanRssDio(Ref ref)`

- [ ] **Step 1: 写失败的测试 — `groupByEpisode`**

创建 `test/data/rss/episode_grouping_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:animeko_flutter/data/rss/rss_media_source.dart';
import 'package:animeko_flutter/data/rss/rss_parser.dart';

RssItem _item(String title) => RssItem(
      title: title,
      torrentUrl: 'https://mikan.tangbai.cc/Download/x/x.torrent',
      contentLength: 100,
    );

void main() {
  group('groupByEpisode', () {
    test('groups a single-episode release under its episode number', () {
      final items = [_item('[Group][Show][10][1080P]')];
      final groups = groupByEpisode(items);

      expect(groups.keys, contains(10));
      expect(groups[10], hasLength(1));
    });

    test('expands a ranged release into every covered episode number', () {
      final items = [_item('[Group][Show][07-10][1080P]')];
      final groups = groupByEpisode(items);

      expect(groups.keys, containsAll([7, 8, 9, 10]));
      for (final ep in [7, 8, 9, 10]) {
        expect(groups[ep], hasLength(1));
      }
    });

    test('drops items whose episode number cannot be parsed', () {
      final items = [
        _item('[Group][Show][1080P][MP4]'),
        _item('[Group][Show][12][1080P]'),
      ];
      final groups = groupByEpisode(items);

      expect(groups.keys, [12]);
    });

    test('a single malformed item does not prevent others from grouping', () {
      final items = [
        _item('[Group][Show][12][1080P]'),
        _item('[Group][Show][13][1080P]'),
      ];
      final groups = groupByEpisode(items);

      expect(groups.keys, containsAll([12, 13]));
    });

    test('multiple releases for the same episode number are all kept', () {
      final items = [
        _item('[GroupA][Show][5][1080P]'),
        _item('[GroupB][Show][5][720P]'),
      ];
      final groups = groupByEpisode(items);

      expect(groups[5], hasLength(2));
    });
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `flutter test test/data/rss/episode_grouping_test.dart`
Expected: FAIL，`rss_media_source.dart` 不存在。

- [ ] **Step 3: 实现 `lib/data/rss/rss_media_source.dart`（第一部分：分组 + 数据类）**

```dart
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/media/media_source.dart';
import '../../domain/media/title_parser.dart';
import '../settings/proxy_dio_config.dart';
import '../torrent/rqbit_engine.dart';
import '../torrent/torrent_playback_source.dart';
import 'rss_parser.dart';

part 'rss_media_source.g.dart';

/// Configuration for one instance of the generic RSS BT media source.
///
/// Mirrors upstream Animeko's `rss` factory: [searchUrl] is a template with
/// a `{keyword}` placeholder (path-segment, not query-encoded by the caller
/// here since Dio handles query encoding when the placeholder sits inside a
/// query string).
class RssSourceConfig {
  const RssSourceConfig({
    required this.name,
    required this.searchUrl,
    required this.iconUrl,
  });

  final String name;
  final String searchUrl;
  final String iconUrl;
}

const mikanRssSourceConfig = RssSourceConfig(
  name: 'mikan',
  searchUrl: 'https://mikan.tangbai.cc/RSS/Search?searchstr={keyword}',
  iconUrl: 'https://mikan.tangbai.cc/favicon.ico',
);

/// One parsed BT release: the raw RSS item plus its parsed title metadata.
class RssRelease {
  const RssRelease({required this.item, required this.parsed});

  final RssItem item;
  final ParsedTitle parsed;
}

/// Groups raw RSS items by episode number, discarding items whose title
/// could not be parsed into an [EpisodeRange]. A single malformed item is
/// skipped via try/catch so it never prevents the rest of the feed from
/// being grouped. Ranged releases (e.g. episodes 07-10) are expanded so the
/// same release appears under every covered episode number.
Map<int, List<RssRelease>> groupByEpisode(List<RssItem> items) {
  final groups = <int, List<RssRelease>>{};
  for (final item in items) {
    try {
      final parsed = parseTitle(item.title);
      final range = parsed.episodeRange;
      if (range == null) continue;
      final release = RssRelease(item: item, parsed: parsed);
      for (final episodeNumber in range.expand()) {
        groups.putIfAbsent(episodeNumber, () => []).add(release);
      }
    } catch (_) {
      continue;
    }
  }
  return groups;
}

/// One subject-level search result: a Mikan RSS search already carries every
/// release for every episode, so all grouping happens once, here, at search
/// time. [listEpisodes] and [resolvePlayback] below only ever read from
/// [groups]; they issue no further network requests.
class RssSeriesCandidate implements MediaCandidate {
  const RssSeriesCandidate({
    required this.sourceId,
    required this.title,
    required this.groups,
  });

  @override
  final String sourceId;
  @override
  final String title;
  final Map<int, List<RssRelease>> groups;
}

class RssEpisode implements MediaEpisode {
  const RssEpisode({
    required this.sourceId,
    required this.title,
    required this.episodeNumber,
    required this.releases,
  });

  @override
  final String sourceId;
  @override
  final String title;
  final int episodeNumber;
  final List<RssRelease> releases;
}
```

- [ ] **Step 4: 运行测试验证通过（分组部分）**

Run: `flutter test test/data/rss/episode_grouping_test.dart`
Expected: PASS。

- [ ] **Step 5: 写失败的测试 — `RssMediaSource` 的 search/listEpisodes/resolvePlayback**

创建 `test/data/rss/rss_media_source_test.dart`：

```dart
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:animeko_flutter/data/rss/rss_media_source.dart';
import 'package:animeko_flutter/data/torrent/rqbit_engine.dart';
import 'package:animeko_flutter/data/torrent/torrent_playback_source.dart';
import 'package:animeko_flutter/domain/media/media_source.dart';

class MockDio extends Mock implements Dio {}

class MockRqbitEngine extends Mock implements RqbitEngine {}

Response<String> _xmlResponse(String body) => Response(
      data: body,
      requestOptions: RequestOptions(path: '/'),
      statusCode: 200,
    );

void main() {
  late MockDio dio;
  late MockRqbitEngine engine;
  late RssMediaSource source;
  late String xmlBody;

  setUpAll(() {
    xmlBody = File('test/fixtures/mikan_rss_search_sample.xml').readAsStringSync();
  });

  setUp(() {
    dio = MockDio();
    engine = MockRqbitEngine();
    source = RssMediaSource(mikanRssSourceConfig, dio, engine);
  });

  test('id and displayName come from config', () {
    expect(source.id, 'mikan');
    expect(source.displayName, 'mikan');
  });

  test('search fetches the templated URL and groups results by episode', () async {
    when(() => dio.get<String>(any())).thenAnswer((_) async => _xmlResponse(xmlBody));

    final candidates = await source.search('魔法少女奈叶');

    expect(candidates, hasLength(1));
    final candidate = candidates.single as RssSeriesCandidate;
    expect(candidate.sourceId, 'mikan');
    expect(candidate.groups.keys, containsAll([3, 7, 8, 9, 10]));

    final captured = verify(() => dio.get<String>(captureAny())).captured;
    expect(captured.single, contains('searchstr=%E9%AD%94%E6%B3%95%E5%B0%91%E5%A5%B3'));
  });

  test('listEpisodes converts cached groups synchronously, sorted ascending', () async {
    when(() => dio.get<String>(any())).thenAnswer((_) async => _xmlResponse(xmlBody));
    final candidates = await source.search('魔法少女奈叶');

    final episodes = await source.listEpisodes(candidates.single);

    final numbers = episodes.cast<RssEpisode>().map((e) => e.episodeNumber).toList();
    expect(numbers, numbers.toList()..sort());
    expect(numbers, containsAll([3, 7, 8, 9, 10]));

    verifyNever(() => dio.get<String>(any()));
  });

  test('resolvePlayback maps every release to a TorrentPlaybackSource', () async {
    when(() => dio.get<String>(any())).thenAnswer((_) async => _xmlResponse(xmlBody));
    final candidates = await source.search('魔法少女奈叶');
    final episodes = await source.listEpisodes(candidates.single);
    final ep10 = episodes.cast<RssEpisode>().firstWhere((e) => e.episodeNumber == 10);

    final playbackSources = await source.resolvePlayback(ep10);

    expect(playbackSources, isNotEmpty);
    expect(playbackSources, everyElement(isA<TorrentPlaybackSource>()));
  });
}
```

- [ ] **Step 6: 运行测试验证失败**

Run: `flutter test test/data/rss/rss_media_source_test.dart`
Expected: FAIL，`RssMediaSource` 类不存在。

- [ ] **Step 7: 在 `lib/data/rss/rss_media_source.dart` 末尾追加 `RssMediaSource` 类与 provider**

```dart
class RssMediaSource implements MediaSource {
  RssMediaSource(this.config, this._dio, this._engine);

  final RssSourceConfig config;
  final Dio _dio;
  final RqbitEngine _engine;

  @override
  String get id => config.name;

  @override
  String get displayName => config.name;

  @override
  Future<List<MediaCandidate>> search(String title) async {
    final url = config.searchUrl.replaceAll(
      '{keyword}',
      Uri.encodeQueryComponent(title),
    );
    final response = await _dio.get<String>(url);
    final items = parseRssFeed(response.data ?? '');
    final groups = groupByEpisode(items);

    return [
      RssSeriesCandidate(sourceId: config.name, title: title, groups: groups),
    ];
  }

  @override
  Future<List<MediaEpisode>> listEpisodes(MediaCandidate candidate) async {
    final rssCandidate = candidate as RssSeriesCandidate;
    final episodeNumbers = rssCandidate.groups.keys.toList()..sort();
    return [
      for (final episodeNumber in episodeNumbers)
        RssEpisode(
          sourceId: config.name,
          title: '第 $episodeNumber 集',
          episodeNumber: episodeNumber,
          releases: rssCandidate.groups[episodeNumber]!,
        ),
    ];
  }

  @override
  Future<List<MediaPlaybackSource>> resolvePlayback(MediaEpisode episode) async {
    final rssEpisode = episode as RssEpisode;
    final sortedReleases = [...rssEpisode.releases]..sort((a, b) {
        final resA = a.parsed.resolution ?? '';
        final resB = b.parsed.resolution ?? '';
        return resB.compareTo(resA);
      });

    return [
      for (final release in sortedReleases)
        TorrentPlaybackSource(release: release, engine: _engine),
    ];
  }
}

@riverpod
Dio mikanRssDio(Ref ref) {
  final dio = Dio(BaseOptions(headers: {'User-Agent': 'Mozilla/5.0'}));
  configureProxy(dio, ref);
  return dio;
}
```

- [ ] **Step 8: 运行 build_runner 生成 `rss_media_source.g.dart`**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: 成功生成 `lib/data/rss/rss_media_source.g.dart`，无冲突报错。

- [ ] **Step 9: 运行测试验证通过**

Run: `flutter test test/data/rss/rss_media_source_test.dart test/data/rss/episode_grouping_test.dart`
Expected: PASS（注意：这一步依赖 Task 6/7 已存在的 `RqbitEngine`/`TorrentPlaybackSource` 类型；若按顺序先做 Task 6/7 再回来做本 Task 的 Step 5-9，或提前占位这两个类的最简签名，均可满足编译。本计划建议实际执行时先完成 Task 6、Task 7，再执行本 Task 的 Step 5-9）。

- [ ] **Step 10: Commit**

```bash
git add lib/data/rss/rss_media_source.dart lib/data/rss/rss_media_source.g.dart test/data/rss/episode_grouping_test.dart test/data/rss/rss_media_source_test.dart
git commit -m "feat(rss): add generic RssMediaSource with episode grouping"
```

---

### Task 5: `MediaPlaybackSource` 生命周期扩展（`prepare()`/`dispose()`）

**Files:**
- Modify: `lib/domain/media/media_source.dart`
- Modify: `lib/data/anime1/anime1_models.dart`
- Modify: `lib/data/xifan/xifan_models.dart`
- Modify: `lib/data/yinghua/yinghua_models.dart`
- Modify: `lib/data/dilidili/dilidili_models.dart`
- Modify: `test/domain/media/media_source_test.dart`

**Interfaces:**
- Consumes: 无
- Produces: `abstract class MediaPlaybackSource { const MediaPlaybackSource(); String get url; Map<String,String> get headers; Future<String> prepare() async => url; Future<void> dispose() async {} }`

- [ ] **Step 1: 在 `test/domain/media/media_source_test.dart` 中新增回归测试**

打开现有 `test/domain/media/media_source_test.dart`，将其中的

```dart
class _FakePlaybackSource implements MediaPlaybackSource {
```

改为

```dart
class _FakePlaybackSource extends MediaPlaybackSource {
```

并在文件的 `main()` 内新增：

```dart
  test('MediaPlaybackSource.prepare() defaults to returning url', () async {
    const source = _FakePlaybackSource('https://example.com/video.mp4');
    expect(await source.prepare(), 'https://example.com/video.mp4');
  });

  test('MediaPlaybackSource.dispose() defaults to a no-op', () async {
    const source = _FakePlaybackSource('https://example.com/video.mp4');
    await expectLater(source.dispose(), completes);
  });
```

（若 `_FakePlaybackSource` 构造函数不是位置参数形式，按文件中实际已有的构造函数写法调整调用方式，保持字段名/构造签名与文件中已有定义一致。）

- [ ] **Step 2: 运行测试验证失败**

Run: `flutter test test/domain/media/media_source_test.dart`
Expected: FAIL —— `_FakePlaybackSource` 用 `extends` 但 `MediaPlaybackSource` 还没有 `const` 构造函数和默认方法，编译报错（`The class 'MediaPlaybackSource' can't be extended` 或 "no unnamed constructor")。

- [ ] **Step 3: 修改 `lib/domain/media/media_source.dart` 中的 `MediaPlaybackSource`**

将现有：

```dart
abstract class MediaPlaybackSource {
  /// Direct video URL (mp4/m3u8/etc).
  String get url;

  /// HTTP headers that must be sent when actually requesting [url] (e.g.
  /// via media_kit's `Media(url, httpHeaders: ...)`). Empty when the
  /// source's CDN needs none.
  Map<String, String> get headers;
}
```

改为：

```dart
abstract class MediaPlaybackSource {
  const MediaPlaybackSource();

  /// Direct video URL (mp4/m3u8/etc).
  String get url;

  /// HTTP headers that must be sent when actually requesting [url] (e.g.
  /// via media_kit's `Media(url, httpHeaders: ...)`). Empty when the
  /// source's CDN needs none.
  Map<String, String> get headers;

  /// Returns the URL that should actually be handed to the player. HTTP
  /// sources return [url] unchanged (the default implementation below). BT
  /// sources override this to download the `.torrent`, hand it to the
  /// torrent engine, and return the resulting local stream URL.
  Future<String> prepare() async => url;

  /// Called when playback of this source ends or a fallback switches away
  /// from it, to release any resources (e.g. a downloading torrent). HTTP
  /// sources need no cleanup, hence the no-op default.
  Future<void> dispose() async {}
}
```

- [ ] **Step 4: 修改 4 个现有 `XxxPlaybackSource` 类，`implements` 改为 `extends`**

在 `lib/data/anime1/anime1_models.dart` 中：

```dart
class Anime1PlaybackSource implements MediaPlaybackSource {
```

改为：

```dart
class Anime1PlaybackSource extends MediaPlaybackSource {
```

在 `lib/data/xifan/xifan_models.dart` 中：

```dart
class XifanPlaybackSource implements MediaPlaybackSource {
```

改为：

```dart
class XifanPlaybackSource extends MediaPlaybackSource {
```

在 `lib/data/yinghua/yinghua_models.dart` 中：

```dart
class YinghuaPlaybackSource implements MediaPlaybackSource {
```

改为：

```dart
class YinghuaPlaybackSource extends MediaPlaybackSource {
```

在 `lib/data/dilidili/dilidili_models.dart` 中：

```dart
class DilidiliPlaybackSource implements MediaPlaybackSource {
```

改为：

```dart
class DilidiliPlaybackSource extends MediaPlaybackSource {
```

（每个类现有的 `const XxxPlaybackSource({required this.url, this.headers = const {}});` 构造函数和两个 `@override final` 字段均保持不变，无需其他改动。）

- [ ] **Step 5: 运行测试验证通过**

Run: `flutter test test/domain/media/media_source_test.dart`
Expected: PASS。

- [ ] **Step 6: 运行全量回归确认四个数据源未被破坏**

Run: `flutter test test/data/anime1/ test/data/xifan/ test/data/yinghua/ test/data/dilidili/`
Expected: PASS，全部现有测试通过。

- [ ] **Step 7: Commit**

```bash
git add lib/domain/media/media_source.dart lib/data/anime1/anime1_models.dart lib/data/xifan/xifan_models.dart lib/data/yinghua/yinghua_models.dart lib/data/dilidili/dilidili_models.dart test/domain/media/media_source_test.dart
git commit -m "feat(media): add prepare()/dispose() lifecycle hooks to MediaPlaybackSource"
```

---

### Task 6: `RqbitEngine` sidecar 管理类

**Files:**
- Create: `lib/data/torrent/rqbit_engine.dart`
- Test: `test/data/torrent/rqbit_engine_test.dart`

**Interfaces:**
- Consumes: `Dio` (`package:dio`)
- Produces:
  - `class TorrentFileInfo { final int index; final String name; final int length; const TorrentFileInfo({required this.index, required this.name, required this.length}); }`
  - `class AddTorrentResult { final int id; final List<TorrentFileInfo> files; const AddTorrentResult({required this.id, required this.files}); int pickVideoFile({int? episodeInSet}); }`
  - `class RqbitEngine { Future<void> ensureStarted(); Future<AddTorrentResult> addTorrent(List<int> torrentBytes); String streamUrl(int torrentId, {required int fileIndex}); Future<void> deleteTorrent(int torrentId); Future<void> shutdown(); }`
  - `@Riverpod(keepAlive: true) RqbitEngine rqbitEngine(Ref ref)`

- [ ] **Step 1: 写失败的测试**

创建 `test/data/torrent/rqbit_engine_test.dart`：

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:animeko_flutter/data/torrent/rqbit_engine.dart';

class MockDio extends Mock implements Dio {}

Response<Map<String, dynamic>> _jsonResponse(Map<String, dynamic> body) => Response(
      data: body,
      requestOptions: RequestOptions(path: '/'),
      statusCode: 200,
    );

void main() {
  group('AddTorrentResult.pickVideoFile', () {
    test('picks the single file when there is only one', () {
      const result = AddTorrentResult(
        id: 0,
        files: [TorrentFileInfo(index: 0, name: 'movie.mp4', length: 1000)],
      );
      expect(result.pickVideoFile(), 0);
    });

    test('picks the largest file when there are multiple and no episodeInSet given', () {
      const result = AddTorrentResult(
        id: 0,
        files: [
          TorrentFileInfo(index: 0, name: 'sample.mp4', length: 10),
          TorrentFileInfo(index: 1, name: 'episode.mp4', length: 1000),
        ],
      );
      expect(result.pickVideoFile(), 1);
    });
  });

  group('RqbitEngine (Dio request construction)', () {
    late MockDio dio;
    late RqbitEngine engine;

    setUp(() {
      dio = MockDio();
      engine = RqbitEngine.forTesting(dio, port: 3030);
    });

    test('addTorrent POSTs raw bytes to /torrents', () async {
      when(() => dio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
          )).thenAnswer((_) async => _jsonResponse({
            'id': 0,
            'details': {
              'files': [
                {'name': 'a.mp4', 'length': 100},
              ],
            },
          }));

      final bytes = [1, 2, 3];
      final result = await engine.addTorrent(bytes);

      expect(result.id, 0);
      expect(result.files.single.name, 'a.mp4');

      final captured = verify(() => dio.post<Map<String, dynamic>>(
            captureAny(),
            data: captureAny(named: 'data'),
          )).captured;
      expect(captured[0], 'http://127.0.0.1:3030/torrents');
      expect(captured[1], bytes);
    });

    test('streamUrl builds the correct loopback URL', () {
      final url = engine.streamUrl(5, fileIndex: 2);
      expect(url, 'http://127.0.0.1:3030/torrents/5/stream/2');
    });

    test('deleteTorrent POSTs to /torrents/{id}/delete', () async {
      when(() => dio.post<dynamic>(any())).thenAnswer((_) async => _jsonResponse({}));

      await engine.deleteTorrent(7);

      verify(() => dio.post<dynamic>('http://127.0.0.1:3030/torrents/7/delete')).called(1);
    });
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `flutter test test/data/torrent/rqbit_engine_test.dart`
Expected: FAIL，`rqbit_engine.dart` 不存在。

- [ ] **Step 3: 实现 `lib/data/torrent/rqbit_engine.dart`**

```dart
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'rqbit_engine.g.dart';

class TorrentFileInfo {
  const TorrentFileInfo({
    required this.index,
    required this.name,
    required this.length,
  });

  final int index;
  final String name;
  final int length;
}

/// Result of adding a torrent to the rqbit sidecar.
class AddTorrentResult {
  const AddTorrentResult({required this.id, required this.files});

  final int id;
  final List<TorrentFileInfo> files;

  /// Picks which file inside a (possibly multi-file) torrent to stream.
  /// v1 heuristic: pick the largest file. [episodeInSet] is accepted for
  /// forward-compatibility with multi-file-per-episode torrents but is not
  /// yet used to disambiguate (see design doc Limitations section).
  int pickVideoFile({int? episodeInSet}) {
    var best = files.first;
    for (final file in files) {
      if (file.length > best.length) best = file;
    }
    return best.index;
  }
}

/// Manages a single `rqbit` sidecar process and talks to its JSON HTTP API.
///
/// v1 scope: online stream-only. [deleteTorrent] always forgets the torrent
/// and deletes its downloaded files (no retained/offline cache).
class RqbitEngine {
  RqbitEngine();

  /// Test-only constructor that skips process management and talks to a
  /// pre-configured [Dio] on a fixed port.
  RqbitEngine.forTesting(this._dio, {required int port}) : _port = port;

  Dio? _dio;
  int? _port;
  Process? _process;

  Future<void> ensureStarted() async {
    if (_process != null && _port != null) return;

    final process = await Process.start(
      _rqbitBinaryPath(),
      [
        '--http-api-listen-addr',
        '127.0.0.1:0',
        '--disable-upnp-port-forward',
        '--disable-dht-persistence',
        'server',
        'start',
        await _downloadDir(),
      ],
    );
    _process = process;
    unawaited(process.exitCode.then((_) {
      _process = null;
      _port = null;
    }));

    _port = await _readAssignedPort(process);
    _dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:$_port'));
  }

  Future<AddTorrentResult> addTorrent(List<int> torrentBytes) async {
    final response = await _dioClient.post<Map<String, dynamic>>(
      '$_base/torrents',
      data: torrentBytes,
    );
    final data = response.data!;
    final details = data['details'] as Map<String, dynamic>;
    final filesJson = details['files'] as List<dynamic>;
    final files = [
      for (var i = 0; i < filesJson.length; i++)
        TorrentFileInfo(
          index: i,
          name: filesJson[i]['name'] as String,
          length: filesJson[i]['length'] as int,
        ),
    ];
    return AddTorrentResult(id: data['id'] as int, files: files);
  }

  String streamUrl(int torrentId, {required int fileIndex}) {
    return '$_base/torrents/$torrentId/stream/$fileIndex';
  }

  Future<void> deleteTorrent(int torrentId) async {
    try {
      await _dioClient.post<dynamic>('$_base/torrents/$torrentId/delete');
    } catch (_) {
      // Cleanup failures are non-fatal: worst case is extra disk usage.
    }
  }

  Future<void> shutdown() async {
    _process?.kill();
    _process = null;
    _port = null;
  }

  Dio get _dioClient => _dio!;
  String get _base => 'http://127.0.0.1:${_port!}';

  String _rqbitBinaryPath() {
    // TODO(实施阶段): 确定 rqbit 二进制在打包后的 macOS .app 内的实际路径
    // （例如 macos/Runner/Resources/rqbit），当前返回占位路径，供 ensureStarted()
    // 在未打包环境下于 PATH 中查找同名可执行文件。
    return 'rqbit';
  }

  Future<String> _downloadDir() async {
    final dir = await Directory.systemTemp.createTemp('animeko_bt_');
    return dir.path;
  }

  Future<int> _readAssignedPort(Process process) async {
    final firstLine = await process.stdout
        .transform(const SystemEncoding().decoder)
        .firstWhere((line) => line.contains('started HTTP API'));
    final match = RegExp(r':(\d+)$').firstMatch(firstLine.trim());
    return int.parse(match!.group(1)!);
  }
}

@Riverpod(keepAlive: true)
RqbitEngine rqbitEngine(Ref ref) => RqbitEngine();
```

- [ ] **Step 4: 运行 build_runner 生成 `rqbit_engine.g.dart`**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: 成功生成 `lib/data/torrent/rqbit_engine.g.dart`。

- [ ] **Step 5: 运行测试验证通过**

Run: `flutter test test/data/torrent/rqbit_engine_test.dart`
Expected: PASS。

- [ ] **Step 6: Commit**

```bash
git add lib/data/torrent/rqbit_engine.dart lib/data/torrent/rqbit_engine.g.dart test/data/torrent/rqbit_engine_test.dart
git commit -m "feat(torrent): add RqbitEngine sidecar manager"
```

---

### Task 7: `TorrentPlaybackSource`

**Files:**
- Create: `lib/data/torrent/torrent_playback_source.dart`
- Test: `test/data/torrent/torrent_playback_source_test.dart`

**Interfaces:**
- Consumes: `MediaPlaybackSource` (Task 5), `RssRelease` (Task 4), `RqbitEngine`/`AddTorrentResult` (Task 6)
- Produces: `class TorrentPlaybackSource extends MediaPlaybackSource { TorrentPlaybackSource({required this.release, required this.engine, Dio? dio}); }`

- [ ] **Step 1: 写失败的测试**

创建 `test/data/torrent/torrent_playback_source_test.dart`：

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:animeko_flutter/data/rss/rss_media_source.dart';
import 'package:animeko_flutter/data/rss/rss_parser.dart';
import 'package:animeko_flutter/data/torrent/rqbit_engine.dart';
import 'package:animeko_flutter/data/torrent/torrent_playback_source.dart';
import 'package:animeko_flutter/domain/media/title_parser.dart';

class MockDio extends Mock implements Dio {}

class MockRqbitEngine extends Mock implements RqbitEngine {}

Response<List<int>> _bytesResponse(List<int> bytes) => Response(
      data: bytes,
      requestOptions: RequestOptions(path: '/'),
      statusCode: 200,
    );

void main() {
  late MockDio dio;
  late MockRqbitEngine engine;
  late RssRelease release;

  setUp(() {
    dio = MockDio();
    engine = MockRqbitEngine();
    release = RssRelease(
      item: const RssItem(
        title: '[Group][Show][10][1080P]',
        torrentUrl: 'https://mikan.tangbai.cc/Download/x/x.torrent',
        contentLength: 1000,
      ),
      parsed: parseTitle('[Group][Show][10][1080P]'),
    );
  });

  test('prepare() downloads the torrent bytes, adds it to the engine, and '
      'returns the stream URL', () async {
    final torrentBytes = [1, 2, 3];
    when(() => dio.get<List<int>>(
          any(),
          options: any(named: 'options'),
        )).thenAnswer((_) async => _bytesResponse(torrentBytes));
    when(() => engine.addTorrent(torrentBytes)).thenAnswer(
      (_) async => const AddTorrentResult(
        id: 42,
        files: [TorrentFileInfo(index: 0, name: 'a.mp4', length: 1000)],
      ),
    );
    when(() => engine.streamUrl(42, fileIndex: 0))
        .thenReturn('http://127.0.0.1:3030/torrents/42/stream/0');

    final source = TorrentPlaybackSource(release: release, engine: engine, dio: dio);
    final url = await source.prepare();

    expect(url, 'http://127.0.0.1:3030/torrents/42/stream/0');
    verify(() => engine.addTorrent(torrentBytes)).called(1);
  });

  test('dispose() calls engine.deleteTorrent with the torrent id from prepare()', () async {
    when(() => dio.get<List<int>>(
          any(),
          options: any(named: 'options'),
        )).thenAnswer((_) async => _bytesResponse([1]));
    when(() => engine.addTorrent(any())).thenAnswer(
      (_) async => const AddTorrentResult(
        id: 9,
        files: [TorrentFileInfo(index: 0, name: 'a.mp4', length: 1)],
      ),
    );
    when(() => engine.streamUrl(9, fileIndex: 0)).thenReturn('http://x/stream/0');
    when(() => engine.deleteTorrent(9)).thenAnswer((_) async {});

    final source = TorrentPlaybackSource(release: release, engine: engine, dio: dio);
    await source.prepare();
    await source.dispose();

    verify(() => engine.deleteTorrent(9)).called(1);
  });

  test('dispose() before prepare() is a no-op', () async {
    final source = TorrentPlaybackSource(release: release, engine: engine, dio: dio);
    await expectLater(source.dispose(), completes);
    verifyNever(() => engine.deleteTorrent(any()));
  });

  test('prepare() propagates errors from the engine', () async {
    when(() => dio.get<List<int>>(
          any(),
          options: any(named: 'options'),
        )).thenAnswer((_) async => _bytesResponse([1]));
    when(() => engine.addTorrent(any())).thenThrow(Exception('boom'));

    final source = TorrentPlaybackSource(release: release, engine: engine, dio: dio);
    await expectLater(source.prepare(), throwsException);
  });

  test('url getter throws before prepare() has been called', () {
    final source = TorrentPlaybackSource(release: release, engine: engine, dio: dio);
    expect(() => source.url, throwsStateError);
  });

  test('headers is always empty', () {
    final source = TorrentPlaybackSource(release: release, engine: engine, dio: dio);
    expect(source.headers, isEmpty);
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `flutter test test/data/torrent/torrent_playback_source_test.dart`
Expected: FAIL，`torrent_playback_source.dart` 不存在。

- [ ] **Step 3: 实现 `lib/data/torrent/torrent_playback_source.dart`**

```dart
import 'package:dio/dio.dart';

import '../../domain/media/media_source.dart';
import '../rss/rss_media_source.dart';
import 'rqbit_engine.dart';

/// A [MediaPlaybackSource] backed by a BT release. [prepare] downloads the
/// `.torrent` file's raw bytes, hands them to the rqbit sidecar, and returns
/// its local HTTP stream URL. [dispose] tells the engine to forget the
/// torrent and delete its downloaded files (v1 scope: no retained cache).
class TorrentPlaybackSource extends MediaPlaybackSource {
  TorrentPlaybackSource({
    required this.release,
    required this.engine,
    Dio? dio,
  }) : _dio = dio ?? Dio();

  final RssRelease release;
  final RqbitEngine engine;
  final Dio _dio;

  int? _torrentId;
  String? _preparedUrl;

  @override
  String get url {
    final prepared = _preparedUrl;
    if (prepared == null) {
      throw StateError('TorrentPlaybackSource.url read before prepare() completed');
    }
    return prepared;
  }

  @override
  Map<String, String> get headers => const {};

  @override
  Future<String> prepare() async {
    await engine.ensureStarted();
    final response = await _dio.get<List<int>>(
      release.item.torrentUrl,
      options: Options(responseType: ResponseType.bytes),
    );
    final result = await engine.addTorrent(response.data!);
    _torrentId = result.id;
    final fileIndex = result.pickVideoFile(episodeInSet: null);
    _preparedUrl = engine.streamUrl(result.id, fileIndex: fileIndex);
    return _preparedUrl!;
  }

  @override
  Future<void> dispose() async {
    final id = _torrentId;
    if (id != null) {
      await engine.deleteTorrent(id);
    }
  }
}
```

- [ ] **Step 4: 运行测试验证通过**

Run: `flutter test test/data/torrent/torrent_playback_source_test.dart`
Expected: PASS。

- [ ] **Step 5: 回到 Task 4 Step 9，运行 `RssMediaSource` 相关测试确认现在可以通过**

Run: `flutter test test/data/rss/`
Expected: PASS（`TorrentPlaybackSource`/`RqbitEngine` 现已存在，Task 4 中被推迟的编译依赖已解决）。

- [ ] **Step 6: Commit**

```bash
git add lib/data/torrent/torrent_playback_source.dart test/data/torrent/torrent_playback_source_test.dart
git commit -m "feat(torrent): add TorrentPlaybackSource lifecycle implementation"
```

---

### Task 8: `episode_source_matcher.dart` 新增按集数匹配分支

**Files:**
- Modify: `lib/domain/play/episode_source_matcher.dart`
- Modify: `test/domain/play/episode_source_matcher_test.dart`

**Interfaces:**
- Consumes: `RssEpisode` (Task 4), `MergedEpisode` (`lib/domain/play/subject_episodes_controller.dart`, 现有)
- Produces: `matchEpisodeSources({required int ordinalIndex, required List<MergedEpisode> allMerged})`（签名不变，内部行为扩展）

- [ ] **Step 1: 在 `test/domain/play/episode_source_matcher_test.dart` 中新增测试用例**

在现有测试文件的 `main()` 内新增（保留文件中已有的 `_FakeEpisode` 辅助类和已有测试不变）：

```dart
  test('matches an RssEpisode by episodeNumber rather than by position', () {
    final rssEpisode10 = RssEpisode(
      sourceId: 'mikan',
      title: '第 10 集',
      episodeNumber: 10,
      releases: const [],
    );
    final rssEpisode11 = RssEpisode(
      sourceId: 'mikan',
      title: '第 11 集',
      episodeNumber: 11,
      releases: const [],
    );
    // Deliberately out of position order: index 0 is episode 11, index 1 is
    // episode 10, to prove matching is by episodeNumber, not list position.
    final merged = [
      MergedEpisode(episode: rssEpisode11, sourceId: 'mikan'),
      MergedEpisode(episode: rssEpisode10, sourceId: 'mikan'),
    ];

    // Bangumi grid ordinalIndex 9 (0-based) == episode number 10 (1-based).
    final matches = matchEpisodeSources(ordinalIndex: 9, allMerged: merged);

    expect(matches, hasLength(1));
    expect((matches.single.episode as RssEpisode).episodeNumber, 10);
  });

  test('returns no match for an RssEpisode source when the requested episode '
      'number was never published', () {
    final rssEpisode5 = RssEpisode(
      sourceId: 'mikan',
      title: '第 5 集',
      episodeNumber: 5,
      releases: const [],
    );
    final merged = [MergedEpisode(episode: rssEpisode5, sourceId: 'mikan')];

    // ordinalIndex 6 -> wanted episode number 7, which does not exist.
    final matches = matchEpisodeSources(ordinalIndex: 6, allMerged: merged);

    expect(matches, isEmpty);
  });

  test('non-RssEpisode sources continue to match purely by position', () {
    const episodeA = _FakeEpisode('anime1', 'Episode A');
    const episodeB = _FakeEpisode('anime1', 'Episode B');
    final merged = [
      MergedEpisode(episode: episodeA, sourceId: 'anime1'),
      MergedEpisode(episode: episodeB, sourceId: 'anime1'),
    ];

    final matches = matchEpisodeSources(ordinalIndex: 1, allMerged: merged);

    expect(matches, hasLength(1));
    expect(matches.single.episode.title, 'Episode B');
  });
```

需在该测试文件顶部新增 import：

```dart
import 'package:animeko_flutter/data/rss/rss_media_source.dart';
```

- [ ] **Step 2: 运行测试验证失败**

Run: `flutter test test/domain/play/episode_source_matcher_test.dart`
Expected: FAIL —— "matches an RssEpisode by episodeNumber" 和 "returns no match" 两个新用例失败（因为当前实现是纯位置匹配，`ordinalIndex: 9` 会命中 list 里第 10 个元素而不是 `episodeNumber == 10` 的那个，此处 list 只有 2 个元素所以会直接因下标越界被跳过导致 `matches` 为空，测试断言 `hasLength(1)` 失败）。

- [ ] **Step 3: 修改 `lib/domain/play/episode_source_matcher.dart`**

在文件顶部新增 import：

```dart
import '../../data/rss/rss_media_source.dart';
```

将现有函数体：

```dart
List<MergedEpisode> matchEpisodeSources({
  required int ordinalIndex,
  required List<MergedEpisode> allMerged,
}) {
  final bySource = <String, List<MergedEpisode>>{};
  for (final episode in allMerged) {
    bySource.putIfAbsent(episode.sourceId, () => []).add(episode);
  }

  final matches = <MergedEpisode>[];
  for (final episodes in bySource.values) {
    if (ordinalIndex < episodes.length) {
      matches.add(episodes[ordinalIndex]);
    }
  }
  return matches;
}
```

改为：

```dart
List<MergedEpisode> matchEpisodeSources({
  required int ordinalIndex,
  required List<MergedEpisode> allMerged,
}) {
  final bySource = <String, List<MergedEpisode>>{};
  for (final episode in allMerged) {
    bySource.putIfAbsent(episode.sourceId, () => []).add(episode);
  }

  final matches = <MergedEpisode>[];
  for (final episodes in bySource.values) {
    // RSS/BT episode lists are keyed by parsed episode number, not by list
    // position (a source may be missing an episode, or list them out of
    // order relative to the Bangumi grid). ordinalIndex is 0-based; episode
    // numbers parsed from release titles are 1-based, hence the +1.
    final bySort = _findBySort(episodes, ordinalIndex + 1);
    if (bySort != null) {
      matches.add(bySort);
    } else if (ordinalIndex < episodes.length) {
      matches.add(episodes[ordinalIndex]);
    }
  }
  return matches;
}

MergedEpisode? _findBySort(List<MergedEpisode> episodes, int wantedSort) {
  for (final merged in episodes) {
    final episode = merged.episode;
    if (episode is RssEpisode && episode.episodeNumber == wantedSort) {
      return merged;
    }
  }
  return null;
}
```

- [ ] **Step 4: 运行测试验证通过**

Run: `flutter test test/domain/play/episode_source_matcher_test.dart`
Expected: PASS，全部用例（新增的 3 个 + 原有的）通过。

- [ ] **Step 5: Commit**

```bash
git add lib/domain/play/episode_source_matcher.dart test/domain/play/episode_source_matcher_test.dart
git commit -m "feat(play): match RSS episodes by episode number instead of position"
```

---

### Task 9: 注册 `RssMediaSource` 到 `media_registry.dart`

**Files:**
- Modify: `lib/domain/media/media_registry.dart`
- Modify: `test/domain/media/media_registry_test.dart`

**Interfaces:**
- Consumes: `RssMediaSource`/`mikanRssSourceConfig`/`mikanRssDioProvider` (Task 4), `rqbitEngineProvider` (Task 6)
- Produces: `mediaSourcesProvider` 现在返回 3 个源（`anime1`、`xifan`、`mikan`）

- [ ] **Step 1: 修改 `test/domain/media/media_registry_test.dart` 中的断言**

将文件末尾：

```dart
test('mediaSourcesProvider returns the two registered sources '
    '(yinghua and dilidili are intentionally disabled -- see mediaSources '
    'doc comment)', () {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final sources = container.read(mediaSourcesProvider);
  expect(sources.map((s) => s.id), ['anime1', 'xifan']);
});
```

改为：

```dart
test('mediaSourcesProvider returns the three registered sources '
    '(yinghua and dilidili are intentionally disabled -- see mediaSources '
    'doc comment)', () {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final sources = container.read(mediaSourcesProvider);
  expect(sources.map((s) => s.id), ['anime1', 'xifan', 'mikan']);
});
```

- [ ] **Step 2: 运行测试验证失败**

Run: `flutter test test/domain/media/media_registry_test.dart`
Expected: FAIL —— 实际返回 `['anime1', 'xifan']`，长度不匹配期望的 3 个元素。

- [ ] **Step 3: 修改 `lib/domain/media/media_registry.dart`**

在文件顶部 import 块新增两行（放在现有 `import 'media_source.dart';` 之前）：

```dart
import '../../data/rss/rss_media_source.dart';
import '../../data/torrent/rqbit_engine.dart';
```

将现有：

```dart
@riverpod
List<MediaSource> mediaSources(Ref ref) => [
  Anime1MediaSource(ref.watch(anime1ApiProvider)),
  XifanMediaSource(ref.watch(xifanApiProvider)),
];
```

改为：

```dart
@riverpod
List<MediaSource> mediaSources(Ref ref) => [
  Anime1MediaSource(ref.watch(anime1ApiProvider)),
  XifanMediaSource(ref.watch(xifanApiProvider)),
  RssMediaSource(
    mikanRssSourceConfig,
    ref.watch(mikanRssDioProvider),
    ref.watch(rqbitEngineProvider),
  ),
];
```

- [ ] **Step 4: 运行 build_runner 确认无冲突**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: 成功，无冲突报错。

- [ ] **Step 5: 运行测试验证通过**

Run: `flutter test test/domain/media/media_registry_test.dart`
Expected: PASS。

- [ ] **Step 6: Commit**

```bash
git add lib/domain/media/media_registry.dart test/domain/media/media_registry_test.dart
git commit -m "feat(media): register Mikan RssMediaSource in mediaSourcesProvider"
```

---

### Task 10: `player_screen.dart` 集成 `prepare()`/`dispose()` 与缓冲超时降级

**Files:**
- Modify: `lib/ui/player/player_screen.dart`

**Interfaces:**
- Consumes: `MediaPlaybackSource.prepare()`/`dispose()` (Task 5)
- Produces: 无新增公开接口（内部行为变更）

**说明：** `player_screen.dart` 目前没有专属测试文件。本 Task 的验证方式是 `flutter analyze` + 全量 `flutter test` 回归（确认现有 435 个测试不受影响，因为改动只涉及这一个文件内部）+ 手工启动 App 播放一集现有 HTTP 数据源（如 anime1/xifan）确认播放行为未回归。不编造不存在的自动化测试。

- [ ] **Step 1: 修改 `_openCandidate` 方法，插入 `prepare()` 调用**

将现有：

```dart
Future<void> _openCandidate(MediaPlaybackSource source) async {
  if (mounted) setState(() => _isBuffering = true);
  await _player.open(Media(source.url, httpHeaders: source.headers));
  final speed = await ref.read(playbackSpeedControllerProvider.future);
  await _player.setRate(speed);
  await _maybeResumePosition();
  if (mounted) _hasAdvancedToNextEpisode = false;
}
```

改为：

```dart
Future<void> _openCandidate(MediaPlaybackSource source) async {
  if (mounted) setState(() => _isBuffering = true);
  final playableUrl = await source.prepare();
  await _player.open(Media(playableUrl, httpHeaders: source.headers));
  final speed = await ref.read(playbackSpeedControllerProvider.future);
  await _player.setRate(speed);
  await _maybeResumePosition();
  if (mounted) _hasAdvancedToNextEpisode = false;
}
```

- [ ] **Step 2: 在错误降级监听器中，切换候选前释放旧候选**

找到现有的 `_player.stream.error.listen` 监听器：

```dart
_player.stream.error.listen((message) {
  if (!mounted) return;
  final candidates = _candidates;
  if (candidates == null) return;
  if (_candidateIndex + 1 < candidates.length) {
    _candidateIndex++;
    _openCandidate(candidates[_candidateIndex]).catchError((Object e) {
      if (mounted) setState(() => _playbackError = e.toString());
    });
    return;
  }
  setState(() => _playbackError = message);
});
```

改为：

```dart
_player.stream.error.listen((message) {
  if (!mounted) return;
  final candidates = _candidates;
  if (candidates == null) return;
  if (_candidateIndex + 1 < candidates.length) {
    final previousCandidate = candidates[_candidateIndex];
    _candidateIndex++;
    unawaited(previousCandidate.dispose());
    _openCandidate(candidates[_candidateIndex]).catchError((Object e) {
      if (mounted) setState(() => _playbackError = e.toString());
    });
    return;
  }
  setState(() => _playbackError = message);
});
```

若文件顶部尚未 `import 'dart:async';`（用于 `unawaited`），需添加该 import。

- [ ] **Step 3: 在 `_retry()` 方法中同样释放旧候选**

找到现有 `_retry()` 方法（大致形如）：

```dart
void _retry() {
  final candidates = _candidates;
  if (candidates == null) return;
  setState(() => _playbackError = null);
  _openCandidate(candidates[_candidateIndex]).catchError((Object e) {
    if (mounted) setState(() => _playbackError = e.toString());
  });
}
```

在调用 `_openCandidate` 之前插入对旧候选的 `dispose()`（重试同一个候选时，先释放旧的种子会话再重新 `prepare()`，避免重复调用 `prepare()` 时残留旧种子）：

```dart
void _retry() {
  final candidates = _candidates;
  if (candidates == null) return;
  setState(() => _playbackError = null);
  final previousCandidate = candidates[_candidateIndex];
  unawaited(previousCandidate.dispose());
  _openCandidate(candidates[_candidateIndex]).catchError((Object e) {
    if (mounted) setState(() => _playbackError = e.toString());
  });
}
```

- [ ] **Step 4: 新增缓冲超时计时器**

找到现有 buffering 监听器（大致形如）：

```dart
_bufferingSubscription = _player.stream.buffering.listen((buffering) {
  if (mounted) setState(() => _isBuffering = buffering);
});
```

改为，并新增一个 `Timer? _bufferTimeoutTimer;` 字段（放在其他 `late final` / 字段声明附近）：

```dart
Timer? _bufferTimeoutTimer;
```

```dart
_bufferingSubscription = _player.stream.buffering.listen((buffering) {
  if (mounted) setState(() => _isBuffering = buffering);
  if (buffering) {
    _bufferTimeoutTimer ??= Timer(const Duration(seconds: 30), _handleBufferTimeout);
  } else {
    _bufferTimeoutTimer?.cancel();
    _bufferTimeoutTimer = null;
  }
});
```

新增 `_handleBufferTimeout` 方法（放在 `_openCandidate` 附近）：

```dart
void _handleBufferTimeout() {
  _bufferTimeoutTimer = null;
  if (!mounted) return;
  final candidates = _candidates;
  if (candidates == null) return;
  if (_candidateIndex + 1 < candidates.length) {
    final previousCandidate = candidates[_candidateIndex];
    _candidateIndex++;
    unawaited(previousCandidate.dispose());
    _openCandidate(candidates[_candidateIndex]).catchError((Object e) {
      if (mounted) setState(() => _playbackError = e.toString());
    });
  } else {
    setState(() => _playbackError = '缓冲超时，未找到可用线路');
  }
}
```

- [ ] **Step 5: 在 `dispose()` 中取消计时器**

找到 `State` 类的 `dispose()` 方法，在其中新增（放在其他 `.cancel()` 调用附近）：

```dart
_bufferTimeoutTimer?.cancel();
```

- [ ] **Step 6: 运行 `flutter analyze`**

Run: `flutter analyze`
Expected: 0 error（可保留既有的 pre-existing info 级提示）。

- [ ] **Step 7: 运行全量测试回归**

Run: `flutter test`
Expected: PASS，全部测试通过（现有 435 个 + 本计划新增的测试）。

- [ ] **Step 8: 手工验证**

启动 App（`flutter run -d macos`），播放一集现有 HTTP 数据源（anime1 或 xifan）的内容，确认：
1. 播放正常开始，无报错。
2. 切换线路/退出播放页面时无异常。
（因为 HTTP 源的 `prepare()` 默认实现直接返回 `url`，`dispose()` 默认空操作，这一步验证 Task 5+10 的改动对现有源是透明的。）

- [ ] **Step 9: Commit**

```bash
git add lib/ui/player/player_screen.dart
git commit -m "feat(player): call prepare()/dispose() lifecycle hooks and add buffer timeout fallback"
```

---

### Task 11: 整体回归验证

**Files:**
- 无新文件（纯验证任务）

**Interfaces:**
- Consumes: 全部前述 Task 的产出
- Produces: 无

- [ ] **Step 1: 重新生成所有 codegen 文件**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: 成功，无冲突，无遗漏的 `*.g.dart`。

- [ ] **Step 2: 静态分析**

Run: `flutter analyze`
Expected: 0 error（pre-existing 的 28 条 info 级提示可保留不变）。

- [ ] **Step 3: 全量测试**

Run: `flutter test`
Expected: PASS，全部测试通过（现有 435 个 + 本计划新增的约 40+ 个测试，具体数字取决于每个 Task 实际新增的用例数）。

- [ ] **Step 4: 格式化检查**

Run: `dart format --output=none --set-exit-if-changed lib test`
Expected: exit code 0（无需要格式化的文件）。若有格式问题，运行 `dart format lib test` 后重新检查。

- [ ] **Step 5: 确认 git 状态干净**

Run: `git status`
Expected: 工作区干净（除本计划文档自身的历史 commit 外，无未提交改动）。

- [ ] **Step 6: 最终 commit（如有格式化改动）**

```bash
git add -A
git commit -m "chore: final formatting pass for Mikan BT media source feature" --allow-empty
```

---

## 已知限制 / 后续技术债（与 spec 一致，本次不实现）

- 无代理支持：BT 流量直连，不接入 `proxy_dio_config.dart`。
- 无离线缓存/保留/做种：`dispose()` 总是彻底删除种子文件；1→2（离线缓存）需一张新 Drift 表 + `schemaVersion` 3 迁移，留作后续增量。
- 多集合集单文件对应多集的场景（罕见）不支持：`pickVideoFile(episodeInSet:)` 参数已预留但当前实现忽略它，回退到"选最大文件"启发式。
- SP/OVA/特别篇分组为孤儿分组，本期无专门 UI 展示。
- `RssEpisode.episodeNumber == bangumiEpisode.sort` 采用直接数值相等的简化假设，未做绝对集数/季内集数换算。
- `resolvePlayback()` 的排序是简单启发式（按分辨率降序），非 Animeko 完整 `MediaSelector`（字幕组黑名单、语言偏好、tier 排序等）。
- 无 fastresume：应用重启后无法恢复种子下载进度（v1 范围内每次播放都是全新添加）。
- rqbit 二进制的实际打包路径（`macos/Runner/Resources/` 下如何嵌入、签名、公证）未在本计划范围内，`_rqbitBinaryPath()` 当前为占位实现，依赖 PATH 中存在同名可执行文件（开发环境可用 `brew install rqbit` 满足）。
