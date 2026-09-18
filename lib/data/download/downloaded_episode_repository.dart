import 'dart:io';

import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../local_database.dart';

part 'downloaded_episode_repository.g.dart';

enum DownloadStatus { downloading, completed, failed, interrupted }

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

class DownloadedEpisodeRepository {
  DownloadedEpisodeRepository(this._db, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _now;

  Future<DownloadedEpisode?> findByKey(String episodeKey) => (_db.select(
    _db.downloadedEpisodes,
  )..where((row) => row.episodeKey.equals(episodeKey))).getSingleOrNull();

  Future<DownloadedEpisode?> findCompleted(String episodeKey) =>
      (_db.select(_db.downloadedEpisodes)
            ..where((row) => row.episodeKey.equals(episodeKey))
            ..where((row) => row.status.equals(DownloadStatus.completed.name)))
          .getSingleOrNull();

  Future<List<DownloadedEpisode>> getAll() => (_db.select(
    _db.downloadedEpisodes,
  )..orderBy([(row) => OrderingTerm.desc(row.createdAt)])).get();

  Stream<List<DownloadedEpisode>> watchAll() => (_db.select(
    _db.downloadedEpisodes,
  )..orderBy([(row) => OrderingTerm.desc(row.createdAt)])).watch();

  Future<void> upsert(DownloadedEpisodeWrite value) async {
    final existing = await findByKey(value.episodeKey);
    await _db
        .into(_db.downloadedEpisodes)
        .insertOnConflictUpdate(
          DownloadedEpisodesCompanion.insert(
            id: existing == null ? const Value.absent() : Value(existing.id),
            sourceId: value.sourceId,
            subjectId: value.subjectId,
            episodeKey: value.episodeKey,
            subjectName: value.subjectName,
            episodeLabel: value.episodeLabel,
            localPath: value.localPath,
            format: value.format,
            fileSizeBytes: Value(value.fileSizeBytes),
            status: value.status.name,
            errorMessage: Value(value.errorMessage),
            episodeDir: Value(value.episodeDir),
            createdAt: existing?.createdAt ?? _now(),
            completedAt: Value(
              value.status == DownloadStatus.completed ? _now() : null,
            ),
          ),
        );
  }

  /// Marks every row still in [DownloadStatus.downloading] as
  /// [DownloadStatus.interrupted]. Call once at app startup (from
  /// `DownloadQueueController.build()`) — a `downloading` row that survives
  /// to the next launch means the app was killed/crashed mid-download, so
  /// nothing is actually still writing to that file.
  Future<void> reconcileInterrupted() =>
      (_db.update(
            _db.downloadedEpisodes,
          )..where((row) => row.status.equals(DownloadStatus.downloading.name)))
          .write(
            DownloadedEpisodesCompanion(
              status: Value(DownloadStatus.interrupted.name),
            ),
          );

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

  Future<void> delete(String episodeKey) => (_db.delete(
    _db.downloadedEpisodes,
  )..where((row) => row.episodeKey.equals(episodeKey))).go();

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
}

@riverpod
DownloadedEpisodeRepository downloadedEpisodeRepository(Ref ref) =>
    DownloadedEpisodeRepository(ref.watch(appDatabaseProvider));

@riverpod
Future<bool> downloadedEpisodeByKey(Ref ref, String episodeKey) async =>
    await ref
        .watch(downloadedEpisodeRepositoryProvider)
        .findCompleted(episodeKey) !=
    null;

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
