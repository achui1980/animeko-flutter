import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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

@DriftDatabase(tables: [Subjects, Episodes, SubjectCollections, SearchHistory])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  /// SQLite does not enforce declared FOREIGN KEY constraints unless this
  /// pragma is turned on for the connection -- drift does not do this
  /// automatically. Without it, `Episodes.subjectId`/`SubjectCollections.subjectId`
  /// referencing a non-existent `Subjects.id` would silently succeed instead
  /// of throwing.
  @override
  MigrationStrategy get migration => MigrationStrategy(
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
