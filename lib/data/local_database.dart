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

/// Persistent cache of the `Bangumi subjectId -> Mikan bangumiId` mapping
/// resolved by `MikanSubjectLocator` (see
/// `lib/data/rss/mikan_subject_locator.dart`). Resolving costs up to 4 HTTP
/// requests (one 条目 search plus up to three back-link verifications), so
/// the result is cached and re-used on every later visit to the same
/// subject.
///
/// [mikanBangumiId] is nullable and `null` means "confirmed *not* findable
/// on Mikan", which is a real, cacheable answer (the source then falls back
/// to keyword search) -- but only for 7 days, since a newly-aired subject
/// can show up on Mikan later (see
/// `MikanSubjectMappingRepository.negativeTtl`). Positive results never
/// expire.
///
/// Deliberately has NO foreign key to [Subjects]: `PRAGMA foreign_keys` is
/// ON for this connection (see [AppDatabase.migration]) and nothing in the
/// app currently writes [Subjects], so a `references(Subjects, #id)` here
/// would make every mapping insert fail.
class MikanSubjectMappings extends Table {
  IntColumn get subjectId => integer()();
  IntColumn get mikanBangumiId => integer().nullable()();
  DateTimeColumn get resolvedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {subjectId};
}

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

@DriftDatabase(
  tables: [
    Subjects,
    Episodes,
    SubjectCollections,
    SearchHistory,
    SubjectImageCache,
    MikanSubjectMappings,
    DownloadedEpisodes,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 5;

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
