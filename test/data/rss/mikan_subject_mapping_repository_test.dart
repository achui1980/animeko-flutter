import 'package:animeko_flutter/data/local_database.dart';
import 'package:animeko_flutter/data/rss/mikan_subject_mapping_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  /// Fixed "current time" so the 7-day negative TTL is deterministic.
  final now = DateTime(2026, 9, 11, 12);

  MikanSubjectMappingRepository repositoryAt(DateTime clock) =>
      MikanSubjectMappingRepository(db, now: () => clock);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  group('lookup', () {
    test('returns null when the subject was never resolved', () async {
      expect(await repositoryAt(now).lookup(545008), isNull);
    });

    test('returns the cached positive mapping', () async {
      await repositoryAt(now).save(545008, 4012);

      final cached = await repositoryAt(now).lookup(545008);

      expect(cached, isNotNull);
      expect(cached!.bangumiId, 4012);
    });

    test('a positive mapping never expires', () async {
      await repositoryAt(now).save(545008, 4012);

      final cached = await repositoryAt(
        now.add(const Duration(days: 3650)),
      ).lookup(545008);

      expect(cached?.bangumiId, 4012);
    });

    test('returns a fresh negative result as a usable cache entry', () async {
      await repositoryAt(now).save(545008, null);

      final cached = await repositoryAt(
        now.add(const Duration(days: 6, hours: 23)),
      ).lookup(545008);

      expect(cached, isNotNull);
      expect(cached!.bangumiId, isNull);
    });

    test(
      'treats a negative result older than 7 days as a cache miss',
      () async {
        await repositoryAt(now).save(545008, null);

        final cached = await repositoryAt(
          now.add(const Duration(days: 7, seconds: 1)),
        ).lookup(545008);

        expect(cached, isNull);
      },
    );

    test(
      'treats a negative result exactly negativeTtl old as a miss',
      () async {
        await repositoryAt(now).save(545008, null);

        final cached = await repositoryAt(
          now.add(MikanSubjectMappingRepository.negativeTtl),
        ).lookup(545008);

        expect(cached, isNull);
      },
    );

    test('does not serve another subject\'s mapping', () async {
      await repositoryAt(now).save(999999, 4012);

      expect(await repositoryAt(now).lookup(545008), isNull);
    });
  });

  group('save', () {
    test('upserts: a later save overwrites the earlier value', () async {
      await repositoryAt(now).save(545008, null);
      await repositoryAt(now.add(const Duration(days: 1))).save(545008, 4012);

      final rows = await db.select(db.mikanSubjectMappings).get();

      expect(rows, hasLength(1));
      expect(rows.single.mikanBangumiId, 4012);
      expect(rows.single.resolvedAt, now.add(const Duration(days: 1)));
    });

    test('stamps resolvedAt with the injected clock', () async {
      await repositoryAt(now).save(545008, 4012);

      final rows = await db.select(db.mikanSubjectMappings).get();

      expect(rows.single.resolvedAt, now);
    });
  });

  group('readJapaneseName', () {
    test('returns null when the subject is not cached locally', () async {
      expect(await repositoryAt(now).readJapaneseName(545008), isNull);
    });

    test('returns the Subjects.name column for a cached subject', () async {
      await db
          .into(db.subjects)
          .insert(
            SubjectsCompanion.insert(
              id: const Value(545008),
              name: 'ふつつかな悪女ではございますが ～雛宮蝶鼠伝奇～',
              nameCn: '恶女不才，请多关照 ～雏宫蝶鼠换身传～',
            ),
          );

      expect(
        await repositoryAt(now).readJapaneseName(545008),
        'ふつつかな悪女ではございますが ～雛宮蝶鼠伝奇～',
      );
    });

    test('returns null for a blank name', () async {
      await db
          .into(db.subjects)
          .insert(
            SubjectsCompanion.insert(
              id: const Value(545008),
              name: '   ',
              nameCn: '恶女不才，请多关照',
            ),
          );

      expect(await repositoryAt(now).readJapaneseName(545008), isNull);
    });

    test('does not serve another subject\'s name', () async {
      await db
          .into(db.subjects)
          .insert(
            SubjectsCompanion.insert(
              id: const Value(999999),
              name: 'ふつつかな悪女ではございますが ～雛宮蝶鼠伝奇～',
              nameCn: '恶女不才，请多关照 ～雏宫蝶鼠换身传～',
            ),
          );

      expect(await repositoryAt(now).readJapaneseName(545008), isNull);
    });
  });

  group('CachedMikanMapping', () {
    test('compares by value, including on the positive lookup path', () async {
      await repositoryAt(now).save(545008, 4012);

      final cached = await repositoryAt(now).lookup(545008);

      expect(cached, const CachedMikanMapping(4012));
      expect(cached.hashCode, const CachedMikanMapping(4012).hashCode);
      expect(cached, isNot(const CachedMikanMapping(null)));
    });
  });
}
