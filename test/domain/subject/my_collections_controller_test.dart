import 'package:animeko_flutter/data/subject/collection_type.dart';
import 'package:animeko_flutter/data/subject/subject_api.dart';
import 'package:animeko_flutter/data/subject/subject_models.dart';
import 'package:animeko_flutter/domain/subject/my_collections_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class MockSubjectApi extends Mock implements SubjectApi {}

void main() {
  late MockSubjectApi api;
  late ProviderContainer container;

  setUp(() {
    api = MockSubjectApi();
    container = ProviderContainer(
      overrides: [subjectApiProvider.overrideWithValue(api)],
      retry: (retryCount, error) => null,
    );
    addTearDown(container.dispose);
  });

  group('build', () {
    test('fetches the first page for the given type at offset 0', () async {
      when(() => api.getMyCollections(type: CollectionType.doing, offset: 0, limit: 20)).thenAnswer(
        (_) async => const PaginatedCollections(
          items: [MyCollectionSubject(subjectId: 1, name: 'A', nameCn: 'A-cn')],
          total: 1,
        ),
      );

      final result = await container.read(
        myCollectionsControllerProvider(type: CollectionType.doing).future,
      );

      expect(result, hasLength(1));
      expect(result.single.nameCn, 'A-cn');
    });

    test('fetches all types (type: null) at offset 0', () async {
      when(() => api.getMyCollections(type: null, offset: 0, limit: 20)).thenAnswer(
        (_) async => const PaginatedCollections(items: [], total: 0),
      );

      final result = await container.read(myCollectionsControllerProvider(type: null).future);

      expect(result, isEmpty);
    });
  });

  group('loadMore', () {
    test('fetches the next page using the current length as offset and appends it', () async {
      when(() => api.getMyCollections(type: CollectionType.wish, offset: 0, limit: 20)).thenAnswer(
        (_) async => const PaginatedCollections(
          items: [MyCollectionSubject(subjectId: 1, name: 'A', nameCn: 'A-cn')],
          total: 2,
        ),
      );
      await container.read(myCollectionsControllerProvider(type: CollectionType.wish).future);

      when(() => api.getMyCollections(type: CollectionType.wish, offset: 1, limit: 20)).thenAnswer(
        (_) async => const PaginatedCollections(
          items: [MyCollectionSubject(subjectId: 2, name: 'B', nameCn: 'B-cn')],
          total: 2,
        ),
      );

      await container.read(myCollectionsControllerProvider(type: CollectionType.wish).notifier).loadMore();

      final result = container.read(myCollectionsControllerProvider(type: CollectionType.wish)).value!;
      expect(result, hasLength(2));
      expect(result.map((s) => s.subjectId), [1, 2]);
    });
  });
}
