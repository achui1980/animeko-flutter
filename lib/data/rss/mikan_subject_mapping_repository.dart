import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../local_database.dart';

part 'mikan_subject_mapping_repository.g.dart';

/// A usable cached `subjectId -> Mikan bangumiId` answer.
///
/// [bangumiId] `null` means "confirmed absent from Mikan, and that negative
/// answer has not expired yet" -- distinct from
/// [MikanSubjectMappingRepository.lookup] returning `null`, which means
/// "no usable cache, go ask the network".
class CachedMikanMapping {
  const CachedMikanMapping(this.bangumiId);

  final int? bangumiId;
}

/// Read/write access to the persistent `subjectId -> Mikan bangumiId`
/// mapping cache (see [MikanSubjectMappings]), plus the local Japanese-name
/// lookup the locator needs for its second search-keyword candidate.
///
/// The Japanese-name read lives here (rather than injecting [AppDatabase]
/// into `RssMediaSource`) so the media source has exactly one collaborator
/// for all of its local-database needs.
class MikanSubjectMappingRepository {
  MikanSubjectMappingRepository(
    this._db, {
    DateTime Function() now = DateTime.now,
  }) : _now = now;

  final AppDatabase _db;
  final DateTime Function() _now;

  /// How long a negative ("not on Mikan") answer stays valid. A subject can
  /// be added to Mikan after it starts airing, so a miss must be retried
  /// eventually -- but not on every single visit.
  static const negativeTtl = Duration(days: 7);

  /// Returns the cached answer for [subjectId], or `null` when there is no
  /// usable cache: either nothing was ever stored, or the stored answer is a
  /// negative one that has since expired.
  Future<CachedMikanMapping?> lookup(int subjectId) async {
    final row = await (_db.select(
      _db.mikanSubjectMappings,
    )..where((t) => t.subjectId.equals(subjectId))).getSingleOrNull();
    if (row == null) return null;

    final bangumiId = row.mikanBangumiId;
    if (bangumiId != null) return CachedMikanMapping(bangumiId);

    if (_now().difference(row.resolvedAt) >= negativeTtl) return null;
    return const CachedMikanMapping(null);
  }

  /// Stores the resolution result for [subjectId], overwriting any previous
  /// answer. Pass a `null` [mikanBangumiId] to record a negative result.
  Future<void> save(int subjectId, int? mikanBangumiId) async {
    await _db
        .into(_db.mikanSubjectMappings)
        .insertOnConflictUpdate(
          MikanSubjectMappingsCompanion.insert(
            subjectId: Value(subjectId),
            mikanBangumiId: Value(mikanBangumiId),
            resolvedAt: _now(),
          ),
        );
  }

  /// The subject's original (usually Japanese) name from the local
  /// [Subjects] cache, or `null` when the subject was never cached locally
  /// or its name is blank. Mikan indexes Japanese titles too, so this is the
  /// locator's second keyword candidate -- when it is `null` that candidate
  /// is simply skipped, with no extra HTTP request.
  Future<String?> readJapaneseName(int subjectId) async {
    final row = await (_db.select(
      _db.subjects,
    )..where((t) => t.id.equals(subjectId))).getSingleOrNull();
    final name = row?.name.trim();
    if (name == null || name.isEmpty) return null;
    return name;
  }
}

@riverpod
MikanSubjectMappingRepository mikanSubjectMappingRepository(Ref ref) =>
    MikanSubjectMappingRepository(ref.watch(appDatabaseProvider));
