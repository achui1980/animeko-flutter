# 收藏/改状态时本地记录封面图 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When the user collects/changes a subject's collection status on the detail page while an `imageUrl` is known (arrived via navigation from Home/Search/Schedule), persist `subjectId -> imageUrl` to a local SQLite table, and have the "My Collection" list read that table to show covers that the `GET /v2/subjects/list` API itself never returns.

**Architecture:** New Drift table `SubjectImageCache` (own migration, `schemaVersion` 1→2) + a new `SubjectImageCacheRepository` (upsert `save`, batch `getFor`) behind a `keepAlive` `AppDatabase` provider. `SubjectCollectionController.setCollectionType` gains an optional `imageUrl` param and best-effort writes to the repository after a successful remote update. `MyCollectionsController` merges cached URLs into a new `MyCollectionsPage.imageUrls` map; `SubjectCard.fromMyCollectionSubject` and `my_collection_screen.dart` consume that map to populate `imageUrl` for rendering. See design doc: `docs/superpowers/specs/2026-09-08-collection-image-cache-design.md`.

**Tech Stack:** Flutter, Riverpod 3.x (`riverpod_annotation` 4.0.2, codegen via `riverpod_generator`), Drift 2.31.0 (SQLite), `mocktail` for test doubles, `flutter_test`.

---

## Task 1: `SubjectImageCache` table, schema migration, and `AppDatabase` provider

**Files:**
- Modify: `lib/data/local_database.dart`
- Test: `test/data/local_database_test.dart`

- [ ] **Step 1: Add the `SubjectImageCache` table, bump `schemaVersion`, add the migration, and add the `AppDatabase` provider**

Replace the whole file with:

```dart
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'local_database.g.dart';

/// Cached subject (anime) metadata. Minimal columns for now -- the full
/// Subject model with tags/characters/staff/etc. is Plan 1b-2/1b-3's job;
/// this table only proves the persistence layer and its migration path
/// work.
class Subjects extends Table {
  IntColumn get id => integer()();
  TextColumn get name => text()();
  TextColumn get nameCn => text()();
  TextColumn get summary => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Cached episode metadata for a subject.
class Episodes extends Table {
  IntColumn get id => integer()();
  IntColumn get subjectId => integer().references(Subjects, #id)();
  TextColumn get sort => text()();
  TextColumn get name => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// The user's local collection (favorite/watch-progress) state for a
/// subject, with `dirty`/`syncedAt` tracking for Plan 1b-4's cloud sync:
/// `dirty` is set on any local edit and cleared once a push to the server
/// succeeds; `syncedAt` records the last successful sync time.
class SubjectCollections extends Table {
  IntColumn get subjectId => integer().references(Subjects, #id)();
  TextColumn get collectionType => text()();
  IntColumn get selfRatingScore => integer().nullable()();
  TextColumn get selfRatingComment => text().nullable()();
  BoolColumn get isPrivate => boolean().withDefault(const Constant(false))();
  BoolColumn get dirty => boolean().withDefault(const Constant(false))();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {subjectId};
}

/// Purely local search-history entries -- never synced to the server.
class SearchHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get query => text()();
  DateTimeColumn get searchedAt => dateTime()();
}

/// Locally-recorded `subjectId -> imageUrl` mapping, written when the
/// user collects/changes a subject's status on the detail page while its
/// cover image URL happens to be known (see
/// `SubjectCollectionController.setCollectionType`'s `imageUrl` param).
/// Exists because `GET /v2/subjects/list` (the "My Collection" list API)
/// never returns an image field -- see `MyCollectionSubject`'s doc
/// comment in `subject_models.dart`. Deliberately a standalone table
/// (not a column on [SubjectCollections]) so it doesn't take on that
/// table's cloud-sync semantics (`dirty`/`syncedAt`) or its non-nullable
/// unrelated columns (design doc "关键发现").
class SubjectImageCache extends Table {
  IntColumn get subjectId => integer()();
  TextColumn get imageUrl => text()();

  @override
  Set<Column> get primaryKey => {subjectId};
}

@DriftDatabase(
  tables: [Subjects, Episodes, SubjectCollections, SearchHistory, SubjectImageCache],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 2;

  /// SQLite does not enforce declared FOREIGN KEY constraints unless this
  /// pragma is turned on for the connection -- drift does not do this
  /// automatically. Without it, `Episodes.subjectId`/`SubjectCollections.subjectId`
  /// referencing a non-existent `Subjects.id` would silently succeed instead
  /// of throwing.
  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(subjectImageCache);
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'animeko.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
  }
}

/// Keeps the SQLite connection alive across page navigation -- unlike
/// every other provider in this codebase (all `autoDispose`), the DB
/// connection must not be torn down when e.g. the user leaves the
/// collection page, or every provider that reads/writes it would pay a
/// reconnect cost (and, worse, could race a half-closed connection).
@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) => AppDatabase();
```

- [ ] **Step 2: Regenerate the Drift + Riverpod codegen**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: Succeeds, regenerating `lib/data/local_database.g.dart` with a `SubjectImageCache`/`SubjectImageCacheCompanion` class pair and an `appDatabaseProvider`.

- [ ] **Step 3: Write the failing test for the new table**

Add this test to `test/data/local_database_test.dart`, inserting it right after the existing `'subjectCollections table round-trips a dirty row'` test (before `'searchHistory table round-trips a row'`):

```dart
  test('subjectImageCache table round-trips a row', () async {
    await db.into(db.subjectImageCache).insert(
          SubjectImageCacheCompanion.insert(
            subjectId: const Value(42),
            imageUrl: 'https://example.com/a.jpg',
          ),
        );

    final rows = await db.select(db.subjectImageCache).get();

    expect(rows, hasLength(1));
    expect(rows.single.subjectId, 42);
    expect(rows.single.imageUrl, 'https://example.com/a.jpg');
  });

  test('AppDatabase.schemaVersion is 2 (bumped for subjectImageCache)', () {
    expect(db.schemaVersion, 2);
  });
```

- [ ] **Step 4: Run the test**

Run: `flutter test test/data/local_database_test.dart`
Expected: PASS (6 tests total: the 4 pre-existing ones + the 2 new ones).

- [ ] **Step 5: Commit**

```bash
git add lib/data/local_database.dart lib/data/local_database.g.dart test/data/local_database_test.dart
git commit -m "feat(data): add SubjectImageCache table and keepAlive AppDatabase provider"
```

---

## Task 2: `SubjectImageCacheRepository`

**Files:**
- Create: `lib/data/subject/subject_image_cache_repository.dart`
- Test: `test/data/subject/subject_image_cache_repository_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `test/data/subject/subject_image_cache_repository_test.dart`:

```dart
import 'package:animeko_flutter/data/local_database.dart';
import 'package:animeko_flutter/data/subject/subject_image_cache_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late SubjectImageCacheRepository repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = SubjectImageCacheRepository(db);
  });

  tearDown(() => db.close());

  group('save', () {
    test('inserts a new subjectId -> imageUrl row', () async {
      await repository.save(1, 'https://example.com/a.jpg');

      final result = await repository.getFor([1]);

      expect(result, {1: 'https://example.com/a.jpg'});
    });

    test('upserts: a second save for the same subjectId overwrites the old value', () async {
      await repository.save(1, 'https://example.com/old.jpg');
      await repository.save(1, 'https://example.com/new.jpg');

      final result = await repository.getFor([1]);

      expect(result, {1: 'https://example.com/new.jpg'});
    });
  });

  group('getFor', () {
    test('returns an empty map for an empty id list', () async {
      final result = await repository.getFor(<int>[]);

      expect(result, isEmpty);
    });

    test('returns only the ids that have a cached row (partial hit)', () async {
      await repository.save(1, 'https://example.com/a.jpg');

      final result = await repository.getFor([1, 2, 3]);

      expect(result, {1: 'https://example.com/a.jpg'});
    });

    test('returns an empty map when none of the requested ids are cached', () async {
      final result = await repository.getFor([99]);

      expect(result, isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/data/subject/subject_image_cache_repository_test.dart`
Expected: FAIL to compile -- `Target of URI doesn't exist: 'package:animeko_flutter/data/subject/subject_image_cache_repository.dart'`.

- [ ] **Step 3: Implement the repository**

Create `lib/data/subject/subject_image_cache_repository.dart`:

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../local_database.dart';

part 'subject_image_cache_repository.g.dart';

/// Persists the `subjectId -> imageUrl` mapping recorded when the user
/// collects/changes a subject's status on the detail page (design doc
/// "写入路径"), so the "My Collection" list -- whose own API response
/// has no image field, see `MyCollectionSubject`'s doc comment in
/// `subject_models.dart` -- can show covers locally instead of leaving a
/// blank placeholder.
class SubjectImageCacheRepository {
  SubjectImageCacheRepository(this._db);
  final AppDatabase _db;

  /// Upserts one `subjectId -> imageUrl` row. Called after a successful
  /// collection-status change, so it deliberately overwrites any
  /// previously stored URL for the same [subjectId] (design doc: cached
  /// values get replaced by the next `save`, not merged/versioned).
  Future<void> save(int subjectId, String imageUrl) async {
    await _db.into(_db.subjectImageCache).insertOnConflictUpdate(
          SubjectImageCacheCompanion.insert(subjectId: subjectId, imageUrl: imageUrl),
        );
  }

  /// Batch-looks-up cached image URLs for a page of collection-list
  /// items. The returned map only contains keys for ids that actually
  /// have a cached row -- callers should treat a missing key the same
  /// as "no locally-cached image".
  Future<Map<int, String>> getFor(Iterable<int> subjectIds) async {
    final ids = subjectIds.toList();
    if (ids.isEmpty) return {};
    final rows = await (_db.select(_db.subjectImageCache)
          ..where((t) => t.subjectId.isIn(ids)))
        .get();
    return {for (final row in rows) row.subjectId: row.imageUrl};
  }
}

@riverpod
SubjectImageCacheRepository subjectImageCacheRepository(Ref ref) =>
    SubjectImageCacheRepository(ref.watch(appDatabaseProvider));
```

- [ ] **Step 4: Regenerate codegen**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: Succeeds, generating `lib/data/subject/subject_image_cache_repository.g.dart` with `subjectImageCacheRepositoryProvider`.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/data/subject/subject_image_cache_repository_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/data/subject/subject_image_cache_repository.dart lib/data/subject/subject_image_cache_repository.g.dart test/data/subject/subject_image_cache_repository_test.dart
git commit -m "feat(data): add SubjectImageCacheRepository for local cover-image lookups"
```

---

## Task 3: Write path — `SubjectCollectionController.setCollectionType` records the image

**Files:**
- Modify: `lib/domain/subject/subject_collection_controller.dart`
- Test: `test/domain/subject/subject_collection_controller_test.dart`

- [ ] **Step 1: Write the failing tests**

In `test/domain/subject/subject_collection_controller_test.dart`, add the `SubjectImageCacheRepository` import and a mock class near the top (after the existing `MockSubjectApi` class):

```dart
import 'package:animeko_flutter/data/subject/subject_image_cache_repository.dart';
```

```dart
class MockSubjectImageCacheRepository extends Mock implements SubjectImageCacheRepository {}
```

Update `setUp` to create the mock and override its provider:

```dart
void main() {
  late MockSubjectApi api;
  late MockSubjectImageCacheRepository imageCacheRepo;
  late ProviderContainer container;

  setUp(() {
    api = MockSubjectApi();
    imageCacheRepo = MockSubjectImageCacheRepository();
    container = ProviderContainer(
      overrides: [
        subjectApiProvider.overrideWithValue(api),
        subjectImageCacheRepositoryProvider.overrideWithValue(imageCacheRepo),
      ],
      retry: (retryCount, error) => null,
    );
    addTearDown(container.dispose);
  });
```

Add a new group right after the existing `group('setCollectionType', ...)` block (keep that block unchanged):

```dart
  group('setCollectionType image cache', () {
    test('saves the imageUrl to the local cache after a successful update', () async {
      when(() => api.getSubject(1)).thenAnswer((_) async => _detail);
      await container.read(provider.future);

      when(() => api.updateCollection(1, collectionType: CollectionType.doing))
          .thenAnswer((_) async {});
      when(() => imageCacheRepo.save(1, 'https://example.com/a.jpg'))
          .thenAnswer((_) async {});

      await container.read(provider.notifier).setCollectionType(
            CollectionType.doing,
            imageUrl: 'https://example.com/a.jpg',
          );

      verify(() => imageCacheRepo.save(1, 'https://example.com/a.jpg')).called(1);
    });

    test('does not touch the image cache when imageUrl is not provided', () async {
      when(() => api.getSubject(1)).thenAnswer((_) async => _detail);
      await container.read(provider.future);

      when(() => api.updateCollection(1, collectionType: CollectionType.doing))
          .thenAnswer((_) async {});

      await container.read(provider.notifier).setCollectionType(CollectionType.doing);

      verifyNever(() => imageCacheRepo.save(any(), any()));
    });

    test('does not fail setCollectionType when the image cache save throws', () async {
      when(() => api.getSubject(1)).thenAnswer((_) async => _detail);
      await container.read(provider.future);

      when(() => api.updateCollection(1, collectionType: CollectionType.doing))
          .thenAnswer((_) async {});
      when(() => imageCacheRepo.save(1, 'https://example.com/a.jpg'))
          .thenThrow(Exception('disk full'));

      await container.read(provider.notifier).setCollectionType(
            CollectionType.doing,
            imageUrl: 'https://example.com/a.jpg',
          );

      expect(container.read(provider).value!.collectionType, CollectionType.doing);
    });
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/domain/subject/subject_collection_controller_test.dart`
Expected: FAIL to compile -- `The named parameter 'imageUrl' isn't defined` (from `setCollectionType(CollectionType.doing, imageUrl: ...)`), and `subjectImageCacheRepositoryProvider`/`MockSubjectImageCacheRepository` referencing a method/provider that doesn't yet exist on the controller side.

- [ ] **Step 3: Implement the write path**

In `lib/domain/subject/subject_collection_controller.dart`, add the import:

```dart
import '../../data/subject/subject_image_cache_repository.dart';
```

Replace the `setCollectionType` method with:

```dart
  /// Optimistically updates [state] to [type] before the `PATCH`
  /// resolves, then rolls back to the pre-call state if it fails
  /// (design doc "收藏状态切换"). Rethrows on failure so the caller can
  /// show a one-off error -- see `SubjectDetailScreen` (Task 10).
  ///
  /// If [imageUrl] is given (the caller knows the subject's cover image
  /// URL -- see `_CollectionButtons` in `subject_detail_screen.dart`),
  /// records it to the local image cache once the remote update
  /// succeeds, so `MyCollectionsController` can show a cover for a list
  /// endpoint that itself never returns one (design doc "写入路径").
  /// A failure to write the cache is swallowed -- it must never surface
  /// as a collection-update failure, since the remote update already
  /// succeeded by that point (design doc "风险与已知限制").
  Future<void> setCollectionType(CollectionType type, {String? imageUrl}) async {
    final previous = state;
    final current = await future;
    state = AsyncData(current.copyWith(collectionType: type));
    try {
      await ref.read(subjectApiProvider).updateCollection(subjectId, collectionType: type);
    } catch (_) {
      state = previous;
      rethrow;
    }
    if (imageUrl != null) {
      try {
        await ref.read(subjectImageCacheRepositoryProvider).save(subjectId, imageUrl);
      } catch (_) {
        // Best-effort local cache only -- never let this fail the
        // (already-succeeded) collection-status update.
      }
    }
  }
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/domain/subject/subject_collection_controller_test.dart`
Expected: PASS (all pre-existing tests plus the 3 new ones, 14 total).

- [ ] **Step 5: Commit**

```bash
git add lib/domain/subject/subject_collection_controller.dart test/domain/subject/subject_collection_controller_test.dart
git commit -m "feat(domain): record cover imageUrl to local cache on setCollectionType"
```

---

## Task 4: Thread `imageUrl` through the detail screen to the collection buttons

**Files:**
- Modify: `lib/ui/subject/subject_detail_screen.dart`

No dedicated test file exists for this screen's widget tree in this repo (this is pure plumbing of an already-available value through three constructors; the behavior it triggers is already covered by Task 3's controller tests). Verification is via `flutter analyze` and the full test suite (Step 3 below).

- [ ] **Step 1: Update `_ImmersiveHeader` to pass `imageUrl` down to `_HeaderInfo`**

In `lib/ui/subject/subject_detail_screen.dart`, replace the `_ImmersiveHeader` class body:

```dart
class _ImmersiveHeader extends ConsumerWidget {
  const _ImmersiveHeader({required this.subjectId, required this.imageUrl});

  final int subjectId;
  final String imageUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = subjectDetailControllerProvider(subjectId: subjectId);
    final detail = ref.watch(provider);
    return SubjectBlurredHeader(
      imageUrl: imageUrl,
      info: detail.maybeWhen(
        data: (subject) =>
            _HeaderInfo(subjectId: subjectId, subject: subject, imageUrl: imageUrl),
        orElse: () => null,
      ),
    );
  }
}
```

- [ ] **Step 2: Update `_HeaderInfo` to accept and forward `imageUrl`, and `_CollectionButtons` to accept it**

Replace the `_HeaderInfo` class's constructor/fields and its call to `_CollectionButtons`:

```dart
class _HeaderInfo extends StatelessWidget {
  const _HeaderInfo({required this.subjectId, required this.subject, required this.imageUrl});

  final int subjectId;
  final SubjectDetail subject;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final score = subject.score != null
        ? double.tryParse(subject.score!)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          subject.nameCn.isNotEmpty ? subject.nameCn : subject.name,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        if (score != null || subject.rank != null)
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
            ],
          ),
        const SizedBox(height: 8),
        _CollectionButtons(subjectId: subjectId, imageUrl: imageUrl),
      ],
    );
  }
}
```

Then update the `_CollectionButtons` widget class to accept `imageUrl`:

```dart
class _CollectionButtons extends ConsumerStatefulWidget {
  const _CollectionButtons({required this.subjectId, required this.imageUrl});

  final int subjectId;
  final String imageUrl;

  @override
  ConsumerState<_CollectionButtons> createState() => _CollectionButtonsState();
}
```

And update `_CollectionButtonsState._setType` to pass it through to the controller:

```dart
  Future<void> _setType(CollectionType type) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(
            subjectCollectionControllerProvider(
              subjectId: widget.subjectId,
            ).notifier,
          )
          .setCollectionType(type, imageUrl: widget.imageUrl);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('更新收藏状态失败：$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
```

(`_remove` and the rest of `_CollectionButtonsState`/`_RatingSection`/everything below stay unchanged.)

- [ ] **Step 3: Verify with static analysis and the full test suite**

Run: `flutter analyze`
Expected: No new errors (pre-existing infos are OK per `AGENTS.md`).

Run: `flutter test`
Expected: PASS, no regressions (this task only changes widget-constructor plumbing that's gated behind the pre-existing `if (imageUrl != null)` check in `SubjectDetailScreen.build`, so `_ImmersiveHeader`/`_HeaderInfo`/`_CollectionButtons` are only ever constructed with a non-null `imageUrl`, matching their required, non-nullable `imageUrl` fields).

- [ ] **Step 4: Commit**

```bash
git add lib/ui/subject/subject_detail_screen.dart
git commit -m "feat(ui): thread cover imageUrl to the collection-status buttons"
```

---

## Task 5: `SubjectCard.fromMyCollectionSubject` accepts an optional `imageUrl`

**Files:**
- Modify: `lib/domain/subject_card.dart`
- Test: `test/domain/subject_card_test.dart`

- [ ] **Step 1: Write the failing tests**

Add to `test/domain/subject_card_test.dart` (add the import at the top and the two tests at the end of `main()`):

```dart
import 'package:animeko_flutter/data/subject/subject_models.dart';
```

```dart
  test('fromMyCollectionSubject assigns the given imageUrl when provided', () {
    const subject = MyCollectionSubject(subjectId: 5, name: 'C', nameCn: 'C-cn');
    final card = SubjectCard.fromMyCollectionSubject(subject, imageUrl: 'https://example.com/c.jpg');
    expect(card.imageUrl, 'https://example.com/c.jpg');
  });

  test('fromMyCollectionSubject leaves imageUrl null when not provided', () {
    const subject = MyCollectionSubject(subjectId: 6, name: 'D', nameCn: 'D-cn');
    final card = SubjectCard.fromMyCollectionSubject(subject);
    expect(card.imageUrl, isNull);
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/domain/subject_card_test.dart`
Expected: FAIL -- `The argument type 'Null' can't be assigned to the parameter type 'String'` or `No named parameter with the name 'imageUrl'` (the current `fromMyCollectionSubject(MyCollectionSubject s)` factory takes no `imageUrl` argument).

- [ ] **Step 3: Implement the optional parameter**

In `lib/domain/subject_card.dart`, replace the `fromMyCollectionSubject` factory:

```dart
  factory SubjectCard.fromMyCollectionSubject(MyCollectionSubject s, {String? imageUrl}) =>
      SubjectCard(id: s.subjectId, name: s.name, nameCn: s.nameCn, imageUrl: imageUrl);
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/domain/subject_card_test.dart`
Expected: PASS (4 tests total).

- [ ] **Step 5: Commit**

```bash
git add lib/domain/subject_card.dart test/domain/subject_card_test.dart
git commit -m "feat(domain): SubjectCard.fromMyCollectionSubject accepts an optional imageUrl"
```

---

## Task 6: Read path — `MyCollectionsController` merges cached image URLs

**Files:**
- Modify: `lib/domain/subject/my_collections_controller.dart`
- Test: `test/domain/subject/my_collections_controller_test.dart`

- [ ] **Step 1: Write the failing tests**

In `test/domain/subject/my_collections_controller_test.dart`, add the import and mock class after the existing `MockSubjectApi` class:

```dart
import 'package:animeko_flutter/data/subject/subject_image_cache_repository.dart';
```

```dart
class MockSubjectImageCacheRepository extends Mock implements SubjectImageCacheRepository {}
```

Update `setUp` to create the mock, stub a permissive default, and override its provider:

```dart
void main() {
  late MockSubjectApi api;
  late MockSubjectImageCacheRepository imageCacheRepo;
  late ProviderContainer container;

  setUp(() {
    api = MockSubjectApi();
    imageCacheRepo = MockSubjectImageCacheRepository();
    when(() => imageCacheRepo.getFor(any())).thenAnswer((_) async => {});
    container = ProviderContainer(
      overrides: [
        subjectApiProvider.overrideWithValue(api),
        subjectImageCacheRepositoryProvider.overrideWithValue(imageCacheRepo),
      ],
      retry: (retryCount, error) => null,
    );
    addTearDown(container.dispose);
  });
```

(This default stub keeps all 8 pre-existing `build`/`loadMore` tests passing unchanged, since none of them assert on `imageUrls`.)

Add a new `group('imageUrls', ...)` at the end of `main()`, right before the final closing brace:

```dart
  group('imageUrls', () {
    test('merges cached image URLs from the repository into the page', () async {
      when(() => api.getMyCollections(type: CollectionType.doing, offset: 0, limit: 20)).thenAnswer(
        (_) async => const PaginatedCollections(
          items: [MyCollectionSubject(subjectId: 1, name: 'A', nameCn: 'A-cn')],
          total: 1,
        ),
      );
      when(() => imageCacheRepo.getFor([1])).thenAnswer(
        (_) async => {1: 'https://example.com/a.jpg'},
      );

      final result = await container.read(
        myCollectionsControllerProvider(type: CollectionType.doing).future,
      );

      expect(result.imageUrls, {1: 'https://example.com/a.jpg'});
    });

    test('imageUrls has no entry for subjects without a cached image', () async {
      when(() => api.getMyCollections(type: CollectionType.doing, offset: 0, limit: 20)).thenAnswer(
        (_) async => const PaginatedCollections(
          items: [MyCollectionSubject(subjectId: 1, name: 'A', nameCn: 'A-cn')],
          total: 1,
        ),
      );
      when(() => imageCacheRepo.getFor([1])).thenAnswer((_) async => {});

      final result = await container.read(
        myCollectionsControllerProvider(type: CollectionType.doing).future,
      );

      expect(result.imageUrls, isEmpty);
    });

    test("loadMore merges the new page's cached image URLs on top of the existing ones", () async {
      when(() => api.getMyCollections(type: CollectionType.wish, offset: 0, limit: 20)).thenAnswer(
        (_) async => const PaginatedCollections(
          items: [MyCollectionSubject(subjectId: 1, name: 'A', nameCn: 'A-cn')],
          total: 2,
        ),
      );
      when(() => imageCacheRepo.getFor([1])).thenAnswer(
        (_) async => {1: 'https://example.com/a.jpg'},
      );
      await container.read(myCollectionsControllerProvider(type: CollectionType.wish).future);

      when(() => api.getMyCollections(type: CollectionType.wish, offset: 1, limit: 20)).thenAnswer(
        (_) async => const PaginatedCollections(
          items: [MyCollectionSubject(subjectId: 2, name: 'B', nameCn: 'B-cn')],
          total: 2,
        ),
      );
      when(() => imageCacheRepo.getFor([2])).thenAnswer(
        (_) async => {2: 'https://example.com/b.jpg'},
      );

      await container.read(myCollectionsControllerProvider(type: CollectionType.wish).notifier).loadMore();

      final result = container.read(myCollectionsControllerProvider(type: CollectionType.wish)).value!;
      expect(result.imageUrls, {
        1: 'https://example.com/a.jpg',
        2: 'https://example.com/b.jpg',
      });
    });
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/domain/subject/my_collections_controller_test.dart`
Expected: FAIL to compile -- `subjectImageCacheRepositoryProvider`/`MockSubjectImageCacheRepository` resolve fine (added in Task 2/3), but `MyCollectionsPage` has no `imageUrls` getter, so `result.imageUrls` fails with `The getter 'imageUrls' isn't defined for the type 'MyCollectionsPage'`.

- [ ] **Step 3: Implement the merge logic**

Replace `lib/domain/subject/my_collections_controller.dart` entirely with:

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/subject/collection_type.dart';
import '../../data/subject/subject_api.dart';
import '../../data/subject/subject_image_cache_repository.dart';
import '../../data/subject/subject_models.dart';

part 'my_collections_controller.g.dart';

const _pageSize = 20;

/// The loaded slice of the "My Collection" list plus whether another
/// page might still be available. [hasMore] uses the standard
/// "short page = last page" heuristic -- a fetched page with fewer
/// items than [_pageSize] means there's nothing left to load. This
/// doesn't require trusting [PaginatedCollections.total]'s exact
/// semantics against the real server (see the NOTE on that class).
///
/// [imageUrls] is a locally-cached `subjectId -> imageUrl` lookup (see
/// `SubjectImageCacheRepository`) -- `GET /v2/subjects/list` itself
/// never returns an image field (see `MyCollectionSubject`'s doc
/// comment), so this is the only source of cover images for this page.
/// A subject with no entry here has never been collected/re-collected
/// via the detail page's collection buttons while its image URL was
/// known (design doc "范围外").
class MyCollectionsPage {
  const MyCollectionsPage({
    required this.items,
    required this.hasMore,
    this.imageUrls = const {},
  });

  final List<MyCollectionSubject> items;
  final bool hasMore;
  final Map<int, String> imageUrls;
}

/// Backs the "My Collection" library page (Task 11), one instance per
/// segmented-control tab. `type: null` fetches all 5 states -- the UI
/// itself always passes a concrete [CollectionType] (one per tab), but
/// this controller doesn't require that.
@riverpod
class MyCollectionsController extends _$MyCollectionsController {
  @override
  Future<MyCollectionsPage> build({required CollectionType? type}) async {
    final page = await ref
        .watch(subjectApiProvider)
        .getMyCollections(type: type, offset: 0, limit: _pageSize);
    final imageUrls = await _imageUrlsFor(page.items);
    return MyCollectionsPage(
      items: page.items,
      hasMore: page.items.length >= _pageSize,
      imageUrls: imageUrls,
    );
  }

  /// Fetches the next page (offset = current list length) and appends
  /// it. No pull-to-refresh (design doc, YAGNI) -- leaving and
  /// re-entering the page re-runs [build] instead.
  Future<void> loadMore() async {
    final current = await future;
    final page = await ref
        .read(subjectApiProvider)
        .getMyCollections(type: type, offset: current.items.length, limit: _pageSize);
    final newImageUrls = await _imageUrlsFor(page.items);
    state = AsyncData(
      MyCollectionsPage(
        items: [...current.items, ...page.items],
        hasMore: page.items.length >= _pageSize,
        imageUrls: {...current.imageUrls, ...newImageUrls},
      ),
    );
  }

  Future<Map<int, String>> _imageUrlsFor(List<MyCollectionSubject> items) {
    return ref
        .read(subjectImageCacheRepositoryProvider)
        .getFor(items.map((item) => item.subjectId));
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/domain/subject/my_collections_controller_test.dart`
Expected: PASS (11 tests total: the 8 pre-existing ones + the 3 new ones).

- [ ] **Step 5: Commit**

```bash
git add lib/domain/subject/my_collections_controller.dart test/domain/subject/my_collections_controller_test.dart
git commit -m "feat(domain): MyCollectionsController merges locally-cached cover images"
```

---

## Task 7: Wire `imageUrls` into `my_collection_screen.dart` rendering

**Files:**
- Modify: `lib/ui/collection/my_collection_screen.dart`
- Test: `test/ui/collection/my_collection_screen_test.dart` (existing file, verify only — no new test required)

A widget-test file for this screen already exists (`test/ui/collection/my_collection_screen_test.dart`, 5 tests). Its `MyCollectionsPage(items: ..., hasMore: ...)` constructions don't pass `imageUrls` — this keeps compiling because Task 6 gives `imageUrls` a default value of `const {}`. The design doc's test list (item 6) doesn't call for a new test here, since this task is pure plumbing of an already-available value; the behavior it triggers is already covered by Task 3's controller tests. Verification is via `flutter analyze` and running this existing test file plus the full suite (Step 3 below).

- [ ] **Step 1: Pass `imageUrls` from the page state down to `_CollectionList`**

In `lib/ui/collection/my_collection_screen.dart`, update the `data:` branch inside `_MyCollectionScreenState.build`:

```dart
              data: (page) => _CollectionList(
                type: _selected,
                subjects: page.items,
                imageUrls: page.imageUrls,
                hasMore: page.hasMore,
                editMode: _editMode,
              ),
```

- [ ] **Step 2: Add the `imageUrls` field to `_CollectionList` and use it when building each card**

Replace the `_CollectionList` constructor/fields:

```dart
class _CollectionList extends ConsumerStatefulWidget {
  const _CollectionList({
    required this.type,
    required this.subjects,
    required this.imageUrls,
    required this.hasMore,
    required this.editMode,
  });

  final CollectionType type;
  final List<MyCollectionSubject> subjects;
  final Map<int, String> imageUrls;
  final bool hasMore;
  final bool editMode;

  @override
  ConsumerState<_CollectionList> createState() => _CollectionListState();
}
```

Then update the card construction inside `_CollectionListState.build`'s `itemBuilder`:

```dart
          final subject = widget.subjects[index];
          final card = SubjectCard.fromMyCollectionSubject(
            subject,
            imageUrl: widget.imageUrls[subject.subjectId],
          );
```

(Everything else in the file -- `_StatusMenuButton`, the rest of `_CollectionListState.build`, `AnimeListItem(imageUrl: card.imageUrl ?? '', ...)` -- stays unchanged; `_StatusMenuButton`'s path intentionally does not write to the image cache, per the design doc's "范围外".)

- [ ] **Step 3: Verify with static analysis and the full test suite**

Run: `flutter analyze`
Expected: No new errors.

Run: `flutter test test/ui/collection/my_collection_screen_test.dart`
Expected: PASS, no regressions (all 5 pre-existing tests still pass unchanged).

Run: `flutter test`
Expected: PASS, no regressions.

- [ ] **Step 4: Commit**

```bash
git add lib/ui/collection/my_collection_screen.dart
git commit -m "feat(ui): render locally-cached cover images in the My Collection list"
```

---

## Task 8: Final verification

**Files:** none (verification only).

- [ ] **Step 1: Run static analysis**

Run: `flutter analyze`
Expected: Clean of errors (pre-existing infos are OK per `AGENTS.md`).

- [ ] **Step 2: Run the full test suite**

Run: `flutter test`
Expected: All tests pass (the pre-existing ~359 tests plus the ~13 new ones added across Tasks 1, 2, 3, 5, and 6).

- [ ] **Step 3: Format check**

Run: `dart format --output=none --set-exit-if-changed lib test`
Expected: Exit code 0 (no formatting changes needed). If it fails, run `dart format lib test` and re-verify with Steps 1-2, then amend the relevant task's commit or add a small `style: dart format` commit.

- [ ] **Step 4: Manual smoke test (macOS desktop build)**

This feature's end-to-end effect (a cover image appearing in "My Collection" after the fix) can't be asserted by the automated suite, since it depends on live network data and a real app restart. If a manual pass is wanted: run the app, open a subject from Home/Search (so `imageUrl` is passed into `SubjectDetailScreen`), tap a collection-status chip (e.g. "在看"), go to "我的收藏" and confirm the cover now renders for that subject. Restarting the app should still show it (proves persistence, not just in-memory state). This step is optional and not required to consider the plan complete -- Steps 1-3 are the required completion gates.
