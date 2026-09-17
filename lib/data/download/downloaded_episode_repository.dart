import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../local_database.dart';

part 'downloaded_episode_repository.g.dart';

enum DownloadStatus { downloading, completed, failed }

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
            createdAt: existing?.createdAt ?? _now(),
            completedAt: Value(
              value.status == DownloadStatus.completed ? _now() : null,
            ),
          ),
        );
  }

  Future<void> delete(String episodeKey) => (_db.delete(
    _db.downloadedEpisodes,
  )..where((row) => row.episodeKey.equals(episodeKey))).go();
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
