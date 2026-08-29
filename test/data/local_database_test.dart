import 'package:animeko_flutter/data/local_database.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  test('subjects table round-trips a row', () async {
    await db.into(db.subjects).insert(
          SubjectsCompanion.insert(id: const Value(1), name: 'Test Anime', nameCn: '测试动画'),
        );

    final rows = await db.select(db.subjects).get();

    expect(rows, hasLength(1));
    expect(rows.single.name, 'Test Anime');
  });

  test('episodes table round-trips a row', () async {
    await db.into(db.subjects).insert(
          SubjectsCompanion.insert(id: const Value(1), name: 'Test Anime', nameCn: '测试动画'),
        );
    await db.into(db.episodes).insert(
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
    await db.into(db.subjects).insert(
          SubjectsCompanion.insert(id: const Value(1), name: 'Test Anime', nameCn: '测试动画'),
        );
    await db.into(db.subjectCollections).insert(
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

  test('searchHistory table round-trips a row', () async {
    await db.into(db.searchHistory).insert(
          SearchHistoryCompanion.insert(query: 'mahou shoujo', searchedAt: DateTime(2026, 1, 1)),
        );

    final rows = await db.select(db.searchHistory).get();

    expect(rows, hasLength(1));
    expect(rows.single.query, 'mahou shoujo');
  });

  test('inserting an Episode with a non-existent subjectId throws (FK enforcement)', () async {
    expect(
      () async => await db.into(db.episodes).insert(
            EpisodesCompanion.insert(
              id: const Value(10),
              subjectId: 999,
              sort: '1',
              name: 'Episode 1',
            ),
          ),
      throwsA(anything),
    );
  });
}
