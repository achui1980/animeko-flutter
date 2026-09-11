import 'package:drift/drift.dart';
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
    await _db
        .into(_db.subjectImageCache)
        .insertOnConflictUpdate(
          SubjectImageCacheCompanion.insert(
            subjectId: Value(subjectId),
            imageUrl: imageUrl,
          ),
        );
  }

  /// Batch-looks-up cached image URLs for a page of collection-list
  /// items. The returned map only contains keys for ids that actually
  /// have a cached row -- callers should treat a missing key the same
  /// as "no locally-cached image".
  Future<Map<int, String>> getFor(Iterable<int> subjectIds) async {
    final ids = subjectIds.toList();
    if (ids.isEmpty) return {};
    final rows = await (_db.select(
      _db.subjectImageCache,
    )..where((t) => t.subjectId.isIn(ids))).get();
    return {for (final row in rows) row.subjectId: row.imageUrl};
  }
}

@riverpod
SubjectImageCacheRepository subjectImageCacheRepository(Ref ref) =>
    SubjectImageCacheRepository(ref.watch(appDatabaseProvider));
