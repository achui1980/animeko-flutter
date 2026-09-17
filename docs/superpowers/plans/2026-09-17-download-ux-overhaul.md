# 下载功能 UX 与可靠性重做 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the download feature's UX and reliability per `docs/superpowers/specs/2026-09-17-download-ux-overhaul-design.md` — a single reusable `DownloadPanel` (home/subject-detail/player), per-episode source selection, real progress that survives navigation, stall/timeout handling, and several correctness fixes (HTTP validation, delete-directory bug, cross-source "已下载" lookup).

**Architecture:** Keep the existing layering (Drift persistence → `DownloadWorker` → `DownloadQueueController` (Riverpod) → UI). Add a pure `download_source_resolver.dart` function shared by all four enqueue call sites. Make the queue controller `keepAlive` so progress survives navigation, and persist real progress (bytes/segments) to Drift so a fresh page load can show it too.

**Tech Stack:** Flutter/Dart (`sdk: ^3.11.4`), `flutter_riverpod: 3.3.1` + `riverpod_annotation: 4.0.2` (codegen via `riverpod_generator: 4.0.3`), `drift: 2.31.0` (codegen via `drift_dev: 2.31.0`), `dio: ^5.11.0`, `go_router: ^17.5.0`, `mocktail: ^1.0.5` for the one existing mock (`SettingsStorage`). Package name: `animeko_flutter`.

Every `flutter test` command below assumes `workdir=/Users/portz/js/animeko-flutter`. Every commit step assumes the same. Commit messages follow this repo's existing style: `type(scope): imperative phrase` (see `git log --oneline`), scope is `download` for almost everything, `subject`/`player`/`database` when the change is primarily in that layer.

---

### Task 1: Drift schema v4 → v5 — add progress + episodeDir columns

**Files:**
- Modify: `lib/data/local_database.dart:105-119` (table), `:136` (schemaVersion), `:144-159` (migration)
- Modify: `test/data/local_database_test.dart:104-106` (schemaVersion assertion)
- Test: `test/data/local_database_test.dart` (new migration test, appended near the existing `onUpgrade from schema 2` test at lines 157-178)

- [ ] **Step 1: Write the failing tests**

Add to `test/data/local_database_test.dart`, replacing the existing test at lines 104-106:

```dart
  test('AppDatabase.schemaVersion is 5 (bumped for download progress '
      'columns)', () {
    expect(db.schemaVersion, 5);
  });
```

Add a new test right after the existing `onUpgrade from schema 2 creates the mikanSubjectMappings table` test (after line 178, before the `searchHistory table round-trips a row` test):

```dart
  test(
    'onUpgrade from schema 4 adds the download progress columns',
    () async {
      // downloadedEpisodes already exists at schema 4 (added by an earlier
      // migration); simulate a schema-4 database by dropping just the new
      // columns this migration adds, then run the real onUpgrade callback
      // for the 4 -> 5 step.
      await db.customStatement(
        'ALTER TABLE downloaded_episodes DROP COLUMN received_bytes',
      );
      await db.customStatement(
        'ALTER TABLE downloaded_episodes DROP COLUMN total_bytes',
      );
      await db.customStatement(
        'ALTER TABLE downloaded_episodes DROP COLUMN downloaded_segments',
      );
      await db.customStatement(
        'ALTER TABLE downloaded_episodes DROP COLUMN total_segments',
      );
      await db.customStatement(
        'ALTER TABLE downloaded_episodes DROP COLUMN last_progress_at',
      );
      await db.customStatement(
        'ALTER TABLE downloaded_episodes DROP COLUMN episode_dir',
      );

      await db.migration.onUpgrade(Migrator(db), 4, 5);

      await db
          .into(db.downloadedEpisodes)
          .insert(
            DownloadedEpisodesCompanion.insert(
              sourceId: 'anime1',
              subjectId: 1,
              episodeKey: '1::anime1::1',
              subjectName: '测试番剧',
              episodeLabel: '1',
              localPath: '/tmp/one.mp4',
              format: 'mp4',
              status: 'completed',
              createdAt: DateTime(2026, 9, 17),
            ),
          );
      final row = await db.select(db.downloadedEpisodes).getSingle();
      expect(row.receivedBytes, 0);
      expect(row.totalBytes, isNull);
      expect(row.episodeDir, isNull);
    },
  );
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/data/local_database_test.dart --plain-name "schemaVersion is 5"`
Expected: FAIL — `Expected: <5> Actual: <4>`

- [ ] **Step 3: Update the table definition and migration**

In `lib/data/local_database.dart`, replace the `DownloadedEpisodes` table (currently lines 105-119):

```dart
class DownloadedEpisodes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get sourceId => text()();
  IntColumn get subjectId => integer()();
  TextColumn get episodeKey => text().unique()();
  TextColumn get subjectName => text()();
  TextColumn get episodeLabel => text()();
  TextColumn get localPath => text()();
  TextColumn get format => text()();
  IntColumn get fileSizeBytes => integer().nullable()();
  TextColumn get status => text()();
  TextColumn get errorMessage => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  /// mp4 downloads: bytes received so far. HLS downloads use
  /// [downloadedSegments] instead (segment-level progress; mp4-level byte
  /// counts for HLS would require re-parsing partial .ts files). Defaults
  /// to 0 so existing rows read back as "no progress" rather than null.
  IntColumn get receivedBytes =>
      integer().withDefault(const Constant(0))();
  /// mp4 downloads: total size from the `Content-Length` header, once
  /// known. Null for HLS (no single Content-Length) and for mp4 downloads
  /// before the response headers arrive.
  IntColumn get totalBytes => integer().nullable()();
  /// HLS downloads: segments downloaded so far.
  IntColumn get downloadedSegments => integer().nullable()();
  /// HLS downloads: total segment count, counted from the manifest before
  /// downloading starts.
  IntColumn get totalSegments => integer().nullable()();
  /// Last time [receivedBytes]/[downloadedSegments] increased. Used by the
  /// worker's stall detection (see `DownloadWorker`); not shown directly in
  /// the UI.
  DateTimeColumn get lastProgressAt => dateTime().nullable()();
  /// The directory this episode's file(s) live in, written once by
  /// `DownloadWorker` when it creates the directory. Deletion always uses
  /// this column, never [localPath] (which is a *file* path for completed
  /// downloads but historically was the *directory* path for
  /// downloading/failed ones — see the design spec's bug #7). Null on rows
  /// created before this migration; deletion falls back to the pre-v5
  /// heuristic for those (see `DownloadedEpisodeRepository.deleteWithFiles`).
  TextColumn get episodeDir => text().nullable()();
}
```

Replace `schemaVersion` (currently line 136):

```dart
  int get schemaVersion => 5;
```

Replace the `migration` getter's `onUpgrade` body (currently lines 144-159), adding one more `if`:

```dart
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(subjectImageCache);
      }
      if (from < 3) {
        await m.createTable(mikanSubjectMappings);
      }
      if (from < 4) {
        await m.createTable(downloadedEpisodes);
      }
      if (from < 5) {
        await m.addColumn(downloadedEpisodes, downloadedEpisodes.receivedBytes);
        await m.addColumn(downloadedEpisodes, downloadedEpisodes.totalBytes);
        await m.addColumn(
          downloadedEpisodes,
          downloadedEpisodes.downloadedSegments,
        );
        await m.addColumn(downloadedEpisodes, downloadedEpisodes.totalSegments);
        await m.addColumn(
          downloadedEpisodes,
          downloadedEpisodes.lastProgressAt,
        );
        await m.addColumn(downloadedEpisodes, downloadedEpisodes.episodeDir);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
```

- [ ] **Step 4: Regenerate Drift codegen**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: Regenerates `lib/data/local_database.g.dart` with `receivedBytes`, `totalBytes`, `downloadedSegments`, `totalSegments`, `lastProgressAt`, `episodeDir` added to `$DownloadedEpisodesTable`, `DownloadedEpisode` (the row data class), and `DownloadedEpisodesCompanion`.

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/data/local_database_test.dart`
Expected: PASS (all tests, including the two new/changed ones)

- [ ] **Step 6: Commit**

```bash
git add lib/data/local_database.dart lib/data/local_database.g.dart test/data/local_database_test.dart
git commit -m "feat(database): add download progress columns (schema v5)"
```

### Task 2: `DownloadStatus.interrupted` + `reconcileInterrupted()`

**Files:**
- Modify: `lib/data/download/downloaded_episode_repository.dart:8` (enum), append a method after `upsert` (currently ends at line 84)
- Test: `test/data/download/downloaded_episode_repository_test.dart` (append after the existing `watchAll` test, currently ending at line 121)

- [ ] **Step 1: Write the failing test**

Append to `test/data/download/downloaded_episode_repository_test.dart` (before the final closing `}`):

```dart

  test('reconcileInterrupted marks every downloading row as interrupted', () async {
    await repository.upsert(
      const DownloadedEpisodeWrite(
        sourceId: 'anime1',
        subjectId: 1,
        episodeKey: '1::anime1::1',
        subjectName: '测试番剧',
        episodeLabel: '1',
        localPath: '/tmp/one',
        format: 'mp4',
        status: DownloadStatus.downloading,
      ),
    );
    await repository.upsert(
      const DownloadedEpisodeWrite(
        sourceId: 'xifan',
        subjectId: 2,
        episodeKey: '2::xifan::2',
        subjectName: '测试番剧2',
        episodeLabel: '2',
        localPath: '/tmp/two.mp4',
        format: 'mp4',
        status: DownloadStatus.completed,
      ),
    );

    await repository.reconcileInterrupted();

    final rows = await repository.getAll();
    final one = rows.firstWhere((row) => row.episodeKey == '1::anime1::1');
    final two = rows.firstWhere((row) => row.episodeKey == '2::xifan::2');
    expect(one.status, DownloadStatus.interrupted.name);
    expect(two.status, DownloadStatus.completed.name);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/download/downloaded_episode_repository_test.dart --plain-name "reconcileInterrupted"`
Expected: FAIL — `The method 'reconcileInterrupted' isn't defined for the type 'DownloadedEpisodeRepository'.` (compile error)

- [ ] **Step 3: Implement**

In `lib/data/download/downloaded_episode_repository.dart`, change the enum on line 8:

```dart
enum DownloadStatus { downloading, completed, failed, interrupted }
```

Add this method to `DownloadedEpisodeRepository`, right after `upsert` (which currently ends at line 84, just before `delete`):

```dart
  /// Marks every row still in [DownloadStatus.downloading] as
  /// [DownloadStatus.interrupted]. Call once at app startup (from
  /// `DownloadQueueController.build()`) — a `downloading` row that survives
  /// to the next launch means the app was killed/crashed mid-download, so
  /// nothing is actually still writing to that file.
  Future<void> reconcileInterrupted() => (_db.update(_db.downloadedEpisodes)
        ..where((row) => row.status.equals(DownloadStatus.downloading.name)))
      .write(
        DownloadedEpisodesCompanion(status: Value(DownloadStatus.interrupted.name)),
      );
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/data/download/downloaded_episode_repository_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/data/download/downloaded_episode_repository.dart test/data/download/downloaded_episode_repository_test.dart
git commit -m "feat(download): reconcile interrupted downloads on startup"
```

---

### Task 3: cross-source lookup + centralized delete-with-files

**Files:**
- Modify: `lib/data/download/downloaded_episode_repository.dart` (append two methods)
- Test: `test/data/download/downloaded_episode_repository_test.dart` (append two tests)

- [ ] **Step 1: Write the failing tests**

Append to `test/data/download/downloaded_episode_repository_test.dart`:

```dart

  test('findCompletedForEpisode ignores sourceId', () async {
    await repository.upsert(
      const DownloadedEpisodeWrite(
        sourceId: 'anime1',
        subjectId: 1,
        episodeKey: '1::anime1::第6话',
        subjectName: '测试番剧',
        episodeLabel: '第6话',
        localPath: '/tmp/six.mp4',
        format: 'mp4',
        status: DownloadStatus.completed,
      ),
    );

    // Currently playing from a *different* source (e.g. mikan) than the
    // one the file was actually downloaded from (anime1) -- automatic
    // source selection (see download_source_resolver.dart) means this
    // mismatch is expected, not a bug.
    final found = await repository.findCompletedForEpisode(1, '第6话');
    expect(found, isNotNull);
    expect(found!.sourceId, 'anime1');

    expect(await repository.findCompletedForEpisode(1, '第7话'), isNull);
    expect(await repository.findCompletedForEpisode(2, '第6话'), isNull);
  });

  test('deleteWithFiles removes the record and its directory', () async {
    final dir = await Directory.systemTemp.createTemp('repo_delete_test_');
    addTearDown(() => dir.delete(recursive: true).catchError((_) {}));
    final file = File('${dir.path}/video.mp4');
    await file.writeAsBytes([1, 2, 3]);
    await repository.upsert(
      DownloadedEpisodeWrite(
        sourceId: 'anime1',
        subjectId: 1,
        episodeKey: '1::anime1::1',
        subjectName: '测试番剧',
        episodeLabel: '1',
        localPath: file.path,
        format: 'mp4',
        status: DownloadStatus.completed,
        episodeDir: dir.path,
      ),
    );

    await repository.deleteWithFiles('1::anime1::1');

    expect(await repository.findByKey('1::anime1::1'), isNull);
    expect(await dir.exists(), isFalse);
  });

  test('deleteWithFiles is a no-op for an unknown key', () async {
    await repository.deleteWithFiles('missing::key::1');
    // No exception -- nothing to assert beyond "did not throw".
  });
```

Add the `import 'dart:io';` line at the top of the test file if not already present (it is not — the current file only imports the repository, database, drift, and flutter_test packages).

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/data/download/downloaded_episode_repository_test.dart --plain-name "findCompletedForEpisode"`
Expected: FAIL — compile error, `findCompletedForEpisode` and `episodeDir` param undefined.

- [ ] **Step 3: Implement**

First, add the `episodeDir` field to `DownloadedEpisodeWrite` in the same file (currently lines 10-34):

```dart
class DownloadedEpisodeWrite {
  const DownloadedEpisodeWrite({
    required this.sourceId,
    required this.subjectId,
    required this.episodeKey,
    required this.subjectName,
    required this.episodeLabel,
    required this.localPath,
    required this.format,
    required this.status,
    this.fileSizeBytes,
    this.errorMessage,
    this.episodeDir,
  });

  final String sourceId;
  final int subjectId;
  final String episodeKey;
  final String subjectName;
  final String episodeLabel;
  final String localPath;
  final String format;
  final DownloadStatus status;
  final int? fileSizeBytes;
  final String? errorMessage;
  final String? episodeDir;
}
```

Update `upsert`'s `DownloadedEpisodesCompanion.insert(...)` call (currently lines 66-82) to pass it through — add one line after `errorMessage: Value(value.errorMessage),`:

```dart
            errorMessage: Value(value.errorMessage),
            episodeDir: Value(value.episodeDir),
```

Add `import 'dart:io';` to the top of `lib/data/download/downloaded_episode_repository.dart`. Then add these two methods after `reconcileInterrupted` (added in Task 2):

```dart
  /// Finds a completed download of [episodeTitle] under [subjectId],
  /// regardless of which source it was downloaded from. Used wherever the
  /// app needs to know "is this episode available offline" without also
  /// knowing/caring which source produced the file — automatic source
  /// selection (see `download_source_resolver.dart`) means the file on disk
  /// may not match whichever source the episode is *currently* being
  /// browsed/played from.
  Future<DownloadedEpisode?> findCompletedForEpisode(
    int subjectId,
    String episodeTitle,
  ) => (_db.select(_db.downloadedEpisodes)
        ..where((row) => row.subjectId.equals(subjectId))
        ..where((row) => row.episodeLabel.equals(episodeTitle))
        ..where((row) => row.status.equals(DownloadStatus.completed.name)))
      .getSingleOrNull();

  /// Deletes the DB record for [episodeKey] and, best-effort, its backing
  /// files. Used by the UI's manual delete action and by
  /// `DownloadQueueController.retry` when it cleans up a stale download left
  /// behind after automatically switching to a different source.
  ///
  /// Uses [DownloadedEpisode.episodeDir] when present. Rows written before
  /// schema v5 have a null `episodeDir` -- for those, falls back to the
  /// pre-v5 heuristic (`localPath` is a file for `completed` rows, a
  /// directory for every other status), matching the old (buggy, see design
  /// spec bug #7) `DownloadListItem.deleteLocalPath` behavior exactly so
  /// legacy rows don't regress.
  Future<void> deleteWithFiles(String episodeKey) async {
    final row = await findByKey(episodeKey);
    if (row == null) return;
    final dirPath = row.episodeDir ??
        (row.status == DownloadStatus.completed.name
            ? Directory(row.localPath).parent.path
            : row.localPath);
    try {
      await Directory(dirPath).delete(recursive: true);
    } on FileSystemException {
      // Files may already be gone; the DB row still needs removing.
    }
    await delete(episodeKey);
  }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/data/download/downloaded_episode_repository_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/data/download/downloaded_episode_repository.dart test/data/download/downloaded_episode_repository_test.dart
git commit -m "feat(download): add cross-source lookup and centralized delete"
```

### Task 4: `download_source_resolver.dart` — shared auto-select-source function

**Files:**
- Create: `lib/domain/download/download_source_resolver.dart`
- Test: `test/domain/download/download_source_resolver_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:animeko_flutter/domain/download/download_source_resolver.dart';
import 'package:animeko_flutter/domain/media/media_source.dart';
import 'package:animeko_flutter/domain/play/subject_episodes_controller.dart';
import 'package:flutter_test/flutter_test.dart';

class _Episode implements MediaEpisode {
  const _Episode(this.sourceId, this.title);

  @override
  final String sourceId;
  @override
  final String title;
}

MergedEpisode _e(String sourceId, String title) =>
    MergedEpisode(episode: _Episode(sourceId, title), sourceId: sourceId);

void main() {
  group('resolveDownloadOptions', () {
    test('groups by title and keeps only downloadable sources', () {
      final merged = [
        _e('anime1', '第1集'),
        _e('mikan', '第1集'),
        _e('mikan', '第2集'),
      ];

      final options = resolveDownloadOptions(merged);

      expect(options, hasLength(2));
      final first = options.firstWhere((o) => o.title == '第1集');
      expect(first.isDownloadable, isTrue);
      expect(first.candidates.map((c) => c.sourceId), ['anime1']);
      final second = options.firstWhere((o) => o.title == '第2集');
      expect(second.isDownloadable, isFalse);
      expect(second.candidates, isEmpty);
    });

    test('prefers anime1 over xifan when both are available', () {
      final merged = [_e('xifan', '第1集'), _e('anime1', '第1集')];

      final options = resolveDownloadOptions(merged);

      expect(options.single.preferred!.sourceId, 'anime1');
      expect(
        options.single.candidates.map((c) => c.sourceId),
        ['anime1', 'xifan'],
      );
    });

    test('an episode with only xifan is still downloadable', () {
      final options = resolveDownloadOptions([_e('xifan', '第1集')]);

      expect(options.single.isDownloadable, isTrue);
      expect(options.single.preferred!.sourceId, 'xifan');
    });

    test('an episode available on no HTTP source is not downloadable', () {
      final options = resolveDownloadOptions([_e('mikan', '第1集')]);

      expect(options.single.isDownloadable, isFalse);
      expect(options.single.preferred, isNull);
    });

    test('preserves the merged list\'s title order', () {
      final merged = [_e('anime1', '第2集'), _e('anime1', '第1集')];

      final options = resolveDownloadOptions(merged);

      expect(options.map((o) => o.title), ['第2集', '第1集']);
    });
  });

  group('resolvePreferredDownloadSource', () {
    test('finds the preferred candidate for a single episode by title', () {
      final merged = [_e('xifan', '第1集'), _e('anime1', '第1集')];

      final match = resolvePreferredDownloadSource(merged, '第1集');

      expect(match!.sourceId, 'anime1');
    });

    test('returns null when no HTTP source has this episode', () {
      final merged = [_e('mikan', '第1集')];

      expect(resolvePreferredDownloadSource(merged, '第1集'), isNull);
    });

    test('returns null when the title does not exist at all', () {
      final merged = [_e('anime1', '第1集')];

      expect(resolvePreferredDownloadSource(merged, '第99集'), isNull);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/domain/download/download_source_resolver_test.dart`
Expected: FAIL — `Error: Error when reading 'lib/domain/download/download_source_resolver.dart': No such file or directory.`

- [ ] **Step 3: Implement**

```dart
// lib/domain/download/download_source_resolver.dart
import '../media/media_source.dart';
import '../play/subject_episodes_controller.dart';

/// Registered HTTP direct-link sources that support downloading, in
/// priority order. Must stay in sync with `DownloadWorker.enqueue`'s own
/// allow-list (`lib/data/download/download_worker.dart`) -- BT/RSS sources
/// (e.g. `'mikan'`) are deliberately excluded (see the design spec's
/// explicit out-of-scope list).
const downloadableSourcePriority = ['anime1', 'xifan'];

/// One episode (identified by [title], the join key across sources --
/// mirrors how `EpisodeNumberGrid` already groups [MergedEpisode]s) and
/// every HTTP-downloadable source that has it, ordered by
/// [downloadableSourcePriority].
class EpisodeDownloadOption {
  const EpisodeDownloadOption({required this.title, required this.candidates});

  final String title;

  /// Downloadable-source candidates for this episode. Empty when no
  /// registered HTTP download source has it (e.g. Mikan/BT only).
  final List<MergedEpisode> candidates;

  bool get isDownloadable => candidates.isNotEmpty;

  /// The source that should actually be used if the caller doesn't need to
  /// show every option (e.g. the player's single-episode download button,
  /// or the "download selected" batch action).
  MergedEpisode? get preferred => candidates.isEmpty ? null : candidates.first;
}

int _priorityOf(String sourceId) {
  final index = downloadableSourcePriority.indexOf(sourceId);
  return index == -1 ? downloadableSourcePriority.length : index;
}

/// Groups [merged] by episode title, keeping only HTTP-downloadable source
/// candidates per group (ordered by priority). One [EpisodeDownloadOption]
/// per distinct title, in the order titles first appear in [merged]. Pure
/// function -- no network, no Flutter import -- shared by the episode
/// selection tab, batch "download selected", the player's single-episode
/// download button, and `DownloadQueueController.retry`.
List<EpisodeDownloadOption> resolveDownloadOptions(
  List<MergedEpisode> merged,
) {
  final byTitle = <String, List<MergedEpisode>>{};
  for (final episode in merged) {
    byTitle.putIfAbsent(episode.title, () => []).add(episode);
  }
  return byTitle.entries
      .map(
        (entry) => EpisodeDownloadOption(
          title: entry.key,
          candidates: entry.value
              .where(
                (e) => downloadableSourcePriority.contains(e.sourceId),
              )
              .toList()
            ..sort((a, b) => _priorityOf(a.sourceId).compareTo(_priorityOf(b.sourceId))),
        ),
      )
      .toList();
}

/// Resolves the best downloadable candidate for a single episode by
/// [episodeTitle] -- e.g. for the player's download button when the
/// currently-playing source (which may be Mikan/BT) isn't itself
/// downloadable, or for `DownloadQueueController.retry` re-selecting a
/// source after the original one stopped having the episode. Returns null
/// when no registered HTTP source has this episode.
MergedEpisode? resolvePreferredDownloadSource(
  List<MergedEpisode> merged,
  String episodeTitle,
) {
  final matches = merged
      .where(
        (e) =>
            e.title == episodeTitle &&
            downloadableSourcePriority.contains(e.sourceId),
      )
      .toList()
    ..sort((a, b) => _priorityOf(a.sourceId).compareTo(_priorityOf(b.sourceId)));
  return matches.isEmpty ? null : matches.first;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/domain/download/download_source_resolver_test.dart`
Expected: PASS (11 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/domain/download/download_source_resolver.dart test/domain/download/download_source_resolver_test.dart
git commit -m "feat(download): add shared auto-select-source resolver"
```
### Task 5: Snapshot the download directory into each `DownloadRequest`

**Why:** `DownloadQueueController.build()` currently `watch`es `downloadSettingsControllerProvider` so `DownloadWorker` always has the latest directory, but any change to the setting rebuilds the whole controller and wipes the in-flight queue (spec bug #2). Task 11 fixes that by making `build()` stop watching the setting — which means `DownloadWorker` can no longer read the directory from its own constructor. Instead, each `DownloadRequest` carries its own `downloadRoot`, captured at `enqueue()` time.

**Files:**
- Modify: `lib/data/download/download_worker.dart`
- Modify: `test/data/download/download_worker_test.dart`

- [ ] **Step 1: Update the failing test helper and call sites**

Open `test/data/download/download_worker_test.dart`. Change the `_request` helper (around line 119) to require a `downloadRoot`:

```dart
DownloadRequest _request(
  String sourceId,
  int subjectId, {
  required String downloadRoot,
}) => DownloadRequest(
  subjectId: subjectId,
  subjectName: 'Subject $subjectId',
  sourceId: sourceId,
  episode: _Episode(sourceId, '$subjectId'),
  episodeLabel: '$subjectId',
  downloadRoot: downloadRoot,
);
```

Update every call site in the same file to pass `downloadRoot: root.path` and remove the now-redundant `downloadRoot: root.path` argument from every `DownloadWorker(...)` constructor call (5 call sites: "resolves the second request...", "rejects a request from an unsupported source", "prefers an MP4 candidate...", "cancelling an active request...", "persists a failure message..."). For example the first test's calls become:

```dart
final worker = DownloadWorker(
  dio: _dio({
    'https://cdn.example/first.mp4': [1],
    'https://cdn.example/second.mp4': [2],
  }),
  sourceForId: (id) => sources[id]!,
  repository: repository,
)..events.listen(events.add);

worker.enqueue(_request('anime1', 1, downloadRoot: root.path));
worker.enqueue(_request('xifan', 2, downloadRoot: root.path));
```

Do the same (drop `downloadRoot:` from the `DownloadWorker(...)` call, add `downloadRoot: root.path` to every `_request(...)` call) for the other 4 tests.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/data/download/download_worker_test.dart`
Expected: FAIL — compile error, `DownloadRequest` has no `downloadRoot` parameter yet and `DownloadWorker`'s constructor still requires one.

- [ ] **Step 3: Add `downloadRoot` to `DownloadRequest` and drop it from `DownloadWorker`'s constructor**

In `lib/data/download/download_worker.dart`, update `DownloadRequest`:

```dart
class DownloadRequest {
  const DownloadRequest({
    required this.subjectId,
    required this.subjectName,
    required this.sourceId,
    required this.episode,
    required this.episodeLabel,
    required this.downloadRoot,
  });

  final int subjectId;
  final String subjectName;
  final String sourceId;
  final MediaEpisode episode;
  final String episodeLabel;

  /// Snapshotted at enqueue time from `DownloadSettingsController`. Reading
  /// it here (rather than `DownloadWorker` reading a single shared root at
  /// construction time) means an in-flight download keeps writing to the
  /// directory the user had configured when they started it, even if they
  /// change the setting mid-download -- see the design doc's decision to
  /// stop `DownloadQueueController.build()` from watching the download
  /// directory (otherwise every settings change would rebuild the worker
  /// and silently drop the whole queue).
  final String downloadRoot;

  String get episodeKey => '$subjectId::$sourceId::${episode.title}';
}
```

Update `DownloadWorker`'s constructor to drop the `downloadRoot` parameter and field:

```dart
class DownloadWorker {
  DownloadWorker({
    required Dio dio,
    required MediaSource Function(String sourceId) sourceForId,
    required DownloadedEpisodeRepository repository,
  }) : _dio = dio,
       _sourceForId = sourceForId,
       _repository = repository;

  final Dio _dio;
  final MediaSource Function(String) _sourceForId;
  final DownloadedEpisodeRepository _repository;
  final _queue = <DownloadRequest>[];
  final _events = StreamController<DownloadEvent>.broadcast();
  CancelToken? _cancelToken;
  DownloadRequest? _active;
  Completer<void>? _idle;
```

(the `_downloadRoot` field is removed entirely). Update `_download()` to read `request.downloadRoot` instead of `_downloadRoot`:

```dart
  Future<void> _download(DownloadRequest request) async {
    final directory = Directory(
      p.join(
        request.downloadRoot,
        request.sourceId,
        request.subjectId.toString(),
        request.episodeLabel,
      ),
    );
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/data/download/download_worker_test.dart`
Expected: PASS (all 5 existing tests green).

- [ ] **Step 5: Commit**

```bash
git add lib/data/download/download_worker.dart test/data/download/download_worker_test.dart
git commit -m "refactor(download): snapshot download root per request"
```
### Task 6: Detect stalled downloads, retry once, and give up cleanly

**Why:** The worker has no notion of "this connection stopped delivering bytes" — a hung Anime1/Xifan connection blocks the single-task queue forever (spec bug #11, and half of the user's "很久都不动" complaint). Per the approved design: 30s with no new bytes → mark stalled, cancel, auto-retry once; stalled again after the retry → fail and move to the next queued item; from the moment a request is dequeued, if it has received *zero* bytes for a full 2 minutes, fail immediately even if individual stall-retries kept resetting the "time since last byte" clock. While bytes keep arriving, there is no timeout at all.

**Files:**
- Modify: `lib/data/download/download_worker.dart`
- Modify: `test/data/download/download_worker_test.dart`

- [ ] **Step 1: Update the now-obsolete "rejects unsupported source" test**

`enqueue()` is about to stop throwing synchronously for unsupported sources (it now writes a `failed` record instead — the design doc's fix for spec bug #4). Replace the existing test in `test/data/download/download_worker_test.dart`:

```dart
  test('rejects a request from an unsupported source', () {
    final worker = DownloadWorker(
      dio: _dio({}),
      sourceForId: (_) => throw UnimplementedError(),
      repository: repository,
    );

    expect(() => worker.enqueue(_request('rss', 1)), throwsArgumentError);
  });
```

with:

```dart
  test(
    'writes a failed record instead of throwing for an unsupported source',
    () async {
      final events = <DownloadEvent>[];
      final worker = DownloadWorker(
        dio: _dio({}),
        sourceForId: (_) => throw UnimplementedError(),
        repository: repository,
      )..events.listen(events.add);
      final request = _request('rss', 1, downloadRoot: root.path);

      worker.enqueue(request);
      await Future<void>.delayed(Duration.zero);

      final record = await repository.findByKey(request.episodeKey);
      expect(record!.status, DownloadStatus.failed.name);
      expect(record.errorMessage, '此来源不支持下载');
      expect(events.whereType<DownloadFailed>(), hasLength(1));
    },
  );
```

(Also drop the now-unused `downloadRoot: root.path` mismatch check — `_request` already requires it per Task 5.)

- [ ] **Step 2: Add the stall-detection failing tests**

Add a new fake adapter and three tests to `test/data/download/download_worker_test.dart`. Add near the top, after the existing `_Adapter` class:

```dart
/// Never delivers bytes for the first `stallOnAttempt` calls to any URL --
/// it just waits on `cancelFuture` and throws the cancellation dio expects,
/// simulating a connection that hangs until the stall watchdog cancels it.
/// From the `stallOnAttempt + 1`th call onward it serves [responses]
/// normally, simulating "the retry succeeds".
class _StallThenSucceedAdapter implements HttpClientAdapter {
  _StallThenSucceedAdapter(this.responses, {this.stallOnAttempt = 1});

  final Map<String, Object> responses;
  final int stallOnAttempt;
  var _callCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    _callCount++;
    if (_callCount <= stallOnAttempt) {
      await cancelFuture;
      throw DioException.requestCancelled(
        requestOptions: options,
        reason: 'stalled',
      );
    }
    final response = responses[options.uri.toString()];
    if (response is List<int>) {
      return ResponseBody.fromBytes(Uint8List.fromList(response), 200);
    }
    return ResponseBody.fromString(
      response as String? ?? '',
      response == null ? 404 : 200,
    );
  }

  @override
  void close({bool force = false}) {}
}
```

Then add these three tests at the end of `main()`, before the closing `}`:

```dart
  test('retries once after a stall, then succeeds on the retry', () async {
    final events = <DownloadEvent>[];
    final dio = Dio()
      ..httpClientAdapter = _StallThenSucceedAdapter({
        'https://cdn.example/video.mp4': [1, 2, 3],
      });
    final worker = DownloadWorker(
      dio: dio,
      sourceForId: (_) => _Source('anime1', const [
        _PlaybackSource('https://cdn.example/video.mp4'),
      ]),
      repository: repository,
      stallTimeout: const Duration(milliseconds: 20),
      stallCheckInterval: const Duration(milliseconds: 5),
      noProgressTimeout: const Duration(seconds: 5),
    )..events.listen(events.add);

    worker.enqueue(_request('anime1', 1, downloadRoot: root.path));
    await worker.whenIdle;

    expect(events.whereType<DownloadStalled>(), hasLength(1));
    expect(events.whereType<DownloadCompleted>(), hasLength(1));
  });

  test('fails and moves on when a stall persists through the retry', () async {
    final events = <DownloadEvent>[];
    final dio = Dio()
      ..httpClientAdapter = _StallThenSucceedAdapter(
        const {},
        stallOnAttempt: 2,
      );
    final worker = DownloadWorker(
      dio: dio,
      sourceForId: (_) => _Source('anime1', const [
        _PlaybackSource('https://cdn.example/video.mp4'),
      ]),
      repository: repository,
      stallTimeout: const Duration(milliseconds: 20),
      stallCheckInterval: const Duration(milliseconds: 5),
      noProgressTimeout: const Duration(seconds: 5),
    )..events.listen(events.add);
    final request = _request('anime1', 1, downloadRoot: root.path);

    worker.enqueue(request);
    await worker.whenIdle;

    expect(events.whereType<DownloadStalled>(), hasLength(1));
    final failed = events.whereType<DownloadFailed>().single;
    expect(failed.message, contains('停滞'));
    final record = await repository.findByKey(request.episodeKey);
    expect(record!.status, DownloadStatus.failed.name);
  });

  test(
    'gives up at the zero-byte ceiling without waiting for the stall timeout',
    () async {
      final events = <DownloadEvent>[];
      final dio = Dio()
        ..httpClientAdapter = _StallThenSucceedAdapter(
          const {},
          stallOnAttempt: 999,
        );
      final worker = DownloadWorker(
        dio: dio,
        sourceForId: (_) => _Source('anime1', const [
          _PlaybackSource('https://cdn.example/video.mp4'),
        ]),
        repository: repository,
        // Deliberately larger than noProgressTimeout so only the
        // zero-byte ceiling can be the one that fires.
        stallTimeout: const Duration(seconds: 30),
        stallCheckInterval: const Duration(milliseconds: 5),
        noProgressTimeout: const Duration(milliseconds: 20),
      )..events.listen(events.add);
      final request = _request('anime1', 1, downloadRoot: root.path);

      worker.enqueue(request);
      await worker.whenIdle;

      expect(events.whereType<DownloadStalled>(), isEmpty);
      final failed = events.whereType<DownloadFailed>().single;
      expect(failed.message, contains('未能连接'));
    },
  );
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test test/data/download/download_worker_test.dart`
Expected: FAIL — `DownloadWorker` has no `stallTimeout`/`stallCheckInterval`/`noProgressTimeout` parameters yet, and `DownloadStalled` does not exist.

- [ ] **Step 4: Add the `DownloadStalled` event and the stall watchdog**

In `lib/data/download/download_worker.dart`, add the import `import 'dart:async';` is already present. Add a new event class right after `DownloadQueued`:

```dart
/// Emitted once per stall-triggered retry (not on the final give-up) so the
/// UI can show "已停滞，正在重试" -- see [DownloadQueueItem.isStalled] in
/// `download_queue_controller.dart`. Purely transient: never persisted to
/// the [DownloadedEpisodeRepository].
class DownloadStalled extends DownloadEvent {
  const DownloadStalled(super.request);
}
```

Add the internal signal enum and a small result enum right above the `DownloadWorker` class:

```dart
/// Threaded through [CancelToken.cancel] so `_attempt`'s catch block can
/// tell a stall-triggered cancellation apart from a real user-initiated
/// [DownloadWorker.cancel] call.
enum _StallSignal { retryOnce, giveUp }

enum _AttemptResult { done, stalledRetry }
```

Replace the whole `DownloadWorker` class body with:

```dart
class DownloadWorker {
  DownloadWorker({
    required Dio dio,
    required MediaSource Function(String sourceId) sourceForId,
    required DownloadedEpisodeRepository repository,
    this.stallTimeout = const Duration(seconds: 30),
    this.noProgressTimeout = const Duration(minutes: 2),
    this.stallCheckInterval = const Duration(seconds: 1),
  }) : _dio = dio,
       _sourceForId = sourceForId,
       _repository = repository;

  final Dio _dio;
  final MediaSource Function(String) _sourceForId;
  final DownloadedEpisodeRepository _repository;

  /// How long without a new [DownloadProgress] event before the active
  /// attempt is considered stalled. Production default 30s per the design
  /// doc; tests inject millisecond-scale values instead of waiting real
  /// seconds.
  final Duration stallTimeout;

  /// Absolute ceiling on how long a request may sit at zero received bytes
  /// (measured from the moment it is dequeued, not reset by the one
  /// automatic stall-retry) before it is failed outright. Production
  /// default 2 minutes.
  final Duration noProgressTimeout;

  /// How often the watchdog re-checks elapsed time.
  final Duration stallCheckInterval;

  final _queue = <DownloadRequest>[];
  final _events = StreamController<DownloadEvent>.broadcast();
  CancelToken? _cancelToken;
  DownloadRequest? _active;
  Completer<void>? _idle;

  Stream<DownloadEvent> get events => _events.stream;
  Future<void> get whenIdle => _idle?.future ?? Future.value();

  void enqueue(DownloadRequest request) {
    if (request.sourceId != 'anime1' && request.sourceId != 'xifan') {
      unawaited(_failUnsupportedSource(request));
      return;
    }
    if (_active?.episodeKey == request.episodeKey ||
        _queue.any((item) => item.episodeKey == request.episodeKey)) {
      return;
    }
    _queue.add(request);
    _events.add(DownloadQueued(request));
    _idle ??= Completer<void>();
    if (_active == null) unawaited(_drain());
  }

  Future<void> _failUnsupportedSource(DownloadRequest request) async {
    const message = '此来源不支持下载';
    await _repository.upsert(
      DownloadedEpisodeWrite(
        sourceId: request.sourceId,
        subjectId: request.subjectId,
        episodeKey: request.episodeKey,
        subjectName: request.subjectName,
        episodeLabel: request.episodeLabel,
        localPath: '',
        episodeDir: null,
        format: 'mp4',
        status: DownloadStatus.failed,
        errorMessage: message,
      ),
    );
    _events.add(DownloadFailed(request, message));
  }

  void cancel(String episodeKey) {
    _queue.removeWhere((item) => item.episodeKey == episodeKey);
    if (_active?.episodeKey == episodeKey) _cancelToken?.cancel();
  }

  Future<void> _drain() async {
    while (_queue.isNotEmpty) {
      _active = _queue.removeAt(0);
      await _downloadWithStallRetry(_active!);
      _active = null;
    }
    _idle?.complete();
    _idle = null;
  }

  Future<void> _downloadWithStallRetry(DownloadRequest request) async {
    final first = await _attempt(request, hasRetried: false);
    if (first == _AttemptResult.stalledRetry) {
      await _attempt(request, hasRetried: true);
    }
  }

  Future<_AttemptResult> _attempt(
    DownloadRequest request, {
    required bool hasRetried,
  }) async {
    final directory = Directory(
      p.join(
        request.downloadRoot,
        request.sourceId,
        request.subjectId.toString(),
        request.episodeLabel,
      ),
    );
    _cancelToken = CancelToken();
    var lastProgressAt = DateTime.now();
    final startedAt = lastProgressAt;
    var receivedTotal = 0;

    final watchdog = Timer.periodic(stallCheckInterval, (_) {
      final now = DateTime.now();
      if (receivedTotal == 0 && now.difference(startedAt) >= noProgressTimeout) {
        _cancelToken?.cancel(_StallSignal.giveUp);
        return;
      }
      if (now.difference(lastProgressAt) >= stallTimeout) {
        if (hasRetried) {
          _cancelToken?.cancel(_StallSignal.giveUp);
        } else {
          _events.add(DownloadStalled(request));
          _cancelToken?.cancel(_StallSignal.retryOnce);
        }
      }
    });

    void onProgress(int received, int total) {
      receivedTotal = received;
      lastProgressAt = DateTime.now();
      _events.add(DownloadProgress(request, received, total));
    }

    try {
      await directory.create(recursive: true);
      await _repository.upsert(
        DownloadedEpisodeWrite(
          sourceId: request.sourceId,
          subjectId: request.subjectId,
          episodeKey: request.episodeKey,
          subjectName: request.subjectName,
          episodeLabel: request.episodeLabel,
          localPath: directory.path,
          episodeDir: directory.path,
          format: 'mp4',
          status: DownloadStatus.downloading,
        ),
      );
      final candidates = List<MediaPlaybackSource>.of(
        await _sourceForId(request.sourceId).resolvePlayback(request.episode),
      );
      final selected = candidates.firstWhere(
        (item) => item.url.toLowerCase().contains('.mp4'),
        orElse: () => candidates.first,
      );
      final url = await selected.prepare();
      final isHls = Uri.parse(url).path.toLowerCase().endsWith('.m3u8');
      final localPath = isHls
          ? p.join(directory.path, 'playlist.m3u8')
          : p.join(directory.path, 'video.mp4');
      final size = isHls
          ? (await HlsDownloader(_dio).download(
              manifestUrl: Uri.parse(url),
              targetDirectory: directory,
              headers: selected.headers,
              cancelToken: _cancelToken,
              onProgress: onProgress,
            )).fileSizeBytes
          : await _downloadFile(
              url,
              localPath,
              selected.headers,
              onProgress,
            );
      await _repository.upsert(
        DownloadedEpisodeWrite(
          sourceId: request.sourceId,
          subjectId: request.subjectId,
          episodeKey: request.episodeKey,
          subjectName: request.subjectName,
          episodeLabel: request.episodeLabel,
          localPath: localPath,
          episodeDir: directory.path,
          format: isHls ? 'hls' : 'mp4',
          status: DownloadStatus.completed,
          fileSizeBytes: size,
        ),
      );
      _events.add(DownloadCompleted(request));
      return _AttemptResult.done;
    } catch (error) {
      if (error is DioException && CancelToken.isCancel(error)) {
        final reason = error.error;
        if (reason == _StallSignal.retryOnce) return _AttemptResult.stalledRetry;
        if (reason == _StallSignal.giveUp) {
          final message = receivedTotal == 0
              ? '一直未能连接到下载源，已跳过'
              : '下载已停滞，重试后仍无进展，已跳过';
          await _repository.upsert(
            DownloadedEpisodeWrite(
              sourceId: request.sourceId,
              subjectId: request.subjectId,
              episodeKey: request.episodeKey,
              subjectName: request.subjectName,
              episodeLabel: request.episodeLabel,
              localPath: directory.path,
              episodeDir: directory.path,
              format: 'mp4',
              status: DownloadStatus.failed,
              errorMessage: message,
            ),
          );
          _events.add(DownloadFailed(request, message));
          return _AttemptResult.done;
        }
        // A real user-initiated cancel() call.
        if (await directory.exists()) await directory.delete(recursive: true);
        await _repository.delete(request.episodeKey);
        _events.add(DownloadCancelled(request));
        return _AttemptResult.done;
      }
      await _repository.upsert(
        DownloadedEpisodeWrite(
          sourceId: request.sourceId,
          subjectId: request.subjectId,
          episodeKey: request.episodeKey,
          subjectName: request.subjectName,
          episodeLabel: request.episodeLabel,
          localPath: directory.path,
          episodeDir: directory.path,
          format: 'mp4',
          status: DownloadStatus.failed,
          errorMessage: error.toString(),
        ),
      );
      _events.add(DownloadFailed(request, error.toString()));
      return _AttemptResult.done;
    } finally {
      watchdog.cancel();
      _cancelToken = null;
    }
  }

  Future<int> _downloadFile(
    String url,
    String path,
    Map<String, String> headers,
    void Function(int received, int total) onProgress,
  ) async {
    await _dio.download(
      url,
      path,
      cancelToken: _cancelToken,
      options: Options(headers: headers),
      onReceiveProgress: onProgress,
    );
    return File(path).length();
  }
}
```

Note: `_downloadFile`'s signature changed from taking a `DownloadRequest request` to taking the `onProgress` callback directly (the callback already closes over `request` where it's constructed in `_attempt`) — this keeps the watchdog's `receivedTotal`/`lastProgressAt` bookkeeping in one place instead of duplicating it. `HlsDownloader.download`'s `onProgress` parameter is passed the same callback unchanged for now (Task 8 fixes what values `HlsDownloader` actually passes to it).

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/data/download/download_worker_test.dart`
Expected: PASS — all 8 tests (5 original, with 1 replaced + 3 new) green.

- [ ] **Step 6: Commit**

```bash
git add lib/data/download/download_worker.dart test/data/download/download_worker_test.dart
git commit -m "feat(download): detect and recover from stalled downloads"
```
### Task 6a: Persist download progress to disk with throttling

**Files:**
- Modify: `lib/data/download/downloaded_episode_repository.dart` (append one method)
- Modify: `lib/data/download/download_worker.dart` (`_attempt`'s `onProgress` closure)
- Test: `test/data/download/downloaded_episode_repository_test.dart` (append one test)
- Test: `test/data/download/download_worker_test.dart` (append one test)

Task 1 added `receivedBytes`/`totalBytes`/`downloadedSegments`/`totalSegments`/`lastProgressAt` columns so progress survives navigation and app restarts (design doc section 2.1), but no task so far actually writes them — Task 6/8's `onProgress` closure only ever calls `_events.add(DownloadProgress(...))` (in-memory). This task closes that gap, throttled per the design doc's section 2.3 ("每 1 秒或进度变化 ≥1% 才写一次盘").

- [ ] **Step 1: Write the failing repository test**

Append to `test/data/download/downloaded_episode_repository_test.dart` (before the final closing `}`):

```dart

  test('updateProgress writes byte progress and bumps lastProgressAt', () async {
    var now = DateTime(2026, 9, 17, 10);
    repository = DownloadedEpisodeRepository(db, now: () => now);
    await repository.upsert(
      const DownloadedEpisodeWrite(
        sourceId: 'anime1',
        subjectId: 1,
        episodeKey: '1::anime1::1',
        subjectName: '测试番剧',
        episodeLabel: '1',
        localPath: '/tmp/one',
        episodeDir: '/tmp/one',
        format: 'mp4',
        status: DownloadStatus.downloading,
      ),
    );

    now = now.add(const Duration(seconds: 5));
    await repository.updateProgress(
      '1::anime1::1',
      receivedBytes: 512,
      totalBytes: 2048,
    );

    final row = await repository.findByKey('1::anime1::1');
    expect(row!.receivedBytes, 512);
    expect(row.totalBytes, 2048);
    expect(row.downloadedSegments, isNull);
    expect(row.totalSegments, isNull);
    expect(row.lastProgressAt, now);
  });

  test('updateProgress writes segment progress for HLS downloads', () async {
    await repository.upsert(
      const DownloadedEpisodeWrite(
        sourceId: 'anime1',
        subjectId: 1,
        episodeKey: '1::anime1::1',
        subjectName: '测试番剧',
        episodeLabel: '1',
        localPath: '/tmp/one',
        episodeDir: '/tmp/one',
        format: 'hls',
        status: DownloadStatus.downloading,
      ),
    );

    await repository.updateProgress(
      '1::anime1::1',
      downloadedSegments: 3,
      totalSegments: 12,
    );

    final row = await repository.findByKey('1::anime1::1');
    expect(row!.downloadedSegments, 3);
    expect(row.totalSegments, 12);
    expect(row.receivedBytes, 0);
    expect(row.totalBytes, isNull);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/download/downloaded_episode_repository_test.dart --plain-name "updateProgress"`
Expected: FAIL — `The method 'updateProgress' isn't defined for the type 'DownloadedEpisodeRepository'.` (compile error)

- [ ] **Step 3: Implement `updateProgress`**

In `lib/data/download/downloaded_episode_repository.dart`, add this method to `DownloadedEpisodeRepository`, right after `reconcileInterrupted` (added in Task 2):

```dart
  /// Persists live progress for a row already in [DownloadStatus.downloading]
  /// (written by [DownloadWorker._attempt]'s `onProgress` callback, throttled
  /// to at most once per second or once per whole-percent change — see the
  /// design doc's "进度写盘节流" decision). [receivedBytes]/[totalBytes] are
  /// used for mp4 downloads; [downloadedSegments]/[totalSegments] for HLS.
  /// Whichever pair is null for a given download format is simply left
  /// unwritten (both pairs stay in their schema default: `receivedBytes`
  /// defaults to `0`, the rest default to `null`).
  Future<void> updateProgress(
    String episodeKey, {
    int? receivedBytes,
    int? totalBytes,
    int? downloadedSegments,
    int? totalSegments,
  }) => (_db.update(
    _db.downloadedEpisodes,
  )..where((row) => row.episodeKey.equals(episodeKey))).write(
    DownloadedEpisodesCompanion(
      receivedBytes: receivedBytes == null
          ? const Value.absent()
          : Value(receivedBytes),
      totalBytes: Value(totalBytes),
      downloadedSegments: Value(downloadedSegments),
      totalSegments: Value(totalSegments),
      lastProgressAt: Value(_now()),
    ),
  );
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/data/download/downloaded_episode_repository_test.dart`
Expected: PASS

- [ ] **Step 5: Write the failing worker throttling test**

Append to `test/data/download/download_worker_test.dart` (before the final closing `}`):

```dart

  test('persists progress to disk at most once per second', () async {
    var now = DateTime(2026, 9, 17, 10);
    repository = DownloadedEpisodeRepository(database, now: () => now);
    final chunks = List.filled(2_000_000, 7);
    final worker = DownloadWorker(
      dio: _dio({'https://cdn.example/video.mp4': chunks}),
      sourceForId: (_) => _Source('anime1', const [
        _PlaybackSource('https://cdn.example/video.mp4'),
      ]),
      repository: repository,
      now: () => now,
    );
    final request = _request('anime1', 1, downloadRoot: root.path);

    worker.enqueue(request);
    await worker.whenIdle;

    final row = await repository.findByKey(request.episodeKey);
    // The fake adapter delivers the whole body in one synchronous chunk, so
    // `onProgress` fires at most a handful of times regardless of size --
    // this only proves a persisted value exists and matches the final
    // state, not that throttling suppressed any particular call. Task 6a's
    // throttling behavior itself (skipping writes within the 1s/1% window)
    // is exercised by the unit-level throttle-decision helper in Step 7
    // below, not by this integration-level fake-adapter test.
    expect(row!.receivedBytes, chunks.length);
  });
```

- [ ] **Step 6: Run test to verify it fails**

Run: `flutter test test/data/download/download_worker_test.dart --plain-name "persists progress to disk"`
Expected: FAIL — `DownloadWorker`'s constructor doesn't accept a `now` parameter yet, and no `receivedBytes` value has ever been written by the worker (it stays at the schema default `0`).

- [ ] **Step 7: Implement throttled progress persistence in `DownloadWorker`**

In `lib/data/download/download_worker.dart`, add a `now` constructor parameter (defaulting to `DateTime.now`, matching the pattern the repository itself already uses for test determinism). Keep the three duration parameters exactly as Task 6 defined them (`this.stallTimeout`/`this.noProgressTimeout`/`this.stallCheckInterval` -- public fields via constructor shorthand, unchanged); only add `now`, treated like the other injected dependencies (`_dio`/`_sourceForId`/`_repository`) with a private backing field:

```dart
  DownloadWorker({
    required Dio dio,
    required MediaSource Function(String sourceId) sourceForId,
    required DownloadedEpisodeRepository repository,
    this.stallTimeout = const Duration(seconds: 30),
    this.noProgressTimeout = const Duration(minutes: 2),
    this.stallCheckInterval = const Duration(seconds: 1),
    DateTime Function() now = DateTime.now,
  }) : _dio = dio,
       _sourceForId = sourceForId,
       _repository = repository,
       _now = now;
```

Add the matching field alongside the other injected-dependency fields:

```dart
  final DateTime Function() _now;
```

In `_attempt`, hoist a mutable `isHls` flag and throttle-tracking locals above the `onProgress` closure (which currently sits just before the `try` block), and rewrite the closure body to call `_repository.updateProgress` when the throttle window has elapsed:

```dart
    var isHls = false;
    DateTime? lastPersistedAt;
    var lastPersistedPercent = -1;

    void onProgress(int received, int total) {
      receivedTotal = received;
      lastProgressAt = _now();
      _events.add(DownloadProgress(request, received, total));

      final percent = total > 0 ? received * 100 ~/ total : -1;
      final dueByTime =
          lastPersistedAt == null ||
          lastProgressAt.difference(lastPersistedAt!) >=
              const Duration(seconds: 1);
      final dueByPercent = percent >= 0 && percent != lastPersistedPercent;
      if (!dueByTime && !dueByPercent) return;
      lastPersistedAt = lastProgressAt;
      lastPersistedPercent = percent;
      unawaited(
        _repository.updateProgress(
          request.episodeKey,
          receivedBytes: isHls ? null : received,
          totalBytes: isHls ? null : (total > 0 ? total : null),
          downloadedSegments: isHls ? received : null,
          totalSegments: isHls ? (total > 0 ? total : null) : null,
        ),
      );
    }
```

This replaces the version of `onProgress` written in Task 6 (which only did `receivedTotal = received; lastProgressAt = DateTime.now(); _events.add(...)`) — keep the rest of `_attempt` (the watchdog `Timer.periodic`, the `try`/`catch`/`finally` structure) unchanged, but change every remaining `DateTime.now()` call inside `_attempt` to `_now()` for consistency with the new injectable clock (the watchdog closure's `final now = DateTime.now();` and the `lastProgressAt`/`startedAt` initializers before it).

Finally, find the line Task 6 added:

```dart
      final isHls = Uri.parse(url).path.toLowerCase().endsWith('.m3u8');
```

and drop the `final` (the variable is now declared above the closure, so this becomes an assignment to the hoisted `isHls`):

```dart
      isHls = Uri.parse(url).path.toLowerCase().endsWith('.m3u8');
```

- [ ] **Step 8: Run to verify it passes**

Run: `flutter test test/data/download/download_worker_test.dart`
Expected: PASS (every existing test in the file plus the new one).

- [ ] **Step 9: Commit**

```bash
git add lib/data/download/downloaded_episode_repository.dart lib/data/download/download_worker.dart test/data/download/downloaded_episode_repository_test.dart test/data/download/download_worker_test.dart
git commit -m "feat(download): throttle progress writes to disk per design spec"
```
### Task 7: Validate HTTP responses before saving them as video

**Files:**
- Modify: `lib/data/download/download_worker.dart`
- Test: `test/data/download/download_worker_test.dart`

Anime1's CDN sometimes returns HTTP 200 with an HTML error page (expired
cookie / anti-leech redirect) instead of the actual video. Today
`_downloadFile` saves whatever bytes come back, marks the row
`completed`, and the user only discovers the file is broken when
playback fails later. This task makes `_downloadFile` validate the
response before accepting it.

- [ ] **Step 1: Add a small response wrapper the fake adapter can use, so tests can control status codes and headers**

Open `test/data/download/download_worker_test.dart`. Replace the
existing `_Adapter` class (the one with `responses` typed
`Map<String, Object>`) with a version that also understands a new
`_HttpResponse` wrapper, while still accepting the old bare
`List<int>`/`String` shorthand used by every existing test:

```dart
class _HttpResponse {
  const _HttpResponse({
    required this.statusCode,
    required this.body,
    this.headers = const {},
  });

  final int statusCode;
  final Object body; // List<int> or String
  final Map<String, String> headers;
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.responses, {this.waitForCancellation = false});

  final Map<String, Object> responses;
  final bool waitForCancellation;
  final started = Completer<void>();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (waitForCancellation) {
      started.complete();
      await cancelFuture;
      throw DioException.requestCancelled(
        requestOptions: options,
        reason: 'cancelled',
      );
    }
    final response = responses[options.uri.toString()];
    if (response is _HttpResponse) {
      final headers = Headers.fromMap(
        response.headers.map((key, value) => MapEntry(key, [value])),
      );
      if (response.body is List<int>) {
        return ResponseBody.fromBytes(
          Uint8List.fromList(response.body as List<int>),
          response.statusCode,
          headers: headers.map,
        );
      }
      return ResponseBody.fromString(
        response.body as String,
        response.statusCode,
        headers: headers.map,
      );
    }
    if (response is List<int>) {
      return ResponseBody.fromBytes(Uint8List.fromList(response), 200);
    }
    return ResponseBody.fromString(
      response as String? ?? '',
      response == null ? 404 : 200,
    );
  }

  @override
  void close({bool force = false}) {}
}
```

- [ ] **Step 2: Fix the three existing success-path fixtures so the new small-file check doesn't false-positive on them**

The new validation (Step 4) flags a completed download as suspicious
only when it is **both** smaller than 100KB **and** missing a
`content-length` response header. Three existing tests download tiny
fixture bytes (`[1]`, `[2]`, `[1, 2, 3]`) purely to keep the test fast
— they need an explicit `content-length` header so the new check
doesn't reject them.

In `'resolves the second request only after the first finishes'`,
change:

```dart
      dio: _dio({
        'https://cdn.example/first.mp4': [1],
        'https://cdn.example/second.mp4': [2],
      }),
```

to:

```dart
      dio: _dio({
        'https://cdn.example/first.mp4': const _HttpResponse(
          statusCode: 200,
          body: [1],
          headers: {'content-length': '1'},
        ),
        'https://cdn.example/second.mp4': const _HttpResponse(
          statusCode: 200,
          body: [2],
          headers: {'content-length': '1'},
        ),
      }),
```

In `'prefers an MP4 candidate for a Xifan request'`, change:

```dart
      dio: _dio({
        'https://cdn.example/video.mp4': [1, 2, 3],
      }),
```

to:

```dart
      dio: _dio({
        'https://cdn.example/video.mp4': const _HttpResponse(
          statusCode: 200,
          body: [1, 2, 3],
          headers: {'content-length': '3'},
        ),
      }),
```

`'cancelling an active request removes its files and record'` and
`'persists a failure message when downloading fails'` are unaffected
(the first never reaches a response body, the second's plain 404 will
now fail for the *new* status-code reason instead of a
`DioException`, but the assertion `record!.status ==
DownloadStatus.failed.name` and `record.errorMessage, isNotEmpty`
still hold either way — no change needed there).

- [ ] **Step 3: Add three new failing tests for the validation cases**

Add these three tests to the same file (after `'persists a failure
message when downloading fails'`):

```dart
  test('fails when the server returns a non-2xx status', () async {
    final worker = DownloadWorker(
      dio: _dio({
        'https://cdn.example/video.mp4': const _HttpResponse(
          statusCode: 403,
          body: 'forbidden',
        ),
      }),
      sourceForId: (_) => _Source('anime1', const [
        _PlaybackSource('https://cdn.example/video.mp4'),
      ]),
      repository: repository,
    );
    final request = _request('anime1', 1, downloadRoot: root.path);

    worker.enqueue(request);
    await worker.whenIdle;

    final record = await repository.findByKey(request.episodeKey);
    expect(record!.status, DownloadStatus.failed.name);
    expect(record.errorMessage, contains('403'));
  });

  test('fails when the server returns an HTML page instead of a video', () async {
    final worker = DownloadWorker(
      dio: _dio({
        'https://cdn.example/video.mp4': const _HttpResponse(
          statusCode: 200,
          body: '<html><body>login required</body></html>',
          headers: {'content-type': 'text/html; charset=utf-8'},
        ),
      }),
      sourceForId: (_) => _Source('anime1', const [
        _PlaybackSource('https://cdn.example/video.mp4'),
      ]),
      repository: repository,
    );
    final request = _request('anime1', 1, downloadRoot: root.path);

    worker.enqueue(request);
    await worker.whenIdle;

    final record = await repository.findByKey(request.episodeKey);
    expect(record!.status, DownloadStatus.failed.name);
    expect(record.errorMessage, contains('网页'));
  });

  test('fails when the response is suspiciously small with no content-length', () async {
    final worker = DownloadWorker(
      dio: _dio({
        'https://cdn.example/video.mp4': const _HttpResponse(
          statusCode: 200,
          body: [1, 2, 3],
        ),
      }),
      sourceForId: (_) => _Source('anime1', const [
        _PlaybackSource('https://cdn.example/video.mp4'),
      ]),
      repository: repository,
    );
    final request = _request('anime1', 1, downloadRoot: root.path);

    worker.enqueue(request);
    await worker.whenIdle;

    final record = await repository.findByKey(request.episodeKey);
    expect(record!.status, DownloadStatus.failed.name);
    expect(record.errorMessage, contains('过小'));
  });
```

- [ ] **Step 4: Run the tests to verify the three new ones fail**

Run: `flutter test test/data/download/download_worker_test.dart`
Expected: the three new tests FAIL (no validation exists yet — the
403/HTML/small-file responses are all accepted and marked
`completed`); the other tests still PASS.

- [ ] **Step 5: Implement the validation**

Open `lib/data/download/download_worker.dart`. Add the exception class
near the top of the file (after the event classes, before
`DownloadWorker`):

```dart
/// Thrown by [DownloadWorker._downloadFile] when the HTTP response is
/// well-formed (no network/cancel error) but clearly isn't the video it
/// claimed to be -- an expired-cookie/anti-leech HTML error page, a
/// non-2xx status, or a response too small to plausibly be a video.
/// Caught by the same generic failure path as any other download
/// error; [toString] is what ends up in the persisted `errorMessage`.
class DownloadValidationException implements Exception {
  const DownloadValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}
```

Replace `_downloadFile` with a version that sets
`validateStatus: (_) => true` (so dio hands back non-2xx responses
instead of throwing its own `DioException`) and checks status,
content-type, and final file size:

```dart
  Future<int> _downloadFile(
    String url,
    String path,
    Map<String, String> headers,
    void Function(int received, int total) onProgress,
  ) async {
    final response = await _dio.download(
      url,
      path,
      cancelToken: _cancelToken,
      options: Options(headers: headers, validateStatus: (_) => true),
      onReceiveProgress: onProgress,
    );

    if (response.statusCode == null ||
        response.statusCode! < 200 ||
        response.statusCode! >= 300) {
      throw DownloadValidationException(
        '下载失败（HTTP ${response.statusCode}）',
      );
    }

    final contentType = response.headers.value('content-type') ?? '';
    if (contentType.toLowerCase().contains('text/html')) {
      throw const DownloadValidationException(
        '源返回了网页而非视频（可能是防盗链或登录失效）',
      );
    }

    final size = await File(path).length();
    final hasContentLength =
        response.headers.value('content-length') != null;
    if (size < 100 * 1024 && !hasContentLength) {
      throw const DownloadValidationException('返回内容过小，可能不是视频');
    }

    return size;
  }
```

Update the two call sites of `_downloadFile` inside `_attempt` (added
in Task 6) to match the new signature -- they already pass an
`onProgress` closure instead of `request`, so no change is needed
there beyond what Task 6 already wrote; just confirm the call reads:

```dart
          : await _downloadFile(url, localPath, selected.headers, onProgress);
```

`DownloadValidationException` is not a `DioException`, so it falls
straight through to the existing generic `catch (error)` branch in
`_attempt`, which already does:

```dart
      await _repository.upsert(
        DownloadedEpisodeWrite(
          ...
          status: DownloadStatus.failed,
          errorMessage: error.toString(),
        ),
      );
      _events.add(DownloadFailed(request, error.toString()));
```

`error.toString()` on a `DownloadValidationException` returns its
`message` field (via the overridden `toString()`), so no changes are
needed in the catch block itself.

- [ ] **Step 6: Run the tests to verify they all pass**

Run: `flutter test test/data/download/download_worker_test.dart`
Expected: all tests PASS (8 total: the 5 original minus the one
replaced in Task 6, plus Task 6's stall tests, plus these 3 new
validation tests).

- [ ] **Step 7: Commit**

```bash
git add lib/data/download/download_worker.dart test/data/download/download_worker_test.dart
git commit -m "fix(download): validate HTTP response before saving as video"
```
### Task 8: Report real HLS segment progress and skip already-downloaded segments on retry

**Files:**
- Modify: `lib/data/download/hls_downloader.dart`
- Test: `test/data/download/hls_downloader_test.dart`

**Context:** `HlsDownloader.download()` currently calls `onProgress?.call(received, 0)` on every segment (`hls_downloader.dart:60`) — the total is hard-coded to `0`, so `DownloadQueueItem.progress` (`total <= 0 ? null : received / total`) always returns `null` for HLS downloads, and the manager's progress bar spins forever with no percentage. This task makes the total segment count known up front and reports real `(downloadedSegments, totalSegments)` pairs through the *same* `onProgress` callback signature already used by `DownloadWorker` (Task 6's `_attempt` builds one shared `onProgress` closure and passes it to both `HlsDownloader.download` and `_downloadFile` — the callback shape must not change). It also makes an interrupted HLS download resumable: on retry, any `segment_NNNN.ts` file that already exists on disk and is non-empty is skipped instead of re-fetched, matching the design spec's decision that "HLS resume-skip-existing-segments" is in scope while mp4 retries restart from scratch.

- [ ] **Step 1: Add a `fetchedUrls` tracking field to the test file's fake adapter**

Open `test/data/download/hls_downloader_test.dart` and update `_FakeAdapter` to record every URL it was asked to fetch, so a later test can assert a URL was *never* fetched (proving the segment was skipped):

```dart
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.responses);

  final Map<String, Object> responses;
  final cancelFutures = <Future<void>?>[];
  final fetchedUrls = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    cancelFutures.add(cancelFuture);
    fetchedUrls.add(options.uri.toString());
    final response = responses[options.uri.toString()];
    if (response is String) return ResponseBody.fromString(response, 200);
    if (response is List<int>) {
      return ResponseBody.fromBytes(Uint8List.fromList(response), 200);
    }
    return ResponseBody.fromString('', 404);
  }

  @override
  void close({bool force = false}) {}
}
```

(Only the `fetchedUrls` field and the `fetchedUrls.add(...)` line are new; `fakeDio(responses)` and everything else in the file stays as-is.)

- [ ] **Step 2: Write the two new failing tests**

Add these two tests to the same file (after the existing three tests, before the closing `}` of `main()`):

```dart
  test('reports true downloaded/total segment counts via onProgress', () async {
    final target = await Directory.systemTemp.createTemp('hls_test_');
    addTearDown(() => target.delete(recursive: true));
    final dio = fakeDio({
      'https://cdn.example/episode/index.m3u8':
          '#EXTM3U\n#EXTINF:1,\npart-a.ts\n#EXTINF:1,\npart-b.ts\n#EXT-X-ENDLIST\n',
      'https://cdn.example/episode/part-a.ts': [1, 2],
      'https://cdn.example/episode/part-b.ts': [3, 4],
    });
    final calls = <(int, int)>[];

    await HlsDownloader(dio).download(
      manifestUrl: Uri.parse('https://cdn.example/episode/index.m3u8'),
      targetDirectory: target,
      onProgress: (received, total) => calls.add((received, total)),
    );

    // The old bug reported (received, 0) on every call, making progress
    // permanently indeterminate. Every call must now carry the real,
    // stable total segment count (2), and the final call must report
    // both segments as downloaded.
    expect(calls, isNotEmpty);
    for (final call in calls) {
      expect(call.$2, 2, reason: 'total segment count must never be 0');
    }
    expect(calls.last, (2, 2));
  });

  test('skips a segment that already exists and is non-empty on retry', () async {
    final target = await Directory.systemTemp.createTemp('hls_test_');
    addTearDown(() => target.delete(recursive: true));
    // Simulate a previous, interrupted attempt: segment 0 already saved,
    // segment 1 never started.
    await File(
      p.join(target.path, 'segment_0000.ts'),
    ).writeAsBytes([9, 9], flush: true);
    final dio = fakeDio({
      'https://cdn.example/episode/index.m3u8':
          '#EXTM3U\n#EXTINF:1,\npart-a.ts\n#EXTINF:1,\npart-b.ts\n#EXT-X-ENDLIST\n',
      // Deliberately no entry for part-a.ts: if the downloader tries to
      // re-fetch it, the fake adapter falls through to its 404 branch and
      // dio.downloadUri throws, failing the test.
      'https://cdn.example/episode/part-b.ts': [3, 4],
    });

    await HlsDownloader(dio).download(
      manifestUrl: Uri.parse('https://cdn.example/episode/index.m3u8'),
      targetDirectory: target,
    );

    final adapter = dio.httpClientAdapter as _FakeAdapter;
    expect(
      adapter.fetchedUrls,
      isNot(contains('https://cdn.example/episode/part-a.ts')),
    );
    // The pre-existing segment's bytes must be untouched.
    expect(
      await File(p.join(target.path, 'segment_0000.ts')).readAsBytes(),
      [9, 9],
    );
    expect(
      await File(p.join(target.path, 'segment_0001.ts')).readAsBytes(),
      [3, 4],
    );
  });
```

Add the missing import at the top of the test file (it does not currently import `package:path/path.dart`):

```dart
import 'package:path/path.dart' as p;
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `flutter test test/data/download/hls_downloader_test.dart`
Expected: FAIL — the first new test fails because every recorded `total` is `0`, not `2`; the second new test fails because `part-a.ts` IS in `fetchedUrls` (the current implementation always re-downloads every segment) and/or because the pre-seeded bytes get overwritten.

- [ ] **Step 4: Implement real segment counting, progress reporting, and resume-skip**

Replace the body of `download()` in `lib/data/download/hls_downloader.dart` (everything from `final lines = playlistText.split(...)` through the `return HlsDownloadResult(...)` at the end) with:

```dart
    final lines = playlistText.split(RegExp(r'\r?\n'));
    final output = List<String>.from(lines);
    final segmentLineIndexes = <int>[];
    for (var index = 0; index < lines.length; index++) {
      if (lines[index].isNotEmpty && !lines[index].startsWith('#')) {
        segmentLineIndexes.add(index);
      }
    }

    final totalSegments = segmentLineIndexes.length;
    var downloadedSegments = 0;
    var totalBytes = 0;
    onProgress?.call(downloadedSegments, totalSegments);
    for (var index = 0; index < segmentLineIndexes.length; index++) {
      final segment = File(
        p.join(
          targetDirectory.path,
          'segment_${index.toString().padLeft(4, '0')}.ts',
        ),
      );
      final lineIndex = segmentLineIndexes[index];
      final alreadyDownloaded =
          segment.existsSync() && segment.lengthSync() > 0;
      if (!alreadyDownloaded) {
        await _dio.downloadUri(
          playlistUrl.resolve(lines[lineIndex]),
          segment.path,
          cancelToken: cancelToken,
          options: Options(headers: headers),
        );
      }
      totalBytes += await segment.length();
      output[lineIndex] = segment.uri.pathSegments.last;
      downloadedSegments++;
      onProgress?.call(downloadedSegments, totalSegments);
    }

    final playlist = File(p.join(targetDirectory.path, 'playlist.m3u8'));
    await playlist.writeAsString(output.join('\n'));
    return HlsDownloadResult(
      playlist,
      totalBytes + await playlist.length(),
    );
  }
```

The rest of the class (`_getText`, `_firstMasterVariant`, the `HlsDownloadResult` class, imports) is unchanged. The `onProgress` parameter's declared type (`void Function(int received, int total)?`) is also unchanged — only the *meaning* of the two ints shifts from "bytes downloaded so far / 0" to "segments downloaded so far / total segments", which is exactly what the design spec calls for (mp4 downloads report byte counts through the same callback shape in `download_worker.dart`'s `_downloadFile`; HLS downloads report segment counts — `DownloadQueueItem.progress`'s generic `received / total` formula works unchanged either way since both are just "done / total" ratios).

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/data/download/hls_downloader_test.dart`
Expected: PASS — all 5 tests (3 original + 2 new) pass.

- [ ] **Step 6: Run the full download test suite to check for regressions**

Run: `flutter test test/data/download/`
Expected: PASS — `download_worker_test.dart` (8 tests from Tasks 6-7) and `downloaded_episode_repository_test.dart` are unaffected since `HlsDownloader`'s public API (constructor, `download()` signature, `HlsDownloadResult`) did not change.

- [ ] **Step 7: Commit**

```bash
git add lib/data/download/hls_downloader.dart test/data/download/hls_downloader_test.dart
git commit -m "feat(download): report real HLS segment progress and resume partial downloads"
```
### Task 9: Add a cross-source "is this episode downloaded" provider

**Files:**
- Modify: `lib/data/download/downloaded_episode_repository.dart` (add a provider next to the existing `downloadedEpisodeByKeyProvider`)
- Test: `test/data/download/downloaded_episode_repository_test.dart` (append — this test exercises the provider via a `ProviderContainer`, so needs a new import)

**Context:** `downloadedEpisodeByKeyProvider(episodeKey)` (bottom of `downloaded_episode_repository.dart`) only matches an exact `subjectId::sourceId::title` key. After Task 4's automatic source selection ships, the episode a user is *watching* (e.g. from `mikan`) may not be the source it was actually *downloaded* from (e.g. `anime1`), so that exact-key lookup misses a file that is genuinely on disk. `findCompletedForEpisode` (Task 3) already does the source-agnostic query the repository needs; this task exposes it as a Riverpod provider so `PlayerScreen` and the new download-panel widgets can watch it directly instead of composing `ref.watch(...).future` boilerplate at every call site.

- [ ] **Step 1: Write the failing test**

Add this import to the top of `test/data/download/downloaded_episode_repository_test.dart` (alongside the existing imports):

```dart
import 'package:riverpod/riverpod.dart';
```

Append this test before the final closing `}`:

```dart

  test('downloadedEpisodeForEpisodeProvider ignores sourceId', () async {
    await repository.upsert(
      const DownloadedEpisodeWrite(
        sourceId: 'anime1',
        subjectId: 5,
        episodeKey: '5::anime1::第2话',
        subjectName: '测试番剧',
        episodeLabel: '第2话',
        localPath: '/tmp/two.mp4',
        format: 'mp4',
        status: DownloadStatus.completed,
      ),
    );
    final container = ProviderContainer(
      overrides: [
        downloadedEpisodeRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    final found = await container.read(
      downloadedEpisodeForEpisodeProvider(5, '第2话').future,
    );
    final missing = await container.read(
      downloadedEpisodeForEpisodeProvider(5, '第3话').future,
    );

    expect(found, isTrue);
    expect(missing, isFalse);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/download/downloaded_episode_repository_test.dart --plain-name "downloadedEpisodeForEpisodeProvider"`
Expected: FAIL — `Undefined name 'downloadedEpisodeForEpisodeProvider'.` (compile error)

- [ ] **Step 3: Implement**

Add this provider to `lib/data/download/downloaded_episode_repository.dart`, right after the existing `downloadedEpisodeByKeyProvider` at the end of the file:

```dart

@riverpod
Future<bool> downloadedEpisodeForEpisode(
  Ref ref,
  int subjectId,
  String episodeTitle,
) async =>
    await ref
        .watch(downloadedEpisodeRepositoryProvider)
        .findCompletedForEpisode(subjectId, episodeTitle) !=
    null;
```

- [ ] **Step 4: Regenerate Riverpod code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: regenerates `lib/data/download/downloaded_episode_repository.g.dart` with a new `downloadedEpisodeForEpisodeProvider` family provider (two positional args: `subjectId`, `episodeTitle`), no errors.

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/data/download/downloaded_episode_repository_test.dart`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/data/download/downloaded_episode_repository.dart lib/data/download/downloaded_episode_repository.g.dart test/data/download/downloaded_episode_repository_test.dart
git commit -m "feat(download): add cross-source download-status provider"
```
### Task 10: Make the download queue keep-alive, stop watching settings, add `retry()`

**Files:**
- Modify: `lib/domain/download/download_queue_controller.dart`
- Modify: `test/domain/download/download_queue_controller_test.dart`

**Context:** This is the core reliability fix for the "一直在转/很久都不动" complaint. Today `DownloadQueueController` is `autoDispose` with no `ref.keepAlive()` call, so navigating away from the player/download screen destroys the notifier and its in-memory progress map — the DB row still says `downloading` but nothing is left observing the worker's events (spec bug #1). `build()` also `watch`es both `downloadSettingsControllerProvider` and `mediaSourcesProvider`, so changing the download directory in Settings rebuilds the whole controller, constructs a *second* `DownloadWorker`, and silently abandons the first worker's in-flight queue (spec bug #2) — Task 5 already made `DownloadRequest` carry its own `downloadRoot` snapshot so `build()` no longer needs to watch the setting for that reason. This task: (1) adds `ref.keepAlive()` — the same idiom already used by `DownloadSettingsController.build()` and `ProxySettingsController.build()` in this codebase (no `@Riverpod(keepAlive: true)` annotation form exists anywhere in `lib/domain/**`); (2) changes `build()` to `ref.read` the download directory and media sources instead of `ref.watch`; (3) calls `reconcileInterrupted()` once, relying on keep-alive to guarantee it only runs once per app lifetime; (4) adds `retry(episodeKey)`, which re-resolves a preferred download source via Task 4's `resolvePreferredDownloadSource` (so a source that's gone offline since the original download gets automatically swapped rather than failing the same way again) and, if the resolved source differs from the one on the failed/interrupted row, deletes the stale record+files via Task 3's `deleteWithFiles` before re-enqueueing.

- [ ] **Step 1: Write the failing tests**

Open `test/domain/download/download_queue_controller_test.dart`. Add these imports (the file currently imports `download_worker.dart`, `local_database.dart`, `download_queue_controller.dart`, `media_registry.dart`, `media_source.dart`, `settings_storage.dart`, `dio`, `drift/native.dart`, `flutter_test`, `mocktail`, `riverpod`):

```dart
import 'package:animeko_flutter/domain/download/download_source_resolver.dart';
import 'package:animeko_flutter/domain/play/subject_episodes_controller.dart';
```

Add a second fake episode/source fixture near the top of the file (after the existing `_Episode` class and `request` constant):

```dart
class _StubMediaSource implements MediaSource {
  _StubMediaSource(this.id);

  @override
  final String id;

  @override
  String get displayName => id;

  @override
  Future<List<MediaCandidate>> search(String title, {int? subjectId}) =>
      throw UnimplementedError();

  @override
  Future<List<MediaEpisode>> listEpisodes(MediaCandidate candidate) =>
      throw UnimplementedError();

  @override
  Future<List<MediaPlaybackSource>> resolvePlayback(MediaEpisode episode) =>
      throw UnimplementedError();
}
```

Add these tests before the closing `}` of `main()`:

```dart

  test('the controller survives disposal of its last listener', () async {
    final subscription = container.listen(
      downloadQueueControllerProvider,
      (_, _) {},
    );
    await container.read(downloadQueueControllerProvider.future);
    final before = container.read(downloadQueueControllerProvider.notifier);

    // Simulate "the widget that was watching this provider got popped" --
    // without ref.keepAlive() in build(), this disposes the whole notifier.
    subscription.close();
    await container.pump();

    final after = container.read(downloadQueueControllerProvider.notifier);
    expect(after, same(before));
  });

  test('changing the download directory setting does not rebuild the '
      'controller or drop its state', () async {
    final subscription = container.listen(
      downloadQueueControllerProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);
    await container.read(downloadQueueControllerProvider.future);
    final controller = container.read(downloadQueueControllerProvider.notifier);
    controller.emit(const DownloadQueued(request));
    await container.pump();
    expect(
      container.read(downloadQueueControllerProvider).value,
      contains('1::xifan::1'),
    );

    // build() must not `watch` downloadSettingsControllerProvider -- if it
    // does, invalidating that provider rebuilds this one too and the
    // DownloadQueued entry above is lost.
    container.invalidate(downloadSettingsControllerProvider);
    await container.pump();

    expect(
      container.read(downloadQueueControllerProvider).notifier,
      same(controller),
    );
    expect(
      container.read(downloadQueueControllerProvider).value,
      contains('1::xifan::1'),
    );
  });

  test('build() reconciles interrupted rows from a previous run', () async {
    final repository = DownloadedEpisodeRepository(database);
    await repository.upsert(
      const DownloadedEpisodeWrite(
        sourceId: 'anime1',
        subjectId: 9,
        episodeKey: '9::anime1::1',
        subjectName: '测试番剧',
        episodeLabel: '1',
        localPath: '/tmp/nine',
        format: 'mp4',
        status: DownloadStatus.downloading,
      ),
    );

    final subscription = container.listen(
      downloadQueueControllerProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);
    await container.read(downloadQueueControllerProvider.future);

    final row = await repository.findByKey('9::anime1::1');
    expect(row!.status, DownloadStatus.interrupted.name);
  });

  test('retry re-resolves a preferred source and enqueues with it', () async {
    final repository = DownloadedEpisodeRepository(database);
    await repository.upsert(
      const DownloadedEpisodeWrite(
        sourceId: 'anime1',
        subjectId: 7,
        episodeKey: '7::anime1::第1集',
        subjectName: '测试番剧',
        episodeLabel: '第1集',
        localPath: '/tmp/seven',
        format: 'mp4',
        status: DownloadStatus.failed,
        errorMessage: 'boom',
      ),
    );
    final episode = MergedEpisode(
      episode: const _Episode('anime1', '第1集'),
      sourceId: 'anime1',
    );
    late DownloadQueueController controller;
    final testContainer = ProviderContainer(
      overrides: [
        settingsStorageProvider.overrideWith((ref) async => settingsStorage),
        mediaSourcesProvider.overrideWithValue([_StubMediaSource('anime1')]),
        downloadDioProvider.overrideWithValue(Dio()),
        downloadedEpisodeRepositoryProvider.overrideWithValue(repository),
        subjectEpisodesControllerProvider(
          subjectId: 7,
          subjectName: '测试番剧',
        ).overrideWith(() {
          controller = _RecordingController();
          return controller as _RecordingController
            ..episodesToReturn = [episode];
        }),
      ],
    );
    addTearDown(testContainer.dispose);
    final subscription = testContainer.listen(
      downloadQueueControllerProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);
    await testContainer.read(downloadQueueControllerProvider.future);
    final queueController = testContainer.read(
      downloadQueueControllerProvider.notifier,
    );

    await queueController.retry('7::anime1::第1集');

    expect((controller as _RecordingController).enqueued, [episode]);
  });
}

class _RecordingController extends DownloadQueueController {
  List<MergedEpisode> episodesToReturn = const [];
  final enqueued = <MergedEpisode>[];

  @override
  Future<Map<String, DownloadQueueItem>> build() async => const {};

  @override
  void enqueue({
    required int subjectId,
    required String subjectName,
    required MergedEpisode episode,
  }) => enqueued.add(episode);
}
```

**Note:** the `_RecordingController` above is actually overriding `subjectEpisodesControllerProvider`, not `downloadQueueControllerProvider` — it stands in for `SubjectEpisodesController` (which is also a `@riverpod class` extending an `_$SubjectEpisodesController` base). The class name/shape mismatch above is intentional shorthand for this plan step; when writing the real test, replace `_RecordingController extends DownloadQueueController` with `_StubEpisodesController extends SubjectEpisodesController` (matching the pattern already used in `test/ui/subject/subject_detail_screen_download_test.dart`'s `_StubEpisodesController`):

```dart
class _StubEpisodesController extends SubjectEpisodesController {
  _StubEpisodesController(this.episodes);

  final List<MergedEpisode> episodes;

  @override
  Future<List<MergedEpisode>> build({
    required int subjectId,
    required String subjectName,
  }) async => episodes;
}
```

and change the `retry` test's override to:

```dart
        subjectEpisodesControllerProvider(
          subjectId: 7,
          subjectName: '测试番剧',
        ).overrideWith(() => _StubEpisodesController([episode])),
```

then, after calling `retry`, assert against the *real* `downloadQueueControllerProvider`'s emitted state instead of a recording fake — since `retry` calls the controller's own `enqueue`, which drives the real `DownloadWorker`, and `_StubMediaSource.resolvePlayback` throws `UnimplementedError`, the simplest correct assertion is that the repository's old `anime1` record was deleted (same source resolved, so no cross-source deletion happens) and that a new `downloading` row appears for the same key:

```dart
    await queueController.retry('7::anime1::第1集');
    await testContainer.pump();

    final updated = await repository.findByKey('7::anime1::第1集');
    expect(updated!.status, isNot(DownloadStatus.failed.name));
```

Use this corrected version of the "retry" test in the actual file (drop the `_RecordingController` class entirely, add `_StubEpisodesController` instead, and use the `updated!.status, isNot(DownloadStatus.failed.name)` assertion).

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/domain/download/download_queue_controller_test.dart`
Expected: FAIL — `retry` is undefined (compile error) and the keep-alive/settings-rebuild tests fail their assertions (notifier gets rebuilt / state gets dropped) once the compile error is fixed enough to run them individually.

- [ ] **Step 3: Implement**

Replace `lib/domain/download/download_queue_controller.dart` in full:

```dart
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/download/download_worker.dart';
import '../../data/download/downloaded_episode_repository.dart';
import '../media/media_registry.dart';
import '../play/subject_episodes_controller.dart';
import '../settings/download_settings_controller.dart';
import 'download_source_resolver.dart';

part 'download_queue_controller.g.dart';

enum DownloadQueueStatus { queued, downloading, completed, failed }

class DownloadQueueItem {
  const DownloadQueueItem({
    required this.status,
    this.received = 0,
    this.total = 0,
    this.errorMessage,
    this.isStalled = false,
  });

  final DownloadQueueStatus status;
  final int received;
  final int total;
  final String? errorMessage;

  /// Transient UI flag set by a [DownloadStalled] event and cleared on the
  /// next [DownloadProgress]/[DownloadCompleted]/[DownloadFailed] for the
  /// same key. Never persisted -- see the design doc's decision to keep
  /// "stalled" purely in-memory.
  final bool isStalled;

  double? get progress => total <= 0 ? null : received / total;
}

@riverpod
Dio downloadDio(Ref ref) => Dio();

@riverpod
class DownloadQueueController extends _$DownloadQueueController {
  StreamSubscription<DownloadEvent>? _subscription;
  late DownloadWorker _worker;
  late DownloadedEpisodeRepository _repository;

  @override
  Future<Map<String, DownloadQueueItem>> build() async {
    // Keeps this controller (and its DownloadWorker) alive across
    // navigation -- without this, leaving the player/download panel
    // disposes the notifier while the worker's dio download keeps running
    // unobserved (see design doc bug #1).
    ref.keepAlive();
    final root = await ref.read(downloadSettingsControllerProvider.future);
    final sources = ref.read(mediaSourcesProvider);
    _repository = ref.read(downloadedEpisodeRepositoryProvider);
    _worker = DownloadWorker(
      dio: ref.read(downloadDioProvider),
      sourceForId: (id) => sources.firstWhere((source) => source.id == id),
      repository: _repository,
    );
    _subscription = _worker.events.listen(_onEvent);
    ref.onDispose(() {
      _subscription?.cancel();
    });
    // Rows still `downloading` at this point survived a crash/force-quit --
    // nothing is actually writing to them. keepAlive() above guarantees
    // build() runs exactly once per app lifetime, so this never re-runs on
    // a later rebuild.
    await _repository.reconcileInterrupted();
    return const {};
  }

  void enqueue({
    required int subjectId,
    required String subjectName,
    required MergedEpisode episode,
  }) async {
    final root = await ref.read(downloadSettingsControllerProvider.future);
    _worker.enqueue(
      DownloadRequest(
        subjectId: subjectId,
        subjectName: subjectName,
        sourceId: episode.sourceId,
        episode: episode.episode,
        episodeLabel: episode.title,
        downloadRoot: root,
      ),
    );
  }

  void cancel(String episodeKey) => _worker.cancel(episodeKey);

  /// Re-resolves a downloadable source for the episode behind [episodeKey]
  /// (which may no longer be the same source the original download used --
  /// see `download_source_resolver.dart`) and re-enqueues it. If the newly
  /// resolved source differs from the stale record's source, the stale
  /// record and its files are deleted first so a failed/half-downloaded
  /// attempt from an abandoned source doesn't linger on disk.
  ///
  /// Throws [StateError] if no downloadable source has this episode
  /// anymore (e.g. every source's episode list changed).
  Future<void> retry(String episodeKey) async {
    final row = await _repository.findByKey(episodeKey);
    if (row == null) return;
    final merged = await ref.read(
      subjectEpisodesControllerProvider(
        subjectId: row.subjectId,
        subjectName: row.subjectName,
      ).future,
    );
    final match = resolvePreferredDownloadSource(merged, row.episodeLabel);
    if (match == null) {
      throw StateError('源的剧集列表已变化，请在详情页重新选择这一集');
    }
    if (match.sourceId != row.sourceId) {
      await _repository.deleteWithFiles(row.episodeKey);
    }
    enqueue(
      subjectId: row.subjectId,
      subjectName: row.subjectName,
      episode: match,
    );
  }

  void emit(DownloadEvent event) => _onEvent(event);

  void _onEvent(DownloadEvent event) {
    final key = event.request.episodeKey;
    final current = state.value ?? const <String, DownloadQueueItem>{};
    if (event is DownloadCancelled) {
      state = AsyncData({...current}..remove(key));
    } else if (event is DownloadQueued) {
      state = AsyncData({
        ...current,
        key: const DownloadQueueItem(status: DownloadQueueStatus.queued),
      });
    } else if (event is DownloadStalled) {
      final existing = current[key];
      state = AsyncData({
        ...current,
        key: DownloadQueueItem(
          status: DownloadQueueStatus.downloading,
          received: existing?.received ?? 0,
          total: existing?.total ?? 0,
          isStalled: true,
        ),
      });
    } else if (event is DownloadProgress) {
      state = AsyncData({
        ...current,
        key: DownloadQueueItem(
          status: DownloadQueueStatus.downloading,
          received: event.received,
          total: event.total,
        ),
      });
    } else if (event is DownloadCompleted) {
      state = AsyncData({
        ...current,
        key: const DownloadQueueItem(status: DownloadQueueStatus.completed),
      });
    } else if (event is DownloadFailed) {
      state = AsyncData({
        ...current,
        key: DownloadQueueItem(
          status: DownloadQueueStatus.failed,
          errorMessage: event.message,
        ),
      });
    }
  }
}
```

Note: `enqueue` keeps its non-`Future` `void` return signature (fire-and-forget `async` body) — several widget tests (`test/ui/subject/subject_detail_screen_download_test.dart`'s `_RecordingDownloadQueueController`, `test/ui/download/download_manager_screen_test.dart`'s `_FakeQueueController`) override it with a synchronous `void enqueue(...)`, and changing the base signature to `Future<void>` would break those `@override`s.

- [ ] **Step 4: Regenerate Riverpod code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: regenerates `lib/domain/download/download_queue_controller.g.dart`; no new symbols beyond what already existed (`retry`/`emit`/`cancel` are plain instance methods, not providers, so codegen output is otherwise unchanged).

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/domain/download/download_queue_controller_test.dart`
Expected: PASS — all 5 tests (2 original + 3 new, using the corrected `retry` test from Step 1's note).

- [ ] **Step 6: Run the full test suite to check for regressions**

Run: `flutter test`
Expected: PASS. Watch specifically for `test/ui/download/download_manager_screen_test.dart` and `test/ui/subject/subject_detail_screen_download_test.dart` — both override `DownloadQueueController.enqueue` with a synchronous signature and should be unaffected, but this is the first task that touches `download_queue_controller.dart`'s public shape since those tests were written.

- [ ] **Step 7: Commit**

```bash
git add lib/domain/download/download_queue_controller.dart lib/domain/download/download_queue_controller.g.dart test/domain/download/download_queue_controller_test.dart
git commit -m "feat(download): keep the download queue alive and add retry()"
```
### Task 11: Add the shared `DownloadBadgeButton` widget

**Files:**
- Create: `lib/ui/download/download_badge_button.dart`
- Test: `test/ui/download/download_badge_button_test.dart`

This widget replaces the download button that used to live in
`PlayerTopBar` and will be reused in three places: the home screen
AppBar, the subject detail "选集" header row, and the player bottom
bar. It shows a download icon that reflects state, plus an optional
numeric badge showing how many episodes are currently downloading.

- [ ] **Step 1: Write the failing test**

Create `test/ui/download/download_badge_button_test.dart`:

```dart
import 'package:animeko_flutter/ui/download/download_badge_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildButton({
    DownloadButtonState state = DownloadButtonState.idle,
    int activeCount = 0,
    VoidCallback? onTap,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: DownloadBadgeButton(
          downloadState: state,
          activeCount: activeCount,
          onTap: onTap ?? () {},
        ),
      ),
    );
  }

  for (final (state, icon) in [
    (DownloadButtonState.idle, Icons.download_outlined),
    (DownloadButtonState.queued, Icons.schedule),
    (DownloadButtonState.downloading, Icons.downloading),
    (DownloadButtonState.completed, Icons.download_done),
  ]) {
    testWidgets('shows the correct icon for $state', (tester) async {
      await tester.pumpWidget(buildButton(state: state));

      expect(find.byIcon(icon), findsOneWidget);
    });
  }

  testWidgets('tapping the button invokes onTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(buildButton(onTap: () => tapped = true));

    await tester.tap(find.byType(IconButton));

    expect(tapped, isTrue);
  });

  testWidgets('shows a numeric badge when activeCount is greater than zero', (
    tester,
  ) async {
    await tester.pumpWidget(buildButton(activeCount: 3));

    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('hides the badge when activeCount is zero', (tester) async {
    await tester.pumpWidget(buildButton(activeCount: 0));

    expect(find.text('0'), findsNothing);
  });

  testWidgets('uses a custom tooltip when provided', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DownloadBadgeButton(
            downloadState: DownloadButtonState.idle,
            activeCount: 0,
            onTap: () {},
            tooltip: '下载管理',
          ),
        ),
      ),
    );

    expect(find.byTooltip('下载管理'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/ui/download/download_badge_button_test.dart`
Expected: FAIL with "Error: Couldn't resolve the package
'animeko_flutter' in
'package:animeko_flutter/ui/download/download_badge_button.dart'." (the
file doesn't exist yet)

- [ ] **Step 3: Write the implementation**

Create `lib/ui/download/download_badge_button.dart`:

```dart
// lib/ui/download/download_badge_button.dart
import 'package:flutter/material.dart';

/// The visual state of a single episode's download button. Moved here
/// from `player_top_bar.dart` -- this widget is now shared by the home
/// screen, the subject detail "选集" header, and the player bottom bar,
/// not just the player.
enum DownloadButtonState { idle, queued, downloading, completed }

/// A download icon button with an optional numeric badge showing how
/// many episodes are currently downloading (queued or in progress).
///
/// Purely prop-driven so it is testable without a real
/// [DownloadQueueController] or Riverpod [ProviderScope]. Callers own
/// computing [downloadState] and [activeCount] from their own context
/// (e.g. a single episode's state for the player, or a whole subject's
/// active-download count for the subject detail header).
class DownloadBadgeButton extends StatelessWidget {
  const DownloadBadgeButton({
    super.key,
    required this.downloadState,
    required this.activeCount,
    required this.onTap,
    this.iconColor,
    this.tooltip = '下载',
  });

  final DownloadButtonState downloadState;

  /// Number of episodes currently queued or downloading that this button
  /// represents. `0` hides the badge entirely.
  final int activeCount;
  final VoidCallback onTap;

  /// Overrides the icon's color. `null` uses the ambient icon theme --
  /// appropriate for a normal Material [AppBar]. The player bottom bar
  /// passes `Colors.white` explicitly to match its other icons, which
  /// are rendered over a dark video background rather than a themed
  /// surface.
  final Color? iconColor;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: Icon(_icon, color: iconColor),
          tooltip: tooltip,
          onPressed: onTap,
        ),
        if (activeCount > 0)
          Positioned(
            right: 4,
            top: 4,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 1,
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                child: Text(
                  '$activeCount',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  IconData get _icon => switch (downloadState) {
    DownloadButtonState.idle => Icons.download_outlined,
    DownloadButtonState.queued => Icons.schedule,
    DownloadButtonState.downloading => Icons.downloading,
    DownloadButtonState.completed => Icons.download_done,
  };
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/ui/download/download_badge_button_test.dart`
Expected: PASS (7 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/ui/download/download_badge_button.dart test/ui/download/download_badge_button_test.dart
git commit -m "feat(download): add shared download badge button widget"
```
### Task 12: Add the `EpisodeSelectionTab` widget

**Files:**
- Create: `lib/ui/download/episode_selection_tab.dart`
- Test: `test/ui/download/episode_selection_tab_test.dart`

This widget shows every episode of one subject, lets the user check the
ones they want, and enqueues them for download. It reuses
`resolveDownloadOptions` (Task 4) to know which source each episode can
be downloaded from, and the cross-source `downloadedEpisodeForEpisode`
provider (Task 9) to grey out episodes that already have a local file
from *any* source.

- [ ] **Step 1: Write the failing test**

```dart
// test/ui/download/episode_selection_tab_test.dart
import 'package:animeko_flutter/data/download/downloaded_episode_repository.dart';
import 'package:animeko_flutter/data/local_database.dart';
import 'package:animeko_flutter/domain/download/download_queue_controller.dart';
import 'package:animeko_flutter/domain/media/media_source.dart';
import 'package:animeko_flutter/domain/play/subject_episodes_controller.dart';
import 'package:animeko_flutter/ui/download/episode_selection_tab.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeEpisode implements MediaEpisode {
  const _FakeEpisode(this.sourceId, this.title);
  @override
  final String sourceId;
  @override
  final String title;
}

class _StubEpisodesController extends SubjectEpisodesController {
  _StubEpisodesController(this.episodes);
  final List<MergedEpisode> episodes;
  @override
  Future<List<MergedEpisode>> build({
    required int subjectId,
    required String subjectName,
  }) async => episodes;
}

class _RecordingQueueController extends DownloadQueueController {
  _RecordingQueueController([this.items = const {}]);
  final Map<String, DownloadQueueItem> items;
  final enqueued = <MergedEpisode>[];

  @override
  Future<Map<String, DownloadQueueItem>> build() async => items;

  @override
  void enqueue({
    required int subjectId,
    required String subjectName,
    required MergedEpisode episode,
  }) => enqueued.add(episode);
}

void main() {
  late AppDatabase database;
  late DownloadedEpisodeRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = DownloadedEpisodeRepository(database);
  });

  tearDown(() => database.close());

  const anime1Ep1 = MergedEpisode(
    episode: _FakeEpisode('anime1', '第1集'),
    sourceId: 'anime1',
  );
  const anime1Ep2 = MergedEpisode(
    episode: _FakeEpisode('anime1', '第2集'),
    sourceId: 'anime1',
  );
  const mikanEp3 = MergedEpisode(
    episode: _FakeEpisode('mikan', '第3集'),
    sourceId: 'mikan',
  );

  Future<_RecordingQueueController> pumpTab(
    WidgetTester tester, {
    List<MergedEpisode> episodes = const [
      anime1Ep1,
      anime1Ep2,
      mikanEp3,
    ],
    Map<String, DownloadQueueItem> queueItems = const {},
  }) async {
    late _RecordingQueueController queue;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          downloadedEpisodeRepositoryProvider.overrideWithValue(repository),
          subjectEpisodesControllerProvider(
            subjectId: 1,
            subjectName: '测试番剧',
          ).overrideWith(() => _StubEpisodesController(episodes)),
          downloadQueueControllerProvider.overrideWith(() {
            queue = _RecordingQueueController(queueItems);
            return queue;
          }),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: EpisodeSelectionTab(subjectId: 1, subjectName: '测试番剧'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return queue;
  }

  testWidgets('shows a source label and lets the user check a downloadable '
      'episode', (tester) async {
    await pumpTab(tester);

    expect(find.text('第1集'), findsOneWidget);
    expect(find.text('anime1'), findsWidgets);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    expect(find.text('已选 1 集'), findsOneWidget);
  });

  testWidgets('greys out an episode with no downloadable source', (
    tester,
  ) async {
    await pumpTab(tester);

    expect(find.text('无可下载来源'), findsOneWidget);
    final checkboxes = tester.widgetList<Checkbox>(find.byType(Checkbox));
    // The third row (mikan-only) has a disabled (null onChanged) checkbox.
    expect(checkboxes.last.onChanged, isNull);
  });

  testWidgets('greys out an already-downloaded episode as non-selectable', (
    tester,
  ) async {
    await repository.upsert(
      const DownloadedEpisodeWrite(
        sourceId: 'anime1',
        subjectId: 1,
        episodeKey: '1::anime1::第1集',
        subjectName: '测试番剧',
        episodeLabel: '第1集',
        localPath: '/tmp/a.mp4',
        episodeDir: '/tmp',
        format: 'mp4',
        status: DownloadStatus.completed,
      ),
    );

    await pumpTab(tester);

    expect(find.text('已下载'), findsOneWidget);
    final checkboxes = tester.widgetList<Checkbox>(find.byType(Checkbox));
    expect(checkboxes.first.onChanged, isNull);
  });

  testWidgets('greys out a currently-downloading episode with its percent', (
    tester,
  ) async {
    await pumpTab(
      tester,
      queueItems: {
        '1::anime1::第1集': const DownloadQueueItem(
          status: DownloadQueueStatus.downloading,
          received: 42,
          total: 100,
        ),
      },
    );

    expect(find.textContaining('下载中'), findsOneWidget);
    expect(find.textContaining('42'), findsOneWidget);
  });

  testWidgets('select all only checks downloadable, not-yet-downloaded '
      'episodes, then downloads them on tap', (tester) async {
    final queue = await pumpTab(tester);

    await tester.tap(find.text('全选'));
    await tester.pumpAndSettle();

    expect(find.text('已选 2 集'), findsOneWidget);

    await tester.tap(find.text('下载选中 2 集'));
    await tester.pumpAndSettle();

    expect(queue.enqueued.map((e) => e.title), ['第1集', '第2集']);
  });

  testWidgets('clear deselects everything', (tester) async {
    await pumpTab(tester);
    await tester.tap(find.text('全选'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('清空'));
    await tester.pumpAndSettle();

    expect(find.text('已选 0 集'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/ui/download/episode_selection_tab_test.dart`
Expected: FAIL — `episode_selection_tab.dart` does not exist.

- [ ] **Step 3: Write the implementation**

```dart
// lib/ui/download/episode_selection_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/download/downloaded_episode_repository.dart';
import '../../domain/download/download_queue_controller.dart';
import '../../domain/download/download_source_resolver.dart';
import '../../domain/play/subject_episodes_controller.dart';

/// One tab of [DownloadPanel]: every episode of one subject, with a
/// checkbox per downloadable episode and a primary "下载选中 N 集" action.
///
/// Reuses [resolveDownloadOptions] (the same function batch/player
/// auto-select-source logic uses) so the downloadable/source-label
/// decision is made in exactly one place.
class EpisodeSelectionTab extends ConsumerStatefulWidget {
  const EpisodeSelectionTab({
    super.key,
    required this.subjectId,
    required this.subjectName,
  });

  final int subjectId;
  final String subjectName;

  @override
  ConsumerState<EpisodeSelectionTab> createState() =>
      _EpisodeSelectionTabState();
}

class _EpisodeSelectionTabState extends ConsumerState<EpisodeSelectionTab> {
  final _selected = <String>{};

  @override
  Widget build(BuildContext context) {
    final episodesAsync = ref.watch(
      subjectEpisodesControllerProvider(
        subjectId: widget.subjectId,
        subjectName: widget.subjectName,
      ),
    );
    final queue = ref.watch(downloadQueueControllerProvider).value ?? const {};

    return episodesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('加载剧集列表失败：$error')),
      data: (merged) {
        final options = resolveDownloadOptions(merged);
        return Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: options.length,
                itemBuilder: (context, index) =>
                    _row(options[index], queue),
              ),
            ),
            _bottomBar(options, queue),
          ],
        );
      },
    );
  }

  Widget _row(EpisodeDownloadOption option, Map<String, DownloadQueueItem> queue) {
    final downloadedAsync = option.preferred == null
        ? null
        : ref.watch(
            downloadedEpisodeForEpisodeProvider(widget.subjectId, option.title),
          );
    final isDownloaded = downloadedAsync?.value ?? false;
    final queueItem = option.preferred == null
        ? null
        : queue['${widget.subjectId}::${option.preferred!.sourceId}::${option.title}'];
    final isDownloading = queueItem != null &&
        (queueItem.status == DownloadQueueStatus.queued ||
            queueItem.status == DownloadQueueStatus.downloading);
    final selectable = option.isDownloadable && !isDownloaded && !isDownloading;

    String? trailingText;
    if (isDownloaded) {
      trailingText = '已下载';
    } else if (isDownloading) {
      final percent = queueItem?.progress == null
          ? ''
          : ' ${(queueItem!.progress! * 100).round()}%';
      trailingText = '下载中$percent';
    } else if (!option.isDownloadable) {
      trailingText = '无可下载来源';
    }

    final sourceLabel = option.candidates.map((e) => e.sourceId).join(' / ');

    return CheckboxListTile(
      value: _selected.contains(option.title),
      onChanged: selectable
          ? (checked) => setState(() {
              if (checked ?? false) {
                _selected.add(option.title);
              } else {
                _selected.remove(option.title);
              }
            })
          : null,
      title: Text(option.title),
      subtitle: Row(
        children: [
          if (option.isDownloadable) Text(sourceLabel),
          if (trailingText != null) ...[
            if (option.isDownloadable) const Text(' · '),
            Text(
              trailingText,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _bottomBar(
    List<EpisodeDownloadOption> options,
    Map<String, DownloadQueueItem> queue,
  ) {
    bool selectableNow(EpisodeDownloadOption option) {
      if (!option.isDownloadable) return false;
      final queueItem =
          queue['${widget.subjectId}::${option.preferred!.sourceId}::${option.title}'];
      final isDownloading = queueItem != null &&
          (queueItem.status == DownloadQueueStatus.queued ||
              queueItem.status == DownloadQueueStatus.downloading);
      return !isDownloading;
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          TextButton(
            onPressed: () => setState(() {
              _selected
                ..clear()
                ..addAll(options.where(selectableNow).map((o) => o.title));
            }),
            child: const Text('全选'),
          ),
          TextButton(
            onPressed: () => setState(_selected.clear),
            child: const Text('清空'),
          ),
          const Spacer(),
          Text('已选 ${_selected.length} 集'),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: _selected.isEmpty
                ? null
                : () {
                    for (final option in options) {
                      if (_selected.contains(option.title) &&
                          option.preferred != null) {
                        ref
                            .read(downloadQueueControllerProvider.notifier)
                            .enqueue(
                              subjectId: widget.subjectId,
                              subjectName: widget.subjectName,
                              episode: option.preferred!,
                            );
                      }
                    }
                    setState(_selected.clear);
                  },
            child: Text('下载选中 ${_selected.length} 集'),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/ui/download/episode_selection_tab_test.dart`
Expected: PASS (6 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/ui/download/episode_selection_tab.dart test/ui/download/episode_selection_tab_test.dart
git commit -m "feat(download): add per-episode selection tab"
```
### Task 13: Add the `DownloadPanel` widget

**Files:**
- Create: `lib/ui/download/download_panel.dart`
- Test: `test/ui/download/download_panel_test.dart`

`DownloadPanel` is the single component shown from all three entry
points (home screen, subject detail page, player). When `subjectId` is
null (home screen / settings "下载管理" entry) it shows only the
"下载中 · 已下载(N)" list, covering every subject. When `subjectId` is
given (subject detail page / player) it also shows a "选集下载" tab
and filters the list tab to that subject only.

It is opened via `showModalBottomSheet`, not a route, so it can float
over the still-fullscreen player.

- [ ] **Step 1: Write the failing test**

```dart
// test/ui/download/download_panel_test.dart
import 'package:animeko_flutter/data/download/downloaded_episode_repository.dart';
import 'package:animeko_flutter/data/local_database.dart';
import 'package:animeko_flutter/domain/download/download_queue_controller.dart';
import 'package:animeko_flutter/domain/media/media_source.dart';
import 'package:animeko_flutter/domain/play/subject_episodes_controller.dart';
import 'package:animeko_flutter/ui/download/download_panel.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeEpisode implements MediaEpisode {
  const _FakeEpisode(this.sourceId, this.title);
  @override
  final String sourceId;
  @override
  final String title;
}

class _StubEpisodesController extends SubjectEpisodesController {
  _StubEpisodesController(this.episodes);
  final List<MergedEpisode> episodes;
  @override
  Future<List<MergedEpisode>> build({
    required int subjectId,
    required String subjectName,
  }) async => episodes;
}

class _FakeQueueController extends DownloadQueueController {
  @override
  Future<Map<String, DownloadQueueItem>> build() async => const {};
  @override
  void enqueue({
    required int subjectId,
    required String subjectName,
    required MergedEpisode episode,
  }) {}
}

void main() {
  late AppDatabase database;
  late DownloadedEpisodeRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = DownloadedEpisodeRepository(database);
  });

  tearDown(() => database.close());

  Future<void> pumpPanel(
    WidgetTester tester, {
    int? subjectId,
    List<MergedEpisode> episodes = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          downloadedEpisodeRepositoryProvider.overrideWithValue(repository),
          subjectEpisodesControllerProvider(
            subjectId: subjectId ?? 1,
            subjectName: '测试番剧',
          ).overrideWith(() => _StubEpisodesController(episodes)),
          downloadQueueControllerProvider.overrideWith(_FakeQueueController.new),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: DownloadPanel(
              subjectId: subjectId,
              subjectName: subjectId == null ? null : '测试番剧',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('hides the episode-selection tab when subjectId is null', (
    tester,
  ) async {
    await pumpPanel(tester);

    expect(find.text('选集下载'), findsNothing);
    expect(find.text('下载中 · 已下载(0)'), findsOneWidget);
  });

  testWidgets('shows both tabs when subjectId is given', (tester) async {
    const episode = MergedEpisode(
      episode: _FakeEpisode('anime1', '第1集'),
      sourceId: 'anime1',
    );
    await pumpPanel(tester, subjectId: 1, episodes: const [episode]);

    expect(find.text('选集下载'), findsOneWidget);
    expect(find.text('下载中 · 已下载(0)'), findsOneWidget);
  });

  testWidgets('list tab filters to the given subject only', (tester) async {
    await repository.upsert(
      const DownloadedEpisodeWrite(
        sourceId: 'anime1',
        subjectId: 1,
        episodeKey: '1::anime1::第1集',
        subjectName: '测试番剧',
        episodeLabel: '第1集',
        localPath: '/tmp/a.mp4',
        episodeDir: '/tmp',
        format: 'mp4',
        status: DownloadStatus.completed,
      ),
    );
    await repository.upsert(
      const DownloadedEpisodeWrite(
        sourceId: 'anime1',
        subjectId: 2,
        episodeKey: '2::anime1::第1集',
        subjectName: '另一部番剧',
        episodeLabel: '第1集',
        localPath: '/tmp/b.mp4',
        episodeDir: '/tmp',
        format: 'mp4',
        status: DownloadStatus.completed,
      ),
    );

    await pumpPanel(tester, subjectId: 1);
    await tester.tap(find.text('下载中 · 已下载(1)'));
    await tester.pumpAndSettle();

    expect(find.text('测试番剧'), findsOneWidget);
    expect(find.text('另一部番剧'), findsNothing);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/ui/download/download_panel_test.dart`
Expected: FAIL — `download_panel.dart` does not exist.

- [ ] **Step 3: Write the implementation**

```dart
// lib/ui/download/download_panel.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/download/downloaded_episode_repository.dart';
import '../../data/download/downloaded_episodes_provider.dart';
import '../../domain/download/download_queue_controller.dart';
import 'download_list_item.dart';
import 'episode_selection_tab.dart';

/// Merges persisted rows with live queue progress, filtered to
/// [subjectId] when given. Shared by [DownloadPanel]'s tab-count label
/// and its list tab so both read the same filtered set.
final _filteredDownloadsProvider = Provider.family<
  List<DownloadedEpisodeSummary>,
  int?
>((ref, subjectId) {
  final rows = ref.watch(downloadedEpisodesProvider).value ?? const [];
  if (subjectId == null) return rows;
  return rows.where((row) => row.subjectId == subjectId).toList();
});

/// The single download UI shown from the home screen, the subject
/// detail page's "选集" header, and the player's bottom bar -- only
/// the [subjectId] filter differs between call sites.
///
/// When [subjectId] is null, the "选集下载" tab is hidden (there is no
/// single subject's episode list to show) and the list tab covers every
/// subject. [subjectName] is required whenever [subjectId] is given,
/// since the episode-selection tab needs it to resolve the merged
/// episode list.
class DownloadPanel extends ConsumerWidget {
  const DownloadPanel({super.key, this.subjectId, this.subjectName})
    : assert(
        subjectId == null || subjectName != null,
        'subjectName is required whenever subjectId is given',
      );

  final int? subjectId;
  final String? subjectName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showEpisodeTab = subjectId != null;
    final count = ref.watch(_filteredDownloadsProvider(subjectId)).length;

    return DefaultTabController(
      length: showEpisodeTab ? 2 : 1,
      child: Column(
        children: [
          TabBar(
            tabs: [
              if (showEpisodeTab) const Tab(text: '选集下载'),
              Tab(text: '下载中 · 已下载($count)'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                if (showEpisodeTab)
                  EpisodeSelectionTab(
                    subjectId: subjectId!,
                    subjectName: subjectName!,
                  ),
                _ListTab(subjectId: subjectId),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ListTab extends ConsumerWidget {
  const _ListTab({required this.subjectId});

  final int? subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(_filteredDownloadsProvider(subjectId));
    final queueState = ref.watch(downloadQueueControllerProvider);
    final queue = switch (queueState) {
      AsyncData(:final value) => value,
      _ => const <String, DownloadQueueItem>{},
    };

    if (rows.isEmpty) return const Center(child: Text('暂无下载'));
    return ListView.builder(
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        return DownloadListItem(
          row: row,
          queueItem: queue[row.episodeKey],
          onCancel: () => ref
              .read(downloadQueueControllerProvider.notifier)
              .cancel(row.episodeKey),
          onRetry: () => ref
              .read(downloadQueueControllerProvider.notifier)
              .retry(row.episodeKey),
          onDelete: () => ref
              .read(downloadedEpisodeRepositoryProvider)
              .deleteWithFiles(row.episodeKey),
        );
      },
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/ui/download/download_panel_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/ui/download/download_panel.dart test/ui/download/download_panel_test.dart
git commit -m "feat(download): add shared download panel with tabs"
```
### Task 14: Slim `DownloadManagerScreen` down to a `DownloadPanel` wrapper

**Files:**
- Modify: `lib/ui/download/download_manager_screen.dart`
- Test: `test/ui/download/download_manager_screen_test.dart` (rewritten)

The old screen had its own list-merging, retry-by-refetch, and delete
logic. All of that now lives in `DownloadPanel`/`DownloadListItem`/
`DownloadQueueController.retry()`. `/downloads` (still the route
`SettingsScreen`'s "下载管理" tile pushes to) becomes a thin
`Scaffold` wrapper around `DownloadPanel(subjectId: null)`.

- [ ] **Step 1: Write the failing test**

Replace the entire contents of
`test/ui/download/download_manager_screen_test.dart` (the old file used
a hand-rolled `_FakeQueueController`/`_FakeEpisodesController`/
`pumpScreen()` trio to exercise progress/cancel/retry/delete directly —
all of that behavior is now covered by `download_panel_test.dart`
(Task 13) and `download_list_item_test.dart` (Task 15), so this file
only needs to prove the screen wires up `DownloadPanel` correctly):

```dart
// test/ui/download/download_manager_screen_test.dart
import 'package:animeko_flutter/data/download/downloaded_episode_repository.dart';
import 'package:animeko_flutter/domain/download/download_queue_controller.dart';
import 'package:animeko_flutter/domain/media/media_source.dart';
import 'package:animeko_flutter/domain/play/subject_episodes_controller.dart';
import 'package:animeko_flutter/data/local_database.dart';
import 'package:animeko_flutter/ui/download/download_manager_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeQueueController extends DownloadQueueController {
  @override
  Future<Map<String, DownloadQueueItem>> build() async => const {};
  @override
  void enqueue({
    required int subjectId,
    required String subjectName,
    required MergedEpisode episode,
  }) {}
}

void main() {
  late AppDatabase database;
  late DownloadedEpisodeRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = DownloadedEpisodeRepository(database);
  });

  tearDown(() => database.close());

  testWidgets('shows the 下载管理 title and an empty state, with no '
      'episode-selection tab (subjectId is null)', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          downloadedEpisodeRepositoryProvider.overrideWithValue(repository),
          downloadQueueControllerProvider.overrideWith(_FakeQueueController.new),
        ],
        child: const MaterialApp(home: DownloadManagerScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('下载管理'), findsOneWidget);
    expect(find.text('暂无下载'), findsOneWidget);
    expect(find.text('选集下载'), findsNothing);
  });

  testWidgets('lists a completed download across every subject', (
    tester,
  ) async {
    await repository.upsert(
      const DownloadedEpisodeWrite(
        sourceId: 'anime1',
        subjectId: 1,
        episodeKey: '1::anime1::第1集',
        subjectName: '测试番剧',
        episodeLabel: '第1集',
        localPath: '/tmp/a.mp4',
        episodeDir: '/tmp',
        format: 'mp4',
        status: DownloadStatus.completed,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          downloadedEpisodeRepositoryProvider.overrideWithValue(repository),
          downloadQueueControllerProvider.overrideWith(_FakeQueueController.new),
        ],
        child: const MaterialApp(home: DownloadManagerScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('测试番剧'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/ui/download/download_manager_screen_test.dart`
Expected: FAIL — `DownloadManagerScreen` still has its old body, which
does not render a `DownloadPanel`'s two-tab-when-null-shows-one
structure the same way (the old screen has no `TabBar` at all, so
`find.text('暂无下载')` may still pass but the overall structure/imports
will not compile against the new `DownloadPanel` usage expected below
until Step 3 is done — running now against the *old* implementation
file is the "confirm it fails for the right reason" checkpoint; if it
unexpectedly passes, that only means the empty-state text is
unchanged, which is fine — the second test still fails because the old
screen's retry/delete wiring differs and it does not accept a bare
`DownloadedEpisodeSummary` list this way. Proceed to Step 3 regardless).

- [ ] **Step 3: Replace the implementation**

```dart
// lib/ui/download/download_manager_screen.dart
import 'package:flutter/material.dart';

import 'download_panel.dart';

/// Thin wrapper around [DownloadPanel] for the `/downloads` route (still
/// reachable from Settings -> "下载管理"). `subjectId: null` means this
/// covers every subject's downloads, with no episode-selection tab.
class DownloadManagerScreen extends StatelessWidget {
  const DownloadManagerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('下载管理')),
      body: const DownloadPanel(subjectId: null),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/ui/download/download_manager_screen_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/ui/download/download_manager_screen.dart test/ui/download/download_manager_screen_test.dart
git commit -m "refactor(download): slim the download manager screen to a panel wrapper"
```
### Task 15: Update `DownloadListItem` for the new states, source label, and safe delete/retry

**Files:**
- Modify: `lib/ui/download/download_list_item.dart`
- Test: `test/ui/download/download_list_item_test.dart` (new)

Three changes, all driven by the design spec's bug fixes:

1. New visual states: a persisted `interrupted` row (crash/quit mid-download,
   reconciled by Task 2's `reconcileInterrupted()`) shows "已中断" with
   重试/删除 actions; a transient `isStalled` queue item (Task 6) shows
   "已停滞，正在重试" instead of the plain progress bar.
2. A source label (`row.sourceId`) is always shown, so the user can see
   which source a file came from (this is separate from the existing
   `'${row.sourceId} · ${row.episodeLabel}'` subtitle line, which stays).
3. `onDelete`'s caller now must call the repository's
   `deleteWithFiles(episodeKey)` (Task 3) instead of the old
   `DownloadListItem.deleteLocalPath(row.localPath)` static helper — the
   old helper is deleted from this file entirely, since it is the exact
   bug (`Directory(localPath).parent` deletes a sibling-episode
   directory for `failed`/`downloading` rows) that `episodeDir` fixes.
   `DownloadPanel` (Task 13) already calls the repository method
   directly; this task only needs `DownloadListItem` to keep exposing an
   `onDelete: Future<void> Function()` callback (unchanged signature) and
   stop defining `deleteLocalPath` itself.

- [ ] **Step 1: Write the failing test**

```dart
// test/ui/download/download_list_item_test.dart
import 'package:animeko_flutter/data/download/downloaded_episode_repository.dart';
import 'package:animeko_flutter/data/download/downloaded_episodes_provider.dart';
import 'package:animeko_flutter/domain/download/download_queue_controller.dart';
import 'package:animeko_flutter/ui/download/download_list_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

DownloadedEpisodeSummary _row({
  required String status,
  String? errorMessage,
}) => DownloadedEpisodeSummary(
  sourceId: 'anime1',
  subjectId: 1,
  episodeKey: '1::anime1::第1集',
  subjectName: '测试番剧',
  episodeLabel: '第1集',
  localPath: '/tmp/video.mp4',
  status: status,
  errorMessage: errorMessage,
);

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('shows the source label alongside the episode label', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        DownloadListItem(
          row: _row(status: DownloadStatus.completed.name),
          queueItem: null,
          onCancel: () {},
          onRetry: () {},
          onDelete: () async {},
        ),
      ),
    );

    expect(find.textContaining('anime1'), findsWidgets);
  });

  testWidgets('shows 已中断 with retry/delete for an interrupted row', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        DownloadListItem(
          row: _row(status: DownloadStatus.interrupted.name),
          queueItem: null,
          onCancel: () {},
          onRetry: () {},
          onDelete: () async {},
        ),
      ),
    );

    expect(find.text('已中断'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);
  });

  testWidgets('shows 已停滞，正在重试 for a stalled in-progress item', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        DownloadListItem(
          row: _row(status: DownloadStatus.downloading.name),
          queueItem: const DownloadQueueItem(
            status: DownloadQueueStatus.downloading,
            received: 10,
            total: 100,
            isStalled: true,
          ),
          onCancel: () {},
          onRetry: () {},
          onDelete: () async {},
        ),
      ),
    );

    expect(find.text('已停滞，正在重试'), findsOneWidget);
  });

  testWidgets('shows the error message verbatim for a failed row', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        DownloadListItem(
          row: _row(
            status: DownloadStatus.failed.name,
            errorMessage: '源返回了网页而非视频（可能是防盗链或登录失效）',
          ),
          queueItem: null,
          onCancel: () {},
          onRetry: () {},
          onDelete: () async {},
        ),
      ),
    );

    expect(find.text('源返回了网页而非视频（可能是防盗链或登录失效）'), findsOneWidget);
  });

  testWidgets('tapping 重试 on a failed row invokes onRetry', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      _wrap(
        DownloadListItem(
          row: _row(status: DownloadStatus.failed.name, errorMessage: 'x'),
          queueItem: null,
          onCancel: () {},
          onRetry: () => retried = true,
          onDelete: () async {},
        ),
      ),
    );

    await tester.tap(find.text('重试'));
    expect(retried, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/ui/download/download_list_item_test.dart`
Expected: FAIL — `DownloadStatus.interrupted` does not yet drive any UI
branch, `DownloadQueueItem.isStalled` is unused, no source label is
rendered separately.

- [ ] **Step 3: Update the implementation**

```dart
// lib/ui/download/download_list_item.dart
import 'package:flutter/material.dart';

import '../../data/download/downloaded_episode_repository.dart';
import '../../data/download/downloaded_episodes_provider.dart';
import '../../domain/download/download_queue_controller.dart';

class DownloadListItem extends StatelessWidget {
  const DownloadListItem({
    required this.row,
    required this.queueItem,
    required this.onCancel,
    required this.onRetry,
    required this.onDelete,
    super.key,
  });

  final DownloadedEpisodeSummary row;
  final DownloadQueueItem? queueItem;
  final VoidCallback onCancel;
  final VoidCallback onRetry;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final status = queueItem?.status;
    final isDownloading =
        status == DownloadQueueStatus.queued ||
        status == DownloadQueueStatus.downloading ||
        row.status == DownloadStatus.downloading.name;
    final isStalled = queueItem?.isStalled ?? false;
    final isInterrupted =
        status == null && row.status == DownloadStatus.interrupted.name;
    final isFailed =
        status == DownloadQueueStatus.failed ||
        row.status == DownloadStatus.failed.name;

    return ListTile(
      title: Text(row.subjectName),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${row.sourceId} · ${row.episodeLabel}'),
          if (isStalled)
            const Text('已停滞，正在重试')
          else if (isDownloading)
            LinearProgressIndicator(value: queueItem?.progress),
          if (isInterrupted) const Text('已中断'),
          if (isFailed)
            Text(queueItem?.errorMessage ?? row.errorMessage ?? '下载失败'),
        ],
      ),
      isThreeLine: isDownloading || isFailed || isInterrupted,
      trailing: isDownloading
          ? TextButton(onPressed: onCancel, child: const Text('取消'))
          : (isFailed || isInterrupted)
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(onPressed: onRetry, child: const Text('重试')),
                TextButton(onPressed: onDelete, child: const Text('删除')),
              ],
            )
          : TextButton(onPressed: onDelete, child: const Text('删除')),
    );
  }
}
```

Note: `DownloadStatus.interrupted` (Task 2) and
`DownloadQueueItem.isStalled` (Task 6) must already exist by the time
this task runs — both are added in earlier tasks in this same plan, so
no additional data-layer changes are needed here. The old
`static Future<void> deleteLocalPath(String localPath)` helper (and its
`dart:io` import) is deleted outright — nothing in the plan calls it
after Task 13/14 switch to `deleteWithFiles(episodeKey)`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/ui/download/download_list_item_test.dart`
Expected: PASS (5 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/ui/download/download_list_item.dart test/ui/download/download_list_item_test.dart
git commit -m "feat(download): show interrupted/stalled states and drop unsafe delete helper"
```
### Task 16: Wire the subject-detail badge button and remove the AppBar "全部下载" button

**Files:**
- Modify: `lib/ui/subject/subject_detail_screen.dart`
- Modify: `lib/ui/subject/subject_episodes_section.dart`
- Test: `test/ui/subject/subject_detail_screen_download_test.dart` (rewrite)

- [ ] **Step 1: Replace the batch-download test with badge-button assertions**

The existing test file queues every episode from the first HTTP source through an AppBar "全部下载" button -- exactly the all-or-nothing behavior the design eliminates. Replace the whole file:

```dart
// test/ui/subject/subject_detail_screen_download_test.dart
import 'package:animeko_flutter/data/subject/collection_type.dart';
import 'package:animeko_flutter/data/subject/review_models.dart';
import 'package:animeko_flutter/data/subject/subject_api.dart';
import 'package:animeko_flutter/data/subject/subject_models.dart';
import 'package:animeko_flutter/domain/download/download_queue_controller.dart';
import 'package:animeko_flutter/domain/media/media_source.dart';
import 'package:animeko_flutter/domain/play/subject_episodes_controller.dart';
import 'package:animeko_flutter/ui/subject/subject_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockSubjectApi extends Mock implements SubjectApi {}

class _FakeEpisode implements MediaEpisode {
  const _FakeEpisode(this.sourceId, this.title);

  @override
  final String sourceId;

  @override
  final String title;
}

class _StubEpisodesController extends SubjectEpisodesController {
  _StubEpisodesController(this.episodes);

  final List<MergedEpisode> episodes;

  @override
  Future<List<MergedEpisode>> build({
    required int subjectId,
    required String subjectName,
  }) async => episodes;
}

class _FakeQueueController extends DownloadQueueController {
  _FakeQueueController([this.items = const {}]);

  final Map<String, DownloadQueueItem> items;

  @override
  Future<Map<String, DownloadQueueItem>> build() async => items;

  @override
  void enqueue({
    required int subjectId,
    required String subjectName,
    required MergedEpisode episode,
  }) {}
}

SubjectDetail _detail() => SubjectDetail(
  id: 1,
  name: 'Original Name',
  nameCn: '中文名',
  summary: 'summary',
  airDate: '2026-01-01',
  tags: const [],
  collectionType: CollectionType.doing,
  selfRating: const SelfRating(score: 0, tags: [], isPrivate: false),
  episodes: const [],
);

Future<void> _pump(
  WidgetTester tester, {
  Map<String, DownloadQueueItem> queueItems = const {},
  List<MergedEpisode> episodes = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  final api = _MockSubjectApi();
  when(() => api.getSubject(1)).thenAnswer((_) async => _detail());
  when(() => api.getCharacters(1)).thenAnswer((_) async => []);
  when(
    () => api.getReviews(
      subjectId: any(named: 'subjectId'),
      offset: any(named: 'offset'),
      limit: any(named: 'limit'),
    ),
  ).thenAnswer((_) async => const PaginatedReviews(total: 0, items: []));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        subjectApiProvider.overrideWithValue(api),
        subjectEpisodesControllerProvider(
          subjectId: 1,
          subjectName: '中文名',
        ).overrideWith(() => _StubEpisodesController(episodes)),
        downloadQueueControllerProvider.overrideWith(
          () => _FakeQueueController(queueItems),
        ),
      ],
      child: const MaterialApp(
        home: SubjectDetailScreen(subjectId: 1, subjectName: '中文名'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the AppBar no longer has a 全部下载 button', (tester) async {
    await _pump(tester);

    expect(find.byTooltip('全部下载'), findsNothing);
  });

  testWidgets('the 选集 row shows a download badge button', (tester) async {
    final episodes = [
      const MergedEpisode(
        episode: _FakeEpisode('anime1', '第1集'),
        sourceId: 'anime1',
      ),
    ];

    await _pump(tester, episodes: episodes);

    expect(find.byTooltip('下载'), findsOneWidget);
  });

  testWidgets('tapping the badge button opens the download panel', (
    tester,
  ) async {
    final episodes = [
      const MergedEpisode(
        episode: _FakeEpisode('anime1', '第1集'),
        sourceId: 'anime1',
      ),
    ];

    await _pump(tester, episodes: episodes);
    await tester.tap(find.byTooltip('下载'));
    await tester.pumpAndSettle();

    expect(find.text('选集下载'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/ui/subject/subject_detail_screen_download_test.dart`
Expected: FAIL -- the AppBar still has the "全部下载" button and the 选集 section has no download badge/tooltip yet.

- [ ] **Step 3: Remove the AppBar batch-download button and its now-dead helper**

Edit `lib/ui/subject/subject_detail_screen.dart`: delete the top-level `firstDownloadableSourceEpisodes` function (lines 22-30) and replace the `AppBar` with a title-less, action-less bar:

```dart
    return Scaffold(
      appBar: AppBar(),
      body: detailAsync.when(
```

Remove the now-unused imports `download_queue_controller.dart` and `play/subject_episodes_controller.dart` from this file if nothing else in it references `MergedEpisode`/`downloadQueueControllerProvider` after the deletion (check with a quick grep of the file before removing an import).

- [ ] **Step 4: Add the badge button to the 选集 header row**

Edit `lib/ui/subject/subject_episodes_section.dart`. Add imports:

```dart
import '../../domain/download/download_queue_controller.dart';
import '../download/download_badge_button.dart';
import '../download/download_panel.dart';
```

Replace the header `Row` (currently `Text('选集') → Spacer() → conditional progress Text`) with a version that also watches the queue and inserts a `DownloadBadgeButton` between the spacer and the progress text:

```dart
              Row(
                children: [
                  Text('选集', style: theme.textTheme.titleSmall),
                  const Spacer(),
                  Consumer(
                    builder: (context, ref, _) {
                      final queue =
                          ref.watch(downloadQueueControllerProvider).value ??
                          const <String, DownloadQueueItem>{};
                      final activeCount = queue.keys
                          .where((key) => key.startsWith('$subjectId::'))
                          .length;
                      final state = activeCount > 0
                          ? DownloadButtonState.downloading
                          : DownloadButtonState.idle;
                      return DownloadBadgeButton(
                        downloadState: state,
                        activeCount: activeCount,
                        onTap: () => showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => SizedBox(
                            height:
                                MediaQuery.of(context).size.height * 0.8,
                            child: DownloadPanel(
                              subjectId: subjectId,
                              subjectName: subjectName,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  if (progress != null) const SizedBox(width: 8),
                  if (progress != null)
                    Text(
                      progress,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
```

- [ ] **Step 5: Run to verify it passes**

Run: `flutter test test/ui/subject/subject_detail_screen_download_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 6: Run the wider subject test suite for regressions**

Run: `flutter test test/ui/subject/`
Expected: PASS -- no other subject-detail test referenced the removed AppBar button or `firstDownloadableSourceEpisodes`.

- [ ] **Step 7: Commit**

```bash
git add lib/ui/subject/subject_detail_screen.dart lib/ui/subject/subject_episodes_section.dart test/ui/subject/subject_detail_screen_download_test.dart
git commit -m "feat(subject): replace batch-download AppBar button with a download panel badge"
```
### Task 17: Remove the download button from `PlayerTopBar`

**Files:**
- Modify: `lib/ui/player/player_top_bar.dart`
- Test: `test/ui/player/player_top_bar_test.dart`

- [ ] **Step 1: Replace the test file, dropping every download-related test**

The download button is moving to the bottom bar (Task 18) via the shared `DownloadBadgeButton` (Task 11, already tested in `test/ui/download/download_badge_button_test.dart`). Keep only the two tests unrelated to downloads, with their `onDownload`/`downloadState` args removed:

```dart
// test/ui/player/player_top_bar_test.dart
import 'package:animeko_flutter/ui/player/player_top_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the title and triggers callbacks on tap', (tester) async {
    var backTapped = false;
    var screenshotTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlayerTopBar(
            title: '测试标题',
            onBack: () => backTapped = true,
            onScreenshot: () => screenshotTapped = true,
          ),
        ),
      ),
    );

    expect(find.text('测试标题'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    expect(backTapped, isTrue);

    await tester.tap(find.byIcon(Icons.camera_alt));
    expect(screenshotTapped, isTrue);
  });

  testWidgets('ellipsizes a long title instead of overflowing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            child: PlayerTopBar(
              title: '一个非常非常非常非常非常非常长的剧集标题用于测试省略号效果',
              onBack: () {},
              onScreenshot: () {},
            ),
          ),
        ),
      ),
    );

    final textWidget = tester.widget<Text>(
      find.text('一个非常非常非常非常非常非常长的剧集标题用于测试省略号效果'),
    );
    expect(textWidget.maxLines, 1);
    expect(textWidget.overflow, TextOverflow.ellipsis);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/ui/player/player_top_bar_test.dart`
Expected: FAIL -- `PlayerTopBar` still requires `onDownload`/`downloadState` as named parameters, so the constructor calls above are missing required arguments.

- [ ] **Step 3: Trim `PlayerTopBar` to just back/title/screenshot**

Replace the whole file:

```dart
// lib/ui/player/player_top_bar.dart
import 'package:flutter/material.dart';

/// Custom top bar for [PlayerScreen], replacing the floating back button
/// that used to sit alone in the top-left corner.
///
/// The download button that used to live here has moved to
/// [PlayerBottomBar] (see the download UX overhaul design doc's decision
/// that neither the player's nor the subject page's download entry point
/// belongs in a top-right corner) -- [DownloadButtonState] now lives in
/// `download_badge_button.dart`, shared by the bottom bar, the subject
/// detail page, and the home screen.
///
/// Purely prop-driven so it is testable without a real [Player] or
/// Riverpod [ProviderScope].
class PlayerTopBar extends StatelessWidget {
  const PlayerTopBar({
    super.key,
    required this.title,
    required this.onBack,
    required this.onScreenshot,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback onScreenshot;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black45,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              tooltip: '返回',
              onPressed: onBack,
            ),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.camera_alt, color: Colors.white),
              tooltip: '截图',
              onPressed: onScreenshot,
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/ui/player/player_top_bar_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/ui/player/player_top_bar.dart test/ui/player/player_top_bar_test.dart
git commit -m "refactor(player): drop the top bar's download button"
```

Note: `lib/ui/player/player_screen.dart` still passes `onDownload`/`downloadState` to `PlayerTopBar(...)` at this point in the plan -- this will not compile until Task 19 updates that call site. This is expected; Task 19 must be completed before running `flutter analyze`/`flutter test` on the whole project again (the final verification in Task 21 is where that whole-project check happens).
### Task 18: Add the download button to `PlayerBottomBar`

**Files:**
- Modify: `lib/ui/player/player_bottom_bar.dart`
- Test: `test/ui/player/player_bottom_bar_test.dart`

Per the design doc's decision (user: "批量下载的按钮不要放在右上角,播放器的下载也不要放在右上角,放在下面播放里的bar里面"), the download button sits between the speed selector and the line-switch button, so it survives whether or not the controls are still visible on hover.

- [ ] **Step 1: Extend `buildBar` and add download-button tests**

Edit `test/ui/player/player_bottom_bar_test.dart`. Add the import and extend the `buildBar` helper with the new params:

```dart
import 'package:animeko_flutter/ui/download/download_badge_button.dart';
import 'package:animeko_flutter/ui/player/player_bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildBar({
    bool isPlaying = false,
    Duration position = Duration.zero,
    Duration duration = const Duration(minutes: 10),
    VoidCallback? onPlayPause,
    ValueChanged<Duration>? onSeek,
    double currentSpeed = 1.0,
    ValueChanged<double>? onSpeedSelected,
    DownloadButtonState downloadState = DownloadButtonState.idle,
    int downloadActiveCount = 0,
    VoidCallback? onDownloadTap,
    VoidCallback? onLineSwitch,
    VoidCallback? onDrawerToggle,
    VoidCallback? onFullscreenToggle,
    bool isFullscreen = false,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: PlayerBottomBar(
          isPlaying: isPlaying,
          position: position,
          duration: duration,
          onPlayPause: onPlayPause ?? () {},
          onSeek: onSeek ?? (_) {},
          currentSpeed: currentSpeed,
          speedOptions: const [0.5, 0.75, 1.0, 1.25, 1.5, 2.0],
          onSpeedSelected: onSpeedSelected ?? (_) {},
          downloadState: downloadState,
          downloadActiveCount: downloadActiveCount,
          onDownloadTap: onDownloadTap ?? () {},
          onLineSwitch: onLineSwitch,
          onDrawerToggle: onDrawerToggle ?? () {},
          onFullscreenToggle: onFullscreenToggle ?? () {},
          isFullscreen: isFullscreen,
        ),
      ),
    );
  }
```

Keep every existing test in the file unchanged below this point (they still compile against the extended helper's defaults), and append these new tests at the end, before the closing `}`:

```dart

  testWidgets('shows the download icon for the given state', (tester) async {
    await tester.pumpWidget(
      buildBar(downloadState: DownloadButtonState.downloading),
    );

    expect(find.byIcon(Icons.downloading), findsOneWidget);
  });

  testWidgets('tapping the download button invokes onDownloadTap', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(buildBar(onDownloadTap: () => tapped = true));

    await tester.tap(find.byTooltip('下载'));

    expect(tapped, isTrue);
  });

  testWidgets('shows the active-download badge count', (tester) async {
    await tester.pumpWidget(buildBar(downloadActiveCount: 2));

    expect(find.text('2'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/ui/player/player_bottom_bar_test.dart`
Expected: FAIL -- `PlayerBottomBar` does not yet accept `downloadState`/`downloadActiveCount`/`onDownloadTap`.

- [ ] **Step 3: Add the download button to the implementation**

Edit `lib/ui/player/player_bottom_bar.dart`. Add the import:

```dart
import '../download/download_badge_button.dart';
```

Add three new required constructor params, right after `onSpeedSelected` and before `onLineSwitch`:

```dart
    required this.onSpeedSelected,
    required this.downloadState,
    required this.downloadActiveCount,
    required this.onDownloadTap,
    this.onLineSwitch,
```

Add the matching fields, in the same position:

```dart
  final ValueChanged<double> onSpeedSelected;
  final DownloadButtonState downloadState;
  final int downloadActiveCount;
  final VoidCallback onDownloadTap;
  final VoidCallback? onLineSwitch;
```

Insert a `DownloadBadgeButton` between the speed `PopupMenuButton<double>` and the line-switch `IconButton(Icons.alt_route)`:

```dart
            ),
            DownloadBadgeButton(
              downloadState: downloadState,
              activeCount: downloadActiveCount,
              onTap: onDownloadTap,
              iconColor: Colors.white,
            ),
            IconButton(
              icon: const Icon(Icons.alt_route, color: Colors.white),
```

(The first `),` above closes the pre-existing `PopupMenuButton<double>(...)` call -- insert the new widget immediately after it and before the existing line-switch `IconButton`.)

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/ui/player/player_bottom_bar_test.dart`
Expected: PASS (all prior tests plus the 3 new ones).

- [ ] **Step 5: Commit**

```bash
git add lib/ui/player/player_bottom_bar.dart test/ui/player/player_bottom_bar_test.dart
git commit -m "feat(player): add a download button to the bottom control bar"
```

Note: as with Task 17, `lib/ui/player/player_screen.dart`'s `PlayerBottomBar(...)` call site does not yet pass the three new required params -- this will not compile until Task 19. Expected at this point in the plan; do not run whole-project `flutter analyze`/`flutter test` until Task 19 is done.
### Task 19: Wire the player screen to the new badge button and auto-select-source download

**Files:**
- Modify: `lib/ui/player/player_screen.dart`

This task has no new automated test of its own -- `PlayerScreen` has no existing dedicated test file wiring its download button (confirmed in earlier research: only the prop-driven `PlayerTopBar`/`PlayerBottomBar` widgets are unit-tested, not `PlayerScreen`'s own callback wiring). Correctness here is verified by Task 21's whole-project `flutter analyze`/`flutter test` run, which will fail to compile if any of these edits are wrong.

- [ ] **Step 1: Update the imports**

In `lib/ui/player/player_screen.dart`, the import block (lines 1-30) currently imports `download_queue_controller.dart` and `downloaded_episode_repository.dart`. Add the new resolver import and keep the rest:

```dart
import '../../data/download/downloaded_episode_repository.dart';
import '../../data/play/playback_position_storage.dart';
import '../../domain/download/download_queue_controller.dart';
import '../../domain/download/download_source_resolver.dart';
import '../../domain/media/media_registry.dart';
```

(Insert `download_source_resolver.dart` alphabetically between `download_queue_controller.dart` and `media_registry.dart`, matching the file's existing alphabetized import style.)

- [ ] **Step 2: Replace the download-state computation in `build()`**

Locate this block (originally lines 787-794):

```dart
    final downloadQueue = ref.watch(downloadQueueControllerProvider).value;
    final isDownloaded = ref.watch(
      downloadedEpisodeByKeyProvider(_positionKey),
    );
    final downloadState = _downloadButtonState(
      downloadQueue?[_positionKey]?.status,
      isDownloaded.value ?? false,
    );
```

Replace it with:

```dart
    final downloadQueue =
        ref.watch(downloadQueueControllerProvider).value ??
        const <String, DownloadQueueItem>{};
    final isDownloaded = ref.watch(
      downloadedEpisodeForEpisodeProvider(
        widget.subjectId,
        _currentEpisode.title,
      ),
    );
    final mergedEpisodes = ref
        .watch(
          subjectEpisodesControllerProvider(
            subjectId: widget.subjectId,
            subjectName: widget.subjectName,
          ),
        )
        .value;
    final preferredDownloadSource = mergedEpisodes == null
        ? null
        : resolvePreferredDownloadSource(
            mergedEpisodes,
            _currentEpisode.title,
          );
    final preferredEpisodeKey = preferredDownloadSource == null
        ? null
        : '${widget.subjectId}::${preferredDownloadSource.sourceId}::${preferredDownloadSource.title}';
    final downloadState = _downloadButtonState(
      preferredEpisodeKey == null
          ? null
          : downloadQueue[preferredEpisodeKey]?.status,
      isDownloaded.value ?? false,
    );
    final activeDownloadCount = downloadQueue.keys
        .where((key) => key.startsWith('${widget.subjectId}::'))
        .length;
```

This mirrors the subject detail page's badge-count logic from Task 16 (count queue keys by subject prefix) and replaces the old single-source `downloadedEpisodeByKeyProvider(_positionKey)` lookup with the cross-source `downloadedEpisodeForEpisodeProvider` from Task 9, so a download that auto-selected a different source than the one currently playing still shows as "已下载". `subjectEpisodesControllerProvider` was already imported and used elsewhere in this file (via `ref.read` in `_maybePlayNextEpisode`); this is its first `ref.watch` call, which is required so `build()` re-runs when the merged episode list becomes available.

- [ ] **Step 3: Remove the download params from the `PlayerTopBar(` call site**

Locate (originally lines 878-897):

```dart
                      child: PlayerTopBar(
                        title:
                            '${widget.subjectName} · ${_currentEpisode.title}',
                        onBack: () => Navigator.of(context).pop(),
                        onScreenshot: _takeScreenshot,
                        onDownload:
                            _isDownloadableSource(_currentEpisode.sourceId)
                            ? () => ref
                                  .read(
                                    downloadQueueControllerProvider.notifier,
                                  )
                                  .enqueue(
                                    subjectId: widget.subjectId,
                                    subjectName: widget.subjectName,
                                    episode: _currentEpisode,
                                  )
                            : null,
                        downloadState: downloadState,
                      ),
```

Replace with:

```dart
                      child: PlayerTopBar(
                        title:
                            '${widget.subjectName} · ${_currentEpisode.title}',
                        onBack: () => Navigator.of(context).pop(),
                        onScreenshot: _takeScreenshot,
                      ),
```

- [ ] **Step 4: Add the download args to the `PlayerBottomBar(` call site**

Locate the `onSpeedSelected:` callback inside the `PlayerBottomBar(` construction (originally lines 935-943):

```dart
                                        onSpeedSelected: (value) async {
                                           await _player.setRate(value);
                                           await ref
                                               .read(
                                                 playbackSpeedControllerProvider
                                                     .notifier,
                                               )
                                               .setPlaybackSpeed(value);
                                         },
                                        onLineSwitch:
```

Insert the three new required params between them:

```dart
                                        onSpeedSelected: (value) async {
                                           await _player.setRate(value);
                                           await ref
                                               .read(
                                                 playbackSpeedControllerProvider
                                                     .notifier,
                                               )
                                               .setPlaybackSpeed(value);
                                         },
                                        downloadState: downloadState,
                                        downloadActiveCount:
                                            activeDownloadCount,
                                        onDownloadTap: () {
                                          if (preferredDownloadSource ==
                                              null) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  '此集暂无可下载来源',
                                                ),
                                              ),
                                            );
                                            return;
                                          }
                                          ref
                                              .read(
                                                downloadQueueControllerProvider
                                                    .notifier,
                                              )
                                              .enqueue(
                                                subjectId: widget.subjectId,
                                                subjectName:
                                                    widget.subjectName,
                                                episode:
                                                    preferredDownloadSource,
                                              );
                                          if (preferredDownloadSource
                                                  .sourceId !=
                                              _currentEpisode.sourceId) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  '已加入下载队列（将从 ${preferredDownloadSource.sourceId} 下载）',
                                                ),
                                              ),
                                            );
                                          }
                                        },
                                        onLineSwitch:
```

This reuses the `ScaffoldMessenger.of(context).showSnackBar(...)` pattern already established in `_takeScreenshot()`. Per the design decision that a download button is only ever disabled when *no* source at all can serve the episode (not merely because the currently-playing source can't), the button always calls `onDownloadTap`; it shows a "此集暂无可下载来源" toast instead of enqueueing when `preferredDownloadSource` is null, and shows a "将从 X 下载" toast when the auto-selected source differs from what's currently playing (per the design's requirement that source auto-switching must always be visible to the user, never silent).

- [ ] **Step 5: Delete the now-unused top-level `_isDownloadableSource` function**

Delete these two lines (originally 986-987, immediately after `_downloadButtonState`):

```dart
bool _isDownloadableSource(String sourceId) =>
    sourceId == 'anime1' || sourceId == 'xifan';
```

`_downloadButtonState` (originally lines 972-984) is unchanged and still used exactly as before -- only its caller's arguments changed in Step 2.

- [ ] **Step 6: Commit**

```bash
git add lib/ui/player/player_screen.dart
git commit -m "feat(player): auto-select a downloadable source for the download button"
```

Note: this is expected to be the point where `PlayerTopBar`/`PlayerBottomBar`'s call sites finally compile again after Tasks 17/18 changed their constructors. Do not run the whole-project `flutter analyze`/`flutter test` as a completion check for this task alone -- Task 21 does that once every remaining task (20) is also done.
### Task 20: Add a download icon with a global badge to the home screen

**Files:**
- Modify: `lib/ui/home/home_screen.dart`
- Test: `test/ui/home/home_screen_download_test.dart` (new)

Per the design decision (batch 5, "全局下载页"), the `/downloads` navigation entry stays in Settings, but a home-screen icon becomes the primary discoverable entry point, with a badge showing the total number of episodes currently downloading across every subject. This must NOT modify the shared `buildStandardActions()` helper in `lib/ui/common/app_action_bar.dart` (18 lines, also used by Search and Schedule) -- the new icon is appended locally in `home_screen.dart` only.

- [ ] **Step 1: Write the failing test**

Create `test/ui/home/home_screen_download_test.dart`:

```dart
import 'package:animeko_flutter/domain/download/download_queue_controller.dart';
import 'package:animeko_flutter/domain/home/home_recommendations_controller.dart';
import 'package:animeko_flutter/domain/home/trending_controller.dart';
import 'package:animeko_flutter/domain/subject_card.dart';
import 'package:animeko_flutter/ui/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeQueueController extends DownloadQueueController {
  _FakeQueueController(this.items);

  final Map<String, DownloadQueueItem> items;

  @override
  Future<Map<String, DownloadQueueItem>> build() async => items;
}

const _emptyPage = HomeRecommendationsPage(items: [], hasMore: false);

Future<void> _pump(
  WidgetTester tester,
  Map<String, DownloadQueueItem> queueItems,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        trendingProvider.overrideWith((ref) async => const <SubjectCard>[]),
        homeRecommendationsControllerProvider.overrideWith(
          () => _StubRecommendationsController(),
        ),
        downloadQueueControllerProvider.overrideWith(
          () => _FakeQueueController(queueItems),
        ),
      ],
      child: const MaterialApp(home: HomeScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

class _StubRecommendationsController extends HomeRecommendationsController {
  @override
  Future<HomeRecommendationsPage> build() async => _emptyPage;
}

void main() {
  testWidgets('shows a download icon with no badge when nothing is active', (
    tester,
  ) async {
    await _pump(tester, const {});

    expect(find.byTooltip('下载'), findsOneWidget);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('shows the total active-download count across all subjects', (
    tester,
  ) async {
    await _pump(tester, const {
      '1::anime1::1': DownloadQueueItem(status: DownloadQueueStatus.downloading),
      '1::anime1::2': DownloadQueueItem(status: DownloadQueueStatus.queued),
      '2::xifan::1': DownloadQueueItem(status: DownloadQueueStatus.downloading),
    });

    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('tapping the download icon opens the download panel', (
    tester,
  ) async {
    await _pump(tester, const {});

    await tester.tap(find.byTooltip('下载'));
    await tester.pumpAndSettle();

    expect(find.text('下载中 · 已下载(0)'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/ui/home/home_screen_download_test.dart`
Expected: FAIL -- there is no `find.byTooltip('下载')` on the home screen yet.

- [ ] **Step 3: Add the download badge button to the home AppBar actions**

Edit `lib/ui/home/home_screen.dart`. Add imports:

```dart
import '../../domain/download/download_queue_controller.dart';
import '../download/download_badge_button.dart';
import '../download/download_panel.dart';
```

Replace the `_CollapsingHomeAppBar` sliver construction (originally line 72):

```dart
            _CollapsingHomeAppBar(actions: buildStandardActions(context)),
```

with:

```dart
            _CollapsingHomeAppBar(
              actions: [
                ...buildStandardActions(context),
                Builder(
                  builder: (context) {
                    final queue =
                        ref.watch(downloadQueueControllerProvider).value ??
                        const <String, DownloadQueueItem>{};
                    return DownloadBadgeButton(
                      downloadState: queue.isEmpty
                          ? DownloadButtonState.idle
                          : DownloadButtonState.downloading,
                      activeCount: queue.length,
                      onTap: () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => SizedBox(
                          height: MediaQuery.of(context).size.height * 0.8,
                          child: const DownloadPanel(subjectId: null),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
```

`_HomeScreenState` already extends `ConsumerState<HomeScreen>`, so `ref` is directly available inside `build()` without an extra `Consumer` wrapper; the inner `Builder` only exists to obtain a `context` with a `Navigator`/`MediaQuery` scoped under this sliver for `showModalBottomSheet`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/ui/home/home_screen_download_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Run the wider home-screen test suite for regressions**

Run: `flutter test test/ui/home/`
Expected: PASS -- no other home-screen test asserted an exact `actions:` list length that this change would break (confirm by reading test output; if any test does assert an exact count, update it to account for the one new action).

- [ ] **Step 6: Commit**

```bash
git add lib/ui/home/home_screen.dart test/ui/home/home_screen_download_test.dart
git commit -m "feat(home): add a download icon with a global active-download badge"
```
### Task 21: Final verification and plan self-review

**Files:** none (verification only)

- [ ] **Step 1: Regenerate all code-generated files**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: Succeeds with no conflicts. This must pick up every `@riverpod` addition/change made across Tasks 1-20 (`downloadedEpisodeForEpisode` from Task 9, the `DownloadQueueController` rebuild from Task 10, and the schema/table changes from Task 1) into their matching `.g.dart` files.

- [ ] **Step 2: Run static analysis**

Run: `flutter analyze`
Expected: No errors. (Pre-existing info-level lints elsewhere in the codebase are acceptable per this repo's own `AGENTS.md` -- only new errors introduced by this plan's changes are a blocker.)

If this reports errors, work through them file by file rather than guessing -- the most likely sources given this plan's scope are: a stale positional/named argument at one of the `PlayerTopBar(`/`PlayerBottomBar(`/`DownloadBadgeButton(` call sites (Tasks 16-20), an unused import left behind after deleting `firstDownloadableSourceEpisodes`/`_isDownloadableSource` (Tasks 16, 19), or a mismatched type between `DownloadQueueItem.isStalled` (added in Task 6) and its read site in `DownloadListItem` (Task 15).

- [ ] **Step 3: Run the full test suite**

Run: `flutter test`
Expected: All tests pass, including every new/modified download-related test file from Tasks 1-20: `local_database_test.dart`, `download_source_resolver_test.dart`, `download_worker_test.dart`, `hls_downloader_test.dart`, `downloaded_episode_repository_test.dart`, `download_queue_controller_test.dart`, `download_badge_button_test.dart`, `episode_selection_tab_test.dart`, `download_panel_test.dart`, `download_manager_screen_test.dart`, `download_list_item_test.dart`, `subject_detail_screen_download_test.dart`, `player_top_bar_test.dart`, `player_bottom_bar_test.dart`, `home_screen_download_test.dart`, plus the full pre-existing suite (~380+ tests total across the repo).

If any test fails, fix the underlying code (not the test) unless the failure reveals the test itself made an incorrect assumption introduced earlier in this same plan -- in which case fix the test and re-run.

- [ ] **Step 4: Self-review -- spec coverage**

Open `docs/superpowers/specs/2026-09-17-download-ux-overhaul-design.md` and walk each of its five design sections, confirming a task in this plan implements it:

- **Section 1 (组件架构)** -- `DownloadPanel`/`EpisodeSelectionTab`/`DownloadBadgeButton` (Tasks 11-13), `/downloads` slimmed to a `DownloadPanel` wrapper (Task 14), three shared entry points wired (Tasks 16, 19, 20).
- **Section 2 (数据层改动)** -- schema v4→v5 with 6 new columns (Task 1), `DownloadStatus.interrupted`+`reconcileInterrupted()` (Task 2), throttled progress persistence to `receivedBytes`/`totalBytes`/`downloadedSegments`/`totalSegments`/`lastProgressAt` at most once per second or once per whole-percent change (Task 6a, `DownloadedEpisodeRepository.updateProgress` + `DownloadWorker._attempt`'s `onProgress` closure).
- **Section 3 (队列与worker改动)** -- keepAlive + snapshot-per-request download root (Tasks 5, 10), `retry()` re-resolving source (Task 10), stall/timeout detection with one auto-retry (Task 6), real HLS progress + resume-skip (Task 8), `enqueue()` no longer throwing (Task 6).
- **Section 4 (自动逐集择源策略)** -- `download_source_resolver.dart` (Task 4), used by `EpisodeSelectionTab` (Task 12), the player's auto-switch (Task 19), and `retry()` (Task 10).
- **Section 5 (错误处理与已知限制)** -- `episodeDir`-based deletion fixing the sibling-directory-deletion bug (Tasks 1, 3, 15), HTTP response validation (Task 7); the spec's item about `downloadDioProvider` needing no proxy code change is correctly a no-op in this plan (confirmed via `installProxyHttpOverrides` already covering every `Dio` globally -- no task needed).

If any other gap is found (unlikely, given the above walk-through, but re-check with fresh eyes), implement it now with the same TDD step structure as every other task in this plan, before proceeding to Step 5.

- [ ] **Step 5: Self-review -- placeholder scan**

Run:
```bash
grep -rniE "TBD|TODO|placeholder|implement later|fill in|add appropriate|handle edge cases|similar to task" docs/superpowers/plans/2026-09-17-download-ux-overhaul.md
```
Expected: no matches. If any are found, open the flagged task and replace the vague text with the actual concrete content it should have contained (do not merely delete the flagged phrase).

- [ ] **Step 6: Self-review -- type/signature consistency**

Confirm each of the following names is spelled and typed identically at every definition and call site across the whole plan:

- `DownloadBadgeButton({required downloadState, required activeCount, required onTap, iconColor, tooltip})` -- defined Task 11; called from Task 16 (subject detail), Task 18 (`PlayerBottomBar`'s own constructor forwarding these as `downloadState`/`downloadActiveCount`/`onDownloadTap` -- note the *outer* `PlayerBottomBar` params are named `downloadActiveCount`/`onDownloadTap`, which Task 18's `build()` maps onto `DownloadBadgeButton`'s `activeCount`/`onTap` -- confirm this mapping was not swapped), Task 19 (`PlayerScreen`'s `PlayerBottomBar(...)` call site), Task 20 (home screen).
- `DownloadQueueItem` gains `isStalled` in Task 6; read at Task 15 (`DownloadListItem`) and Task 19 (implicitly, via `downloadQueue[key]?.status`, which does NOT read `isStalled` -- confirm this is intentional: the player bottom bar's `downloadState` only reflects `status`, not `isStalled`, since `DownloadBadgeButton` has no stalled-specific icon; only `DownloadListItem`'s row view surfaces the "已停滞" text).
- `resolvePreferredDownloadSource(merged, title)` / `resolveDownloadOptions(merged)` -- defined Task 4; called from Task 12 (`EpisodeSelectionTab`), Task 10 (`retry()`), Task 19 (`PlayerScreen`).
- `downloadedEpisodeForEpisodeProvider(subjectId, episodeTitle)` -- defined Task 9; called from Task 12, Task 19.
- `deleteWithFiles(episodeKey)` -- defined Task 3; called from Task 13 (`DownloadPanel`'s `_ListTab`), Task 15 (no longer calls the deleted `DownloadListItem.deleteLocalPath`).
- `DownloadQueueController.retry(episodeKey)` -- defined Task 10; called from Task 13, Task 15.
- `DownloadedEpisodeRepository.updateProgress(episodeKey, {receivedBytes, totalBytes, downloadedSegments, totalSegments})` -- defined Task 6a; called only from `DownloadWorker._attempt`'s `onProgress` closure (also Task 6a) -- confirm no other call site was left calling the old unthrottled pattern.

Fix any mismatch found inline; no need to re-run the whole review after a fix, just correct it and move on.

- [ ] **Step 7: Final commit**

If Step 4 or Steps 5-6 required any fixes, commit them now with an appropriately scoped message (e.g. `fix(player): correct swapped download badge button params`), following the same `type(scope): message` convention as every other task.

If no fixes were needed, this task requires no commit of its own -- Task 20's commit remains the last commit in the plan.
