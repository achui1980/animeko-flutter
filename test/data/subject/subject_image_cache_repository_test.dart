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
