import 'package:animeko_flutter/data/local_database.dart';
import 'package:drift/drift.dart' show Migrator, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  test('subjects table round-trips a row', () async {
    await db
        .into(db.subjects)
        .insert(
          SubjectsCompanion.insert(
            id: const Value(1),
            name: 'Test Anime',
            nameCn: '测试动画',
          ),
        );

    final rows = await db.select(db.subjects).get();

    expect(rows, hasLength(1));
    expect(rows.single.name, 'Test Anime');
  });

  test('episodes table round-trips a row', () async {
    await db
        .into(db.subjects)
        .insert(
          SubjectsCompanion.insert(
            id: const Value(1),
            name: 'Test Anime',
            nameCn: '测试动画',
          ),
        );
    await db
        .into(db.episodes)
        .insert(
          EpisodesCompanion.insert(
            id: const Value(10),
            subjectId: 1,
            sort: '1',
            name: 'Episode 1',
          ),
        );

    final rows = await db.select(db.episodes).get();

    expect(rows, hasLength(1));
    expect(rows.single.subjectId, 1);
  });

  test('subjectCollections table round-trips a dirty row', () async {
    await db
        .into(db.subjects)
        .insert(
          SubjectsCompanion.insert(
            id: const Value(1),
            name: 'Test Anime',
            nameCn: '测试动画',
          ),
        );
    await db
        .into(db.subjectCollections)
        .insert(
          SubjectCollectionsCompanion.insert(
            subjectId: const Value(1),
            collectionType: 'DOING',
            dirty: const Value(true),
          ),
        );

    final rows = await db.select(db.subjectCollections).get();

    expect(rows, hasLength(1));
    expect(rows.single.dirty, isTrue);
    expect(rows.single.syncedAt, isNull);
    expect(rows.single.isPrivate, isFalse);
  });

  test('subjectImageCache table round-trips a row', () async {
    await db
        .into(db.subjectImageCache)
        .insert(
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

  test('AppDatabase.schemaVersion is 3 (bumped for mikanSubjectMappings)', () {
    expect(db.schemaVersion, 3);
  });

  test('mikanSubjectMappings table round-trips a resolved row', () async {
    await db
        .into(db.mikanSubjectMappings)
        .insert(
          MikanSubjectMappingsCompanion.insert(
            subjectId: const Value(545008),
            mikanBangumiId: const Value(4012),
            resolvedAt: DateTime(2026, 9, 11),
          ),
        );

    final rows = await db.select(db.mikanSubjectMappings).get();

    expect(rows, hasLength(1));
    expect(rows.single.subjectId, 545008);
    expect(rows.single.mikanBangumiId, 4012);
    expect(rows.single.resolvedAt, DateTime(2026, 9, 11));
  });

  test('mikanSubjectMappings accepts a null mikanBangumiId (confirmed '
      'absent from Mikan)', () async {
    await db
        .into(db.mikanSubjectMappings)
        .insert(
          MikanSubjectMappingsCompanion.insert(
            subjectId: const Value(1),
            resolvedAt: DateTime(2026, 9, 11),
          ),
        );

    final rows = await db.select(db.mikanSubjectMappings).get();

    expect(rows.single.mikanBangumiId, isNull);
  });

  test('mikanSubjectMappings does NOT require a matching Subjects row '
      '(no FK: a subject may never have been cached locally)', () async {
    await db
        .into(db.mikanSubjectMappings)
        .insert(
          MikanSubjectMappingsCompanion.insert(
            subjectId: const Value(999999),
            resolvedAt: DateTime(2026, 9, 11),
          ),
        );

    expect(await db.select(db.mikanSubjectMappings).get(), hasLength(1));
  });

  test(
    'onUpgrade from schema 2 creates the mikanSubjectMappings table',
    () async {
      // A fresh in-memory database is created at the current schema, so drop
      // the new table to simulate a schema-2 database, then run the real
      // onUpgrade callback for the 2 -> 3 step.
      await db.customStatement('DROP TABLE mikan_subject_mappings');

      await db.migration.onUpgrade(Migrator(db), 2, 3);

      await db
          .into(db.mikanSubjectMappings)
          .insert(
            MikanSubjectMappingsCompanion.insert(
              subjectId: const Value(545008),
              mikanBangumiId: const Value(4012),
              resolvedAt: DateTime(2026, 9, 11),
            ),
          );
      expect(await db.select(db.mikanSubjectMappings).get(), hasLength(1));
    },
  );

  test('searchHistory table round-trips a row', () async {
    await db
        .into(db.searchHistory)
        .insert(
          SearchHistoryCompanion.insert(
            query: 'mahou shoujo',
            searchedAt: DateTime(2026, 1, 1),
          ),
        );

    final rows = await db.select(db.searchHistory).get();

    expect(rows, hasLength(1));
    expect(rows.single.query, 'mahou shoujo');
  });

  test(
    'inserting an Episode with a non-existent subjectId throws (FK enforcement)',
    () async {
      expect(
        () async => await db
            .into(db.episodes)
            .insert(
              EpisodesCompanion.insert(
                id: const Value(10),
                subjectId: 999,
                sort: '1',
                name: 'Episode 1',
              ),
            ),
        throwsA(anything),
      );
    },
  );
}
