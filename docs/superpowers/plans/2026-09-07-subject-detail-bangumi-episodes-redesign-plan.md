# Subject Detail Bangumi-Episodes Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the subject-detail page's single "开始观看 (N集)" button + flat scraper-merged episode list with a Bangumi-driven episode-number grid, deferring media-source selection to a per-episode tap, and reorder the page per the approved design.

**Architecture:** Add a new, independent direct-to-Bangumi API client (bypassing this app's own backend, which has no episode-list endpoint) that drives a new episode-number grid widget. The existing scraper-merge machinery (`SubjectEpisodesController`/`MergedEpisode`) stays completely unchanged and keeps eagerly fetching/caching in the background; a new pure ordinal-position-matching function bridges "the Nth Bangumi episode" to "the Nth episode each scraper source returned", consulted only when a specific number is tapped. A new single-episode bottom sheet (a sibling of the existing multi-episode one, which stays untouched since it's still used elsewhere) shows the matched source(s) for that one tap.

**Tech Stack:** Flutter/Dart, Riverpod (`riverpod_annotation` codegen), `dio`, `json_serializable`, `mocktail`.

## Global Constraints

- Design spec: `docs/superpowers/specs/2026-09-07-subject-detail-bangumi-episodes-redesign-design.md` (all 6 sections + the updated Section 2/Risks — approved by the user).
- The new Bangumi episode client calls `https://api.bgm.tv` directly (bypassing this app's own `aniApiBaseUrl='https://api.animeko.org'` backend, which was confirmed via 20+ live-probed paths to have no episode-list endpoint). Verified real endpoint: `GET https://api.bgm.tv/v0/episodes?subject_id={id}&type=0&limit=100`, unauthenticated, response shape `{data: [...], total, limit, offset}` where each `data` item has (at minimum) `id`, `sort`, `name`, `name_cn`, `airdate`, `type`.
- The new client's `Dio` instance MUST call `configureProxy(dio, ref)` from `lib/data/settings/proxy_dio_config.dart` (same as every other non-`aniApiBaseUrl` client in this codebase, e.g. `lib/data/dilidili/dilidili_api.dart`'s `dilidiliDioProvider`) — no auth interceptor is needed or wanted for this client.
- Do **NOT** modify `lib/ui/subject/episode_source_grid.dart` or `lib/ui/subject/episode_source_sheet.dart` — both are still used unchanged inside `PlayerScreen`'s in-player drawer for mid-playback source switching, which this feature must not affect. Any new single-episode widget is a **new** file.
- Do **NOT** modify `lib/domain/play/subject_episodes_controller.dart`'s logic — `MergedEpisode`/`SubjectEpisodesController` stay code-unchanged (still drives the background eager scraper fetch/cache); only its *role* changes (no longer feeds the top-level UI button directly).
- Only `type == 0` (正片) Bangumi episodes go into the grid — filter client-side defensively even though the server's own `type=0` query param already filters.
- Out of scope (per the design's Section 6): no new staff/infobox/relations API work; no support for series with more than 100 main episodes (`limit=100` is a hard cap, no pagination); no auto-source-preference memory; no changes to the multi-line playback auto-fallback logic in `lib/ui/player/player_screen.dart`; no changes to Yinghua/Dilidili's disabled status in `lib/domain/media/media_registry.dart`; no whole-app visual re-skin.
- After every task that adds/changes a `@riverpod` or `@JsonSerializable` annotation, run `dart run build_runner build --delete-conflicting-outputs` before that task's tests are expected to compile.
- `flutter analyze` must stay at 0 errors (pre-existing info-level issues are fine) and `flutter test` must stay green after every task that touches `lib/` or `test/`. Baseline immediately before this feature: **411 tests passing, 0 failures**.
- Conventional Commits with scope, one commit per task (Task 7 makes no commit — verification only).
- `SubjectDetailScreen` currently has **no** existing widget test file (`test/ui/subject/` has no `subject_detail_screen_test.dart`) — this is a pre-existing gap, not something this plan introduces or is required to fix. Task 6's own verification is `flutter analyze` + manual review, consistent with this existing gap (mirrors how `PlayerScreen` was treated in the earlier multi-line-playback-fallback feature).

## File Structure

- **Create** `lib/data/subject/bangumi_episode_models.dart` — `BangumiEpisode`, `BangumiEpisodesResponse` (json_serializable).
- **Create** `lib/data/subject/bangumi_episodes_api.dart` — `BangumiEpisodesApi`, `bangumiEpisodesDioProvider`, `bangumiEpisodesApiProvider`.
- **Create** `lib/domain/subject/subject_bangumi_episodes_controller.dart` — `SubjectBangumiEpisodesController`.
- **Create** `lib/domain/play/episode_source_matcher.dart` — `matchEpisodeSources` pure function.
- **Create** `lib/ui/subject/bangumi_episode_grid.dart` — `BangumiEpisodeGrid` widget.
- **Create** `lib/ui/subject/episode_playback_sheet.dart` — `EpisodePlaybackSheet` widget.
- **Modify** `lib/ui/subject/subject_detail_screen.dart` — reorder sections, replace the old button with the new grid, add `airDate` to the header.
- Matching `test/` files for every new source file above.

---

### Task 1: Bangumi episode-list API client + model

**Files:**
- Create: `lib/data/subject/bangumi_episode_models.dart`
- Create: `lib/data/subject/bangumi_episodes_api.dart`
- Test: `test/data/subject/bangumi_episode_models_test.dart`
- Test: `test/data/subject/bangumi_episodes_api_test.dart`

**Interfaces:**
- Produces: `class BangumiEpisode { final int id; final num sort; final String name; final String nameCn; final String airdate; final int type; String get displayName; }`; `class BangumiEpisodesApi { Future<List<BangumiEpisode>> listEpisodes(int subjectId); }`; `bangumiEpisodesApiProvider` (riverpod).
- Consumes: `configureProxy(Dio, Ref)` from `lib/data/settings/proxy_dio_config.dart` (already exists, unchanged).

- [ ] **Step 1: Write the failing model test**

```dart
// test/data/subject/bangumi_episode_models_test.dart
import 'package:animeko_flutter/data/subject/bangumi_episode_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BangumiEpisode', () {
    test('parses a real /v0/episodes data item', () {
      final json = {
        'airdate': '2023-09-29',
        'name': '冒険の終わり',
        'name_cn': '冒险结束',
        'duration': '00:26:00',
        'desc': '...',
        'ep': 1,
        'sort': 1,
        'id': 1227087,
        'subject_id': 400602,
        'comment': 297,
        'type': 0,
        'disc': 0,
        'duration_seconds': 1560,
      };

      final episode = BangumiEpisode.fromJson(json);

      expect(episode.id, 1227087);
      expect(episode.sort, 1);
      expect(episode.name, '冒険の終わり');
      expect(episode.nameCn, '冒险结束');
      expect(episode.airdate, '2023-09-29');
      expect(episode.type, 0);
    });

    test('displayName prefers nameCn, falls back to name when nameCn is empty', () {
      const withCn = BangumiEpisode(
        id: 1,
        sort: 1,
        name: 'EN',
        nameCn: '中文',
        airdate: '',
        type: 0,
      );
      const withoutCn = BangumiEpisode(
        id: 2,
        sort: 2,
        name: 'EN Only',
        nameCn: '',
        airdate: '',
        type: 0,
      );

      expect(withCn.displayName, '中文');
      expect(withoutCn.displayName, 'EN Only');
    });
  });

  group('BangumiEpisodesResponse', () {
    test('parses the {data,total,limit,offset} wrapper', () {
      final json = {
        'data': [
          {
            'airdate': '2023-09-29',
            'name': 'A',
            'name_cn': 'A_CN',
            'ep': 1,
            'sort': 1,
            'id': 1,
            'type': 0,
          },
        ],
        'total': 28,
        'limit': 1,
        'offset': 0,
      };

      final response = BangumiEpisodesResponse.fromJson(json);

      expect(response.data, hasLength(1));
      expect(response.data.single.id, 1);
      expect(response.total, 28);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/subject/bangumi_episode_models_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'animeko_flutter/data/subject/bangumi_episode_models.dart'` (file doesn't exist yet).

- [ ] **Step 3: Write the model file**

```dart
// lib/data/subject/bangumi_episode_models.dart
import 'package:json_annotation/json_annotation.dart';

part 'bangumi_episode_models.g.dart';

/// One item of Bangumi's own public `GET /v0/episodes` response's
/// `data` array. Verified against a live request (2026-09-07,
/// `https://api.bgm.tv/v0/episodes?subject_id=400602&type=0&limit=1`):
/// ```json
/// {
///   "airdate": "2023-09-29", "name": "冒険の終わり", "name_cn": "冒险结束",
///   "duration": "00:26:00", "desc": "...", "ep": 1, "sort": 1,
///   "id": 1227087, "subject_id": 400602, "comment": 297, "type": 0,
///   "disc": 0, "duration_seconds": 1560
/// }
/// ```
/// Deliberately lean subset -- `duration`/`desc`/`ep`/`subject_id`/
/// `comment`/`disc`/`duration_seconds` are all real fields the UI
/// doesn't need (YAGNI); `json_serializable`'s generated `fromJson`
/// ignores undeclared keys, so omitting them is safe (same pattern as
/// `SubjectDetail` in `subject_models.dart`).
@JsonSerializable()
class BangumiEpisode {
  const BangumiEpisode({
    required this.id,
    required this.sort,
    required this.name,
    required this.nameCn,
    required this.airdate,
    required this.type,
  });

  final int id;
  final num sort;
  final String name;

  @JsonKey(name: 'name_cn')
  final String nameCn;

  final String airdate;

  /// 0 = 正片 (main episode), 1 = SP, 2 = OP, 3 = ED, etc. Only
  /// `type == 0` episodes are ever shown in the grid -- see
  /// `SubjectBangumiEpisodesController`.
  final int type;

  /// Display title -- prefers the Chinese name per the design doc's
  /// Section 2, falling back to the original name when no Chinese name
  /// exists.
  String get displayName => nameCn.isNotEmpty ? nameCn : name;

  factory BangumiEpisode.fromJson(Map<String, dynamic> json) =>
      _$BangumiEpisodeFromJson(json);

  Map<String, dynamic> toJson() => _$BangumiEpisodeToJson(this);
}

/// Wrapper for `GET /v0/episodes`'s paginated response shape --
/// `{data: [...], total, limit, offset}`. `total`/`limit`/`offset` are
/// unused by `BangumiEpisodesApi` (no pagination this pass, see the
/// design doc's `limit=100` hard cap) but are declared so
/// `json_serializable`'s generated `fromJson` has a shape to parse the
/// full response against.
@JsonSerializable()
class BangumiEpisodesResponse {
  const BangumiEpisodesResponse({
    required this.data,
    required this.total,
    required this.limit,
    required this.offset,
  });

  final List<BangumiEpisode> data;
  final int total;
  final int limit;
  final int offset;

  factory BangumiEpisodesResponse.fromJson(Map<String, dynamic> json) =>
      _$BangumiEpisodesResponseFromJson(json);

  Map<String, dynamic> toJson() => _$BangumiEpisodesResponseToJson(this);
}
```

- [ ] **Step 4: Regenerate codegen and run the model test**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: writes `lib/data/subject/bangumi_episode_models.g.dart`, exit 0.

Run: `flutter test test/data/subject/bangumi_episode_models_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Write the failing API-client test**

```dart
// test/data/subject/bangumi_episodes_api_test.dart
import 'package:animeko_flutter/data/subject/bangumi_episodes_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

Response<Map<String, dynamic>> jsonResponse(Map<String, dynamic> body) {
  return Response(
    data: body,
    requestOptions: RequestOptions(path: '/v0/episodes'),
    statusCode: 200,
  );
}

void main() {
  late MockDio dio;
  late BangumiEpisodesApi api;

  setUp(() {
    dio = MockDio();
    api = BangumiEpisodesApi(dio);
  });

  group('listEpisodes', () {
    final body = {
      'data': [
        {
          'airdate': '2023-09-29',
          'name': '冒険の終わり',
          'name_cn': '冒险结束',
          'ep': 1,
          'sort': 1,
          'id': 1227087,
          'type': 0,
        },
      ],
      'total': 28,
      'limit': 100,
      'offset': 0,
    };

    test('GETs /v0/episodes with subject_id, type=0, limit=100', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer((_) async => jsonResponse(body));

      await api.listEpisodes(400602);

      verify(
        () => dio.get<Map<String, dynamic>>(
          '/v0/episodes',
          queryParameters: {'subject_id': 400602, 'type': 0, 'limit': 100},
        ),
      ).called(1);
    });

    test('parses the response into a list of BangumiEpisode', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer((_) async => jsonResponse(body));

      final episodes = await api.listEpisodes(400602);

      expect(episodes, hasLength(1));
      expect(episodes.single.id, 1227087);
      expect(episodes.single.nameCn, '冒险结束');
    });
  });
}
```

- [ ] **Step 6: Run test to verify it fails**

Run: `flutter test test/data/subject/bangumi_episodes_api_test.dart`
Expected: FAIL — `bangumi_episodes_api.dart` doesn't exist yet.

- [ ] **Step 7: Write the API client + providers**

```dart
// lib/data/subject/bangumi_episodes_api.dart
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../settings/proxy_dio_config.dart';
import 'bangumi_episode_models.dart';

part 'bangumi_episodes_api.g.dart';

/// Base URL for Bangumi's own official public API -- **not** this
/// app's own backend (`aniApiBaseUrl` in `../api_client.dart`). This is
/// the first client in this codebase to call `api.bgm.tv` directly:
/// investigation (2026-09-07) confirmed `https://api.animeko.org` has
/// no episode-list endpoint under any of 20+ probed paths (only a
/// single-episode-by-ID lookup exists, with no way to enumerate episode
/// IDs), so this feature calls Bangumi's real public API directly
/// instead -- see the design doc's Section 2 and Risks.
const bangumiApiBaseUrl = 'https://api.bgm.tv';

const _connectTimeout = Duration(seconds: 15);
const _receiveTimeout = Duration(seconds: 15);

/// Direct client for Bangumi's own public episode-list endpoint.
/// Unauthenticated -- confirmed via a live request that no auth header
/// is required to read `/v0/episodes`.
class BangumiEpisodesApi {
  BangumiEpisodesApi(this._dio);
  final Dio _dio;

  /// GET /v0/episodes?subject_id={subjectId}&type=0&limit=100 --
  /// `type=0` filters to main episodes server-side (SP/OP/ED excluded).
  /// `limit=100` is a hard cap per the design doc (no pagination this
  /// pass); series with more than 100 main episodes are out of scope.
  Future<List<BangumiEpisode>> listEpisodes(int subjectId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v0/episodes',
      queryParameters: {'subject_id': subjectId, 'type': 0, 'limit': 100},
    );
    return BangumiEpisodesResponse.fromJson(response.data!).data;
  }
}

@riverpod
Dio bangumiEpisodesDio(Ref ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: bangumiApiBaseUrl,
      connectTimeout: _connectTimeout,
      receiveTimeout: _receiveTimeout,
    ),
  );
  configureProxy(dio, ref);
  return dio;
}

@riverpod
BangumiEpisodesApi bangumiEpisodesApi(Ref ref) =>
    BangumiEpisodesApi(ref.watch(bangumiEpisodesDioProvider));
```

- [ ] **Step 8: Regenerate codegen and run both test files**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: writes `lib/data/subject/bangumi_episodes_api.g.dart`, exit 0.

Run: `flutter test test/data/subject/bangumi_episode_models_test.dart test/data/subject/bangumi_episodes_api_test.dart`
Expected: PASS (5 tests total).

- [ ] **Step 9: `flutter analyze` on the touched files, then commit**

Run: `flutter analyze lib/data/subject/bangumi_episode_models.dart lib/data/subject/bangumi_episodes_api.dart`
Expected: No issues found.

```bash
git add lib/data/subject/bangumi_episode_models.dart lib/data/subject/bangumi_episode_models.g.dart \
        lib/data/subject/bangumi_episodes_api.dart lib/data/subject/bangumi_episodes_api.g.dart \
        test/data/subject/bangumi_episode_models_test.dart test/data/subject/bangumi_episodes_api_test.dart
git commit -m "feat(subject): add direct Bangumi episode-list API client

api.animeko.org has no episode-list endpoint (verified via 20+ probed
paths, all 404). This adds a new, independent client that calls
Bangumi's own public API directly at https://api.bgm.tv/v0/episodes,
per the approved design's Section 2 (Option A)."
```

---

### Task 2: `SubjectBangumiEpisodesController`

**Files:**
- Create: `lib/domain/subject/subject_bangumi_episodes_controller.dart`
- Test: `test/domain/subject/subject_bangumi_episodes_controller_test.dart`

**Interfaces:**
- Consumes: `bangumiEpisodesApiProvider` (Task 1), `BangumiEpisode` (Task 1).
- Produces: `subjectBangumiEpisodesControllerProvider({required int subjectId})` → `Future<List<BangumiEpisode>>`, already filtered to `type == 0` and sorted ascending by `sort`. Consumed by Task 6.

- [ ] **Step 1: Write the failing test**

```dart
// test/domain/subject/subject_bangumi_episodes_controller_test.dart
import 'package:animeko_flutter/data/subject/bangumi_episode_models.dart';
import 'package:animeko_flutter/data/subject/bangumi_episodes_api.dart';
import 'package:animeko_flutter/domain/subject/subject_bangumi_episodes_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class MockBangumiEpisodesApi extends Mock implements BangumiEpisodesApi {}

void main() {
  group('SubjectBangumiEpisodesController', () {
    late MockBangumiEpisodesApi api;
    late ProviderContainer container;

    setUp(() {
      api = MockBangumiEpisodesApi();
      container = ProviderContainer(
        overrides: [bangumiEpisodesApiProvider.overrideWithValue(api)],
      );
      addTearDown(container.dispose);
    });

    Future<List<BangumiEpisode>> read() => container.read(
          subjectBangumiEpisodesControllerProvider(subjectId: 400602).future,
        );

    test('filters out non-main episodes (SP/OP/ED) and sorts by sort ascending', () async {
      when(() => api.listEpisodes(400602)).thenAnswer(
        (_) async => [
          const BangumiEpisode(id: 3, sort: 2, name: 'ep2', nameCn: '第2集', airdate: '', type: 0),
          const BangumiEpisode(id: 1, sort: 0, name: 'SP', nameCn: 'SP', airdate: '', type: 1),
          const BangumiEpisode(id: 2, sort: 1, name: 'ep1', nameCn: '第1集', airdate: '', type: 0),
        ],
      );

      final result = await read();

      expect(result.map((e) => e.id), [2, 3]);
    });

    test('propagates the underlying API exception', () async {
      when(() => api.listEpisodes(400602)).thenThrow(Exception('network down'));

      await expectLater(read(), throwsA(isA<Exception>()));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/domain/subject/subject_bangumi_episodes_controller_test.dart`
Expected: FAIL — file/provider doesn't exist yet.

- [ ] **Step 3: Write the controller**

```dart
// lib/domain/subject/subject_bangumi_episodes_controller.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/subject/bangumi_episode_models.dart';
import '../../data/subject/bangumi_episodes_api.dart';

part 'subject_bangumi_episodes_controller.g.dart';

/// Fetches the Bangumi-canonical episode list for [subjectId] via
/// [BangumiEpisodesApi], filters to `type == 0` (main episodes --
/// SP/OP/ED excluded, defensive even though the API's own `type=0`
/// query param already filters server-side), and sorts ascending by
/// [BangumiEpisode.sort].
///
/// Fully independent of `SubjectEpisodesController` -- neither provider
/// blocks the other; see the design doc's Section 4.
@riverpod
class SubjectBangumiEpisodesController extends _$SubjectBangumiEpisodesController {
  @override
  Future<List<BangumiEpisode>> build({required int subjectId}) async {
    final episodes = await ref.watch(bangumiEpisodesApiProvider).listEpisodes(subjectId);
    final mainEpisodes = episodes.where((e) => e.type == 0).toList()
      ..sort((a, b) => a.sort.compareTo(b.sort));
    return mainEpisodes;
  }
}
```

- [ ] **Step 4: Regenerate codegen and run the test**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: writes `lib/domain/subject/subject_bangumi_episodes_controller.g.dart`, exit 0.

Run: `flutter test test/domain/subject/subject_bangumi_episodes_controller_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: `flutter analyze`, then commit**

Run: `flutter analyze lib/domain/subject/subject_bangumi_episodes_controller.dart`
Expected: No issues found.

```bash
git add lib/domain/subject/subject_bangumi_episodes_controller.dart \
        lib/domain/subject/subject_bangumi_episodes_controller.g.dart \
        test/domain/subject/subject_bangumi_episodes_controller_test.dart
git commit -m "feat(subject): add SubjectBangumiEpisodesController"
```

---

### Task 3: `matchEpisodeSources` ordinal-position matcher

**Files:**
- Create: `lib/domain/play/episode_source_matcher.dart`
- Test: `test/domain/play/episode_source_matcher_test.dart`

**Interfaces:**
- Consumes: `MergedEpisode` (`lib/domain/play/subject_episodes_controller.dart`, unchanged).
- Produces: `List<MergedEpisode> matchEpisodeSources({required int ordinalIndex, required List<MergedEpisode> allMerged})`. Consumed by Task 4 (grid button state) and Task 5 (sheet content).

- [ ] **Step 1: Write the failing test**

```dart
// test/domain/play/episode_source_matcher_test.dart
import 'package:animeko_flutter/domain/media/media_source.dart';
import 'package:animeko_flutter/domain/play/episode_source_matcher.dart';
import 'package:animeko_flutter/domain/play/subject_episodes_controller.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeEpisode implements MediaEpisode {
  const _FakeEpisode(this.sourceId, this.title);
  @override
  final String sourceId;
  @override
  final String title;
}

void main() {
  group('matchEpisodeSources', () {
    test('returns one match per source at the same ordinal position', () {
      final merged = [
        const MergedEpisode(episode: _FakeEpisode('a', 'A第1集'), sourceId: 'a'),
        const MergedEpisode(episode: _FakeEpisode('a', 'A第2集'), sourceId: 'a'),
        const MergedEpisode(episode: _FakeEpisode('b', 'B第1集'), sourceId: 'b'),
        const MergedEpisode(episode: _FakeEpisode('b', 'B第2集'), sourceId: 'b'),
      ];

      final result = matchEpisodeSources(ordinalIndex: 1, allMerged: merged);

      expect(result.map((e) => e.episode.title), ['A第2集', 'B第2集']);
    });

    test('skips a source that has fewer episodes than ordinalIndex', () {
      final merged = [
        const MergedEpisode(episode: _FakeEpisode('a', 'A第1集'), sourceId: 'a'),
        const MergedEpisode(episode: _FakeEpisode('b', 'B第1集'), sourceId: 'b'),
        const MergedEpisode(episode: _FakeEpisode('b', 'B第2集'), sourceId: 'b'),
      ];

      final result = matchEpisodeSources(ordinalIndex: 1, allMerged: merged);

      expect(result.map((e) => e.episode.title), ['B第2集']);
    });

    test('returns an empty list when no source has an episode at that position', () {
      final merged = [
        const MergedEpisode(episode: _FakeEpisode('a', 'A第1集'), sourceId: 'a'),
      ];

      final result = matchEpisodeSources(ordinalIndex: 5, allMerged: merged);

      expect(result, isEmpty);
    });

    test('returns an empty list for an empty input list', () {
      final result = matchEpisodeSources(ordinalIndex: 0, allMerged: const []);

      expect(result, isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/domain/play/episode_source_matcher_test.dart`
Expected: FAIL — `episode_source_matcher.dart` doesn't exist yet.

- [ ] **Step 3: Write the pure function**

```dart
// lib/domain/play/episode_source_matcher.dart
import 'subject_episodes_controller.dart';

/// Finds every [MergedEpisode] across [allMerged]'s sources whose
/// position -- within that source's own original list order -- equals
/// [ordinalIndex] (0-based). Used to map a Bangumi episode's position
/// in the canonical episode-number grid back to the scraper-side
/// episodes that (probably) correspond to it, without any title
/// parsing: matching is purely positional, since episode-title formats
/// aren't consistent across sources (see the design doc's Section 3
/// and Risks -- this assumes each source's own episode list is already
/// in the correct episode order, which holds for every source
/// registered today but isn't independently verified).
///
/// A source with fewer than `ordinalIndex + 1` episodes simply
/// contributes no match (no error). The returned list preserves
/// [allMerged]'s original source-grouping order (i.e. the order each
/// source's first episode first appeared in [allMerged], which is the
/// order `SubjectEpisodesController` queried `mediaSourcesProvider`'s
/// sources in); it may be empty (no source has an episode at that
/// position), contain exactly one match, or contain one match per
/// registered source.
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

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/domain/play/episode_source_matcher_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: `flutter analyze`, then commit**

Run: `flutter analyze lib/domain/play/episode_source_matcher.dart`
Expected: No issues found.

```bash
git add lib/domain/play/episode_source_matcher.dart test/domain/play/episode_source_matcher_test.dart
git commit -m "feat(play): add matchEpisodeSources ordinal-position matcher"
```

---

### Task 4: `BangumiEpisodeGrid` widget

**Files:**
- Create: `lib/ui/subject/bangumi_episode_grid.dart`
- Test: `test/ui/subject/bangumi_episode_grid_test.dart`

**Interfaces:**
- Consumes: `BangumiEpisode` (Task 1), `MergedEpisode` (unchanged), `matchEpisodeSources` (Task 3).
- Produces: `class BangumiEpisodeGrid extends StatelessWidget { const BangumiEpisodeGrid({required List<BangumiEpisode> episodes, required AsyncValue<List<MergedEpisode>> mergedEpisodesAsync, required void Function(int ordinalIndex, BangumiEpisode episode) onEpisodeTap}); }`. Consumed by Task 6.

- [ ] **Step 1: Write the failing test**

```dart
// test/ui/subject/bangumi_episode_grid_test.dart
import 'package:animeko_flutter/data/subject/bangumi_episode_models.dart';
import 'package:animeko_flutter/domain/media/media_source.dart';
import 'package:animeko_flutter/domain/play/subject_episodes_controller.dart';
import 'package:animeko_flutter/ui/subject/bangumi_episode_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeEpisode implements MediaEpisode {
  const _FakeEpisode({required this.sourceId, required this.title});
  @override
  final String sourceId;
  @override
  final String title;
}

void main() {
  const episodes = [
    BangumiEpisode(id: 1, sort: 1, name: 'A', nameCn: '第1集', airdate: '', type: 0),
    BangumiEpisode(id: 2, sort: 2, name: 'B', nameCn: '第2集', airdate: '', type: 0),
  ];

  testWidgets('renders one button per episode, labeled by sort', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BangumiEpisodeGrid(
            episodes: episodes,
            mergedEpisodesAsync: const AsyncLoading(),
            onEpisodeTap: (_, _) {},
          ),
        ),
      ),
    );

    expect(find.text('01'), findsOneWidget);
    expect(find.text('02'), findsOneWidget);
  });

  testWidgets('tapping a button calls onEpisodeTap with the right ordinal index and episode', (
    tester,
  ) async {
    int? tappedIndex;
    BangumiEpisode? tappedEpisode;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BangumiEpisodeGrid(
            episodes: episodes,
            mergedEpisodesAsync: const AsyncLoading(),
            onEpisodeTap: (index, episode) {
              tappedIndex = index;
              tappedEpisode = episode;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('02'));

    expect(tappedIndex, 1);
    expect(tappedEpisode, episodes[1]);
  });

  testWidgets('dims a button (OutlinedButton) when no scraper source matched it', (
    tester,
  ) async {
    final merged = AsyncData<List<MergedEpisode>>([
      MergedEpisode(
        episode: const _FakeEpisode(sourceId: 'anime1', title: '第1集'),
        sourceId: 'anime1',
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BangumiEpisodeGrid(
            episodes: episodes,
            mergedEpisodesAsync: merged,
            onEpisodeTap: (_, _) {},
          ),
        ),
      ),
    );

    // Ordinal 0 (episode "01") has a match -> normal button. Ordinal 1
    // (episode "02") has no match -> dimmed OutlinedButton, still
    // present and tappable.
    expect(find.widgetWithText(OutlinedButton, '02'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '01'), findsNothing);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/ui/subject/bangumi_episode_grid_test.dart`
Expected: FAIL — `bangumi_episode_grid.dart` doesn't exist yet.

- [ ] **Step 3: Write the widget**

```dart
// lib/ui/subject/bangumi_episode_grid.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/subject/bangumi_episode_models.dart';
import '../../domain/play/episode_source_matcher.dart';
import '../../domain/play/subject_episodes_controller.dart';

/// Compact grid of Bangumi episode-number buttons (01/02/03/...),
/// replacing the old single "开始观看" button. Tapping a number opens
/// a per-episode source-selection sheet (see `EpisodePlaybackSheet`).
///
/// Each button's visual state depends on the *scraper* episode list
/// ([mergedEpisodesAsync]), matched positionally via
/// [matchEpisodeSources]: while it's still loading, every button
/// renders in the same normal/neutral style (not yet distinguishing
/// has-source/no-source, per the design doc's Section 2 state 3); once
/// loaded, a button renders normal/clickable if at least one scraper
/// source has an episode at that position, or dimmed (but still
/// clickable -- tapping shows "暂无播放源") otherwise.
class BangumiEpisodeGrid extends StatelessWidget {
  const BangumiEpisodeGrid({
    super.key,
    required this.episodes,
    required this.mergedEpisodesAsync,
    required this.onEpisodeTap,
  });

  final List<BangumiEpisode> episodes;
  final AsyncValue<List<MergedEpisode>> mergedEpisodesAsync;
  final void Function(int ordinalIndex, BangumiEpisode episode) onEpisodeTap;

  @override
  Widget build(BuildContext context) {
    final merged = mergedEpisodesAsync.valueOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text('剧集', style: Theme.of(context).textTheme.titleSmall),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < episodes.length; i++)
                _EpisodeNumberButton(
                  episode: episodes[i],
                  // merged == null means the scraper fetch is still in
                  // flight -- neutral state, not yet has/no-source.
                  hasSource: merged == null
                      ? null
                      : matchEpisodeSources(ordinalIndex: i, allMerged: merged).isNotEmpty,
                  onTap: () => onEpisodeTap(i, episodes[i]),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EpisodeNumberButton extends StatelessWidget {
  const _EpisodeNumberButton({
    required this.episode,
    required this.hasSource,
    required this.onTap,
  });

  final BangumiEpisode episode;

  /// null = still loading (neutral state); true = at least one scraper
  /// source matched; false = no source matched (dimmed, still
  /// tappable).
  final bool? hasSource;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = Text(episode.sort.round().toString().padLeft(2, '0'));

    if (hasSource == false) {
      final disabledColor = Theme.of(context).disabledColor;
      return OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 40),
          foregroundColor: disabledColor,
          side: BorderSide(color: disabledColor),
        ),
        child: label,
      );
    }
    // hasSource == true or null (still loading) both render as the
    // normal/neutral clickable style -- see the class doc comment.
    return FilledButton.tonal(
      onPressed: onTap,
      style: FilledButton.styleFrom(minimumSize: const Size(48, 40)),
      child: label,
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/ui/subject/bangumi_episode_grid_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: `flutter analyze`, then commit**

Run: `flutter analyze lib/ui/subject/bangumi_episode_grid.dart`
Expected: No issues found.

```bash
git add lib/ui/subject/bangumi_episode_grid.dart test/ui/subject/bangumi_episode_grid_test.dart
git commit -m "feat(subject): add BangumiEpisodeGrid widget"
```

---

### Task 5: `EpisodePlaybackSheet` widget

**Files:**
- Create: `lib/ui/subject/episode_playback_sheet.dart`
- Test: `test/ui/subject/episode_playback_sheet_test.dart`

**Interfaces:**
- Consumes: `BangumiEpisode` (Task 1), `matchEpisodeSources` (Task 3), `subjectEpisodesControllerProvider`/`MergedEpisode` (unchanged), `mediaSourcesProvider` (unchanged), `sourceLabel` (exported from `lib/ui/subject/episode_source_sheet.dart`, unchanged — reused, not modified).
- Produces: `class EpisodePlaybackSheet extends ConsumerWidget { const EpisodePlaybackSheet({required int subjectId, required String subjectName, required int ordinalIndex, required BangumiEpisode bangumiEpisode}); }`. Consumed by Task 6.

- [ ] **Step 1: Write the failing test**

```dart
// test/ui/subject/episode_playback_sheet_test.dart
import 'package:animeko_flutter/data/subject/bangumi_episode_models.dart';
import 'package:animeko_flutter/domain/media/media_registry.dart';
import 'package:animeko_flutter/domain/media/media_source.dart';
import 'package:animeko_flutter/ui/subject/episode_playback_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _FakeCandidate implements MediaCandidate {
  const _FakeCandidate(this.sourceId, this.title);
  @override
  final String sourceId;
  @override
  final String title;
}

class _FakeEpisode implements MediaEpisode {
  const _FakeEpisode({required this.sourceId, required this.title});
  @override
  final String sourceId;
  @override
  final String title;
}

class MockMediaSource extends Mock implements MediaSource {}

void main() {
  setUpAll(() {
    registerFallbackValue(const _FakeCandidate('fallback', 'fallback'));
  });

  const bangumiEpisode = BangumiEpisode(
    id: 1,
    sort: 1,
    name: 'EN',
    nameCn: '第1集',
    airdate: '2023-09-29',
    type: 0,
  );

  Widget wrap(Widget child, {required List<Override> overrides}) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(home: Scaffold(body: child)),
    );
  }

  testWidgets('shows a loading indicator while the merged list is still loading', (
    tester,
  ) async {
    final source = MockMediaSource();
    when(() => source.id).thenReturn('anime1');
    when(() => source.displayName).thenReturn('anime1.me');
    when(() => source.search(any())).thenAnswer(
      () => Future.delayed(const Duration(seconds: 5), () => const []),
    );

    await tester.pumpWidget(
      wrap(
        const EpisodePlaybackSheet(
          subjectId: 1,
          subjectName: '目标番剧',
          ordinalIndex: 0,
          bangumiEpisode: bangumiEpisode,
        ),
        overrides: [mediaSourcesProvider.overrideWithValue([source])],
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows "暂无播放源" when no source has an episode at this position', (
    tester,
  ) async {
    final source = MockMediaSource();
    when(() => source.id).thenReturn('anime1');
    when(() => source.displayName).thenReturn('anime1.me');
    when(() => source.search(any())).thenAnswer((_) async => const []);

    await tester.pumpWidget(
      wrap(
        const EpisodePlaybackSheet(
          subjectId: 1,
          subjectName: '目标番剧',
          ordinalIndex: 0,
          bangumiEpisode: bangumiEpisode,
        ),
        overrides: [mediaSourcesProvider.overrideWithValue([source])],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('暂无播放源'), findsOneWidget);
  });

  testWidgets('shows one row with a 播放 button for a matched source', (tester) async {
    final source = MockMediaSource();
    when(() => source.id).thenReturn('anime1');
    when(() => source.displayName).thenReturn('anime1.me');
    when(() => source.search('目标番剧')).thenAnswer(
      (_) async => [const _FakeCandidate('anime1', '目标番剧')],
    );
    when(() => source.listEpisodes(any())).thenAnswer(
      (_) async => [const _FakeEpisode(sourceId: 'anime1', title: '第1集')],
    );

    await tester.pumpWidget(
      wrap(
        const EpisodePlaybackSheet(
          subjectId: 1,
          subjectName: '目标番剧',
          ordinalIndex: 0,
          bangumiEpisode: bangumiEpisode,
        ),
        overrides: [mediaSourcesProvider.overrideWithValue([source])],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('anime1.me'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '播放'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/ui/subject/episode_playback_sheet_test.dart`
Expected: FAIL — `episode_playback_sheet.dart` doesn't exist yet.

- [ ] **Step 3: Write the widget**

```dart
// lib/ui/subject/episode_playback_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/subject/bangumi_episode_models.dart';
import '../../domain/media/media_registry.dart';
import '../../domain/play/episode_source_matcher.dart';
import '../../domain/play/subject_episodes_controller.dart';
import 'episode_source_sheet.dart' show sourceLabel;

/// Modal bottom sheet for exactly one Bangumi episode's playback
/// sources -- opened by tapping a number in `BangumiEpisodeGrid`.
///
/// Unlike `EpisodeSourceSheet` (which lists every episode across every
/// source, and stays unmodified/still used elsewhere), this always
/// shows exactly one episode's matched candidates (via
/// [matchEpisodeSources]), even when there's only one -- see the
/// design doc's Section 3 (Q8: interaction consistency, never
/// auto-skip straight to playback). Reads live from
/// `subjectEpisodesControllerProvider` so it auto-refreshes if the
/// background scraper fetch is still in flight when opened.
class EpisodePlaybackSheet extends ConsumerWidget {
  const EpisodePlaybackSheet({
    super.key,
    required this.subjectId,
    required this.subjectName,
    required this.ordinalIndex,
    required this.bangumiEpisode,
  });

  final int subjectId;
  final String subjectName;
  final int ordinalIndex;
  final BangumiEpisode bangumiEpisode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mergedAsync = ref.watch(
      subjectEpisodesControllerProvider(subjectId: subjectId, subjectName: subjectName),
    );
    final sources = ref.watch(mediaSourcesProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(bangumiEpisode.displayName, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            mergedAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              // Any failure to fetch/match the scraper-side episode
              // list (including MediaNotFoundException) is shown the
              // same as "no source matched" -- see the design doc's
              // Section 3.
              error: (error, stack) => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('暂无播放源'),
              ),
              data: (merged) {
                final matches = matchEpisodeSources(ordinalIndex: ordinalIndex, allMerged: merged);
                if (matches.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text('暂无播放源'),
                  );
                }
                return Column(
                  children: [
                    for (final match in matches)
                      ListTile(
                        title: Text(sourceLabel(sources, match.sourceId)),
                        trailing: FilledButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            context.push(
                              '/subject/$subjectId/play'
                              '?name=${Uri.encodeComponent(subjectName)}',
                              extra: match,
                            );
                          },
                          child: const Text('播放'),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/ui/subject/episode_playback_sheet_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: `flutter analyze`, then commit**

Run: `flutter analyze lib/ui/subject/episode_playback_sheet.dart`
Expected: No issues found.

```bash
git add lib/ui/subject/episode_playback_sheet.dart test/ui/subject/episode_playback_sheet_test.dart
git commit -m "feat(subject): add EpisodePlaybackSheet widget"
```

---

### Task 6: Wire the redesign into `SubjectDetailScreen`

**Files:**
- Modify: `lib/ui/subject/subject_detail_screen.dart`

**Interfaces:**
- Consumes: `subjectBangumiEpisodesControllerProvider` (Task 2), `BangumiEpisodeGrid` (Task 4), `EpisodePlaybackSheet` (Task 5). No new test file — this screen has no pre-existing widget test (Global Constraints); verification is `flutter analyze` + manual review.

- [ ] **Step 1: Update imports**

In `lib/ui/subject/subject_detail_screen.dart`, replace the entire import block (currently lines 2-18, i.e. including the three `package:` imports) with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/subject/collection_type.dart';
import '../../data/subject/subject_models.dart';
import '../../domain/play/subject_episodes_controller.dart';
import '../../domain/subject/subject_bangumi_episodes_controller.dart';
import '../../domain/subject/subject_collection_controller.dart';
import '../../domain/subject/subject_detail_controller.dart';
import '../common/error_retry_view.dart';
import '../common/rating_stars.dart';
import 'bangumi_episode_grid.dart';
import 'episode_playback_sheet.dart';
import 'expandable_summary.dart';
import 'subject_blurred_header.dart';
import 'subject_tags_row.dart';
```

Removed: `package:go_router/go_router.dart` (its only use was `context.push` inside the now-deleted `_openEpisodeSheet` function -- that navigation now lives in `episode_playback_sheet.dart` instead), `../../domain/media/media_registry.dart` and `../../domain/media/media_source.dart` (no longer referenced directly in this file), and `episode_source_sheet.dart`'s `EpisodeSourceSheet` import (replaced by the new `episode_playback_sheet.dart`/`bangumi_episode_grid.dart` imports).

- [ ] **Step 2: Replace `SubjectDetailScreen.build` and remove `_openEpisodeSheet`**

Replace everything from the current `build` method through the end of the `_openEpisodeSheet` function (lines 32-107, i.e. `build`, the class's own closing `}`, and the whole `_openEpisodeSheet` function) with the block below. It re-introduces the class-closing `}` right after the new `build` method, then adds the new `_BangumiEpisodesSection` class as a top-level sibling (matching the file's existing style, e.g. `_SubjectInfoSection`/`_ImmersiveHeader` below it) -- `_openEpisodeSheet` is not replaced with an equivalent function; its role is now split across `_BangumiEpisodesSection` and `EpisodePlaybackSheet` (Task 5):

```dart
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(subjectName)),
      body: ListView(
        children: [
          if (imageUrl != null) _ImmersiveHeader(subjectId: subjectId, imageUrl: imageUrl!),
          _BangumiEpisodesSection(subjectId: subjectId, subjectName: subjectName),
          _SubjectInfoSection(subjectId: subjectId),
          _CastStaffSection(subjectId: subjectId),
        ],
      ),
    );
  }
}

/// The Bangumi-canonical episode-number grid, replacing the old single
/// "开始观看" button. Sits directly after the immersive header and
/// before [_SubjectInfoSection] (design doc Section 1). Tapping a
/// number opens [EpisodePlaybackSheet] for that one episode -- see
/// Section 3.
class _BangumiEpisodesSection extends ConsumerWidget {
  const _BangumiEpisodesSection({required this.subjectId, required this.subjectName});

  final int subjectId;
  final String subjectName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bangumiProvider = subjectBangumiEpisodesControllerProvider(subjectId: subjectId);
    final bangumiEpisodes = ref.watch(bangumiProvider);
    final mergedEpisodesAsync = ref.watch(
      subjectEpisodesControllerProvider(subjectId: subjectId, subjectName: subjectName),
    );

    return bangumiEpisodes.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => ErrorRetryView(
        message: '加载剧集列表失败：$error',
        onRetry: () => ref.invalidate(bangumiProvider),
      ),
      data: (episodes) {
        if (episodes.isEmpty) return const SizedBox.shrink();
        return BangumiEpisodeGrid(
          episodes: episodes,
          mergedEpisodesAsync: mergedEpisodesAsync,
          onEpisodeTap: (ordinalIndex, episode) => showModalBottomSheet(
            context: context,
            builder: (_) => EpisodePlaybackSheet(
              subjectId: subjectId,
              subjectName: subjectName,
              ordinalIndex: ordinalIndex,
              bangumiEpisode: episode,
            ),
          ),
        );
      },
    );
  }
}
```

Note: this removes the closing `}` that used to belong to the deleted `_openEpisodeSheet` function's containing scope; make sure `SubjectDetailScreen`'s class closing brace (right after the new `build` method) and the new `_BangumiEpisodesSection` class are both syntactically top-level siblings, matching the surrounding file's existing style (`_SubjectInfoSection`, `_ImmersiveHeader`, etc. are all top-level classes below `SubjectDetailScreen`).

- [ ] **Step 3: Add `airDate` to the header's metadata row**

In `_HeaderInfo.build` (around the current lines 182-216), replace the score/rank `Row` block and add a helper function at file scope:

```dart
class _HeaderInfo extends StatelessWidget {
  const _HeaderInfo({required this.subjectId, required this.subject});

  final int subjectId;
  final SubjectDetail subject;

  @override
  Widget build(BuildContext context) {
    final score = subject.score != null ? double.tryParse(subject.score!) : null;
    final airDateLabel = _formatAirDateYearMonth(subject.airDate);
    final hasScoreOrRank = score != null || subject.rank != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          subject.nameCn.isNotEmpty ? subject.nameCn : subject.name,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        if (hasScoreOrRank || airDateLabel != null)
          Row(
            children: [
              if (score != null) RatingStars(score: score),
              if (subject.rank != null)
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text(
                    '排名：#${subject.rank}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              if (airDateLabel != null)
                Padding(
                  padding: EdgeInsets.only(left: hasScoreOrRank ? 12 : 0),
                  child: Text(
                    hasScoreOrRank ? '· $airDateLabel' : airDateLabel,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 8),
        _CollectionButtons(subjectId: subjectId),
      ],
    );
  }
}

/// Formats [airDate] (e.g. `"2023-09-29"`) as `"2023年9月"` for the
/// header's metadata row (design doc Section 5: year-month
/// granularity, not a full date). Returns null for an empty/unparsable
/// date so the caller can omit the whole element rather than showing a
/// blank `"· "`.
String? _formatAirDateYearMonth(String airDate) {
  final date = DateTime.tryParse(airDate);
  if (date == null) return null;
  return '${date.year}年${date.month}月';
}
```

- [ ] **Step 4: Regenerate codegen (safety net, no new `@riverpod`/`@JsonSerializable` in this task, but confirms nothing else drifted)**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: exit 0, no new/changed outputs beyond what Tasks 1-2 already generated.

- [ ] **Step 5: `flutter analyze` on the whole project**

Run: `flutter analyze`
Expected: 0 errors (only the same pre-existing info-level issues as the 411-test baseline).

- [ ] **Step 6: Run the full test suite**

Run: `flutter test`
Expected: all tests pass (baseline 411 + the new tests added in Tasks 1-5).

- [ ] **Step 7: Commit**

```bash
git add lib/ui/subject/subject_detail_screen.dart
git commit -m "feat(subject): drive detail page episode list from Bangumi data

Replaces the single '开始观看 (N集)' button + flat scraper-merged
episode list with a Bangumi-canonical episode-number grid. Tapping a
number now opens a per-episode source-selection sheet instead of
resolving all sources for all episodes up front. Reorders the page:
header (+ airDate) -> episode grid -> summary/tags/rating -> cast/staff.

Per the approved design's Sections 1/5. lib/domain/play/
subject_episodes_controller.dart is unchanged -- it still eagerly
fetches/caches the scraper-merged list in the background; only its
role changed (consumed per-tap via matchEpisodeSources instead of
driving the old button directly)."
```

---

### Task 7: Final end-to-end sanity pass

**Files:** none -- verification only.

- [ ] **Step 1: Full regression**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: exit 0, no unexpected diffs.

Run: `flutter analyze`
Expected: 0 errors.

Run: `flutter test`
Expected: all tests passing, 0 failures.

- [ ] **Step 2: Verify git state**

Run: `git status --short && git log --oneline -8`
Expected: clean working tree (except any pre-existing unrelated untracked files already present before this feature); log shows, newest first, Task 6's commit, Task 5's, Task 4's, Task 3's, Task 2's, Task 1's, then this plan/spec's own doc commits.

- [ ] **Step 3: Report to the user**

Summarize: the subject detail page now shows a Bangumi-driven episode-number grid instead of the old button; tapping a number opens a per-episode source-selection sheet; `airDate` is now shown in the header; the scraper-merge machinery (`SubjectEpisodesController`) is unchanged and still runs in the background. Note that this feature's episode data now comes from a **direct, unauthenticated call to Bangumi's own public API** (`https://api.bgm.tv`), not from this app's own backend -- the first such direct external call in this codebase (per the user's explicit Option-A decision) -- and that this is worth keeping in mind if Bangumi's public API ever changes shape or becomes rate-limited, since there's no fallback to the app's own backend for this one feature.
