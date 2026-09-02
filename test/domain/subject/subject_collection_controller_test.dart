import 'dart:async';

import 'package:animeko_flutter/data/subject/collection_type.dart';
import 'package:animeko_flutter/data/subject/subject_api.dart';
import 'package:animeko_flutter/data/subject/subject_models.dart';
import 'package:animeko_flutter/domain/subject/subject_collection_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class MockSubjectApi extends Mock implements SubjectApi {}

const _unratedSelfRating = SelfRating(score: 0, tags: [], isPrivate: false);

const _detail = SubjectDetail(
  id: 1,
  name: 'A',
  nameCn: 'A-cn',
  summary: 's',
  airDate: '2026-01-01',
  tags: [],
  selfRating: _unratedSelfRating,
);

const _detailCollected = SubjectDetail(
  id: 1,
  name: 'A',
  nameCn: 'A-cn',
  summary: 's',
  airDate: '2026-01-01',
  tags: [],
  collectionType: CollectionType.doing,
  selfRating: _unratedSelfRating,
);

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

  final provider = subjectCollectionControllerProvider(subjectId: 1);

  group('build', () {
    test('reads the initial collectionType/selfRating from SubjectDetailController', () async {
      when(() => api.getSubject(1)).thenAnswer((_) async => _detailCollected);

      final result = await container.read(provider.future);

      expect(result.collectionType, CollectionType.doing);
      expect(result.selfRating.score, 0);
    });
  });

  group('setCollectionType', () {
    test('optimistically updates state before the PATCH resolves', () async {
      when(() => api.getSubject(1)).thenAnswer((_) async => _detail);
      await container.read(provider.future);
      // subjectCollectionControllerProvider is autoDispose (matching
      // SearchController's pattern -- see search_controller_test.dart).
      // container.read() alone does not keep an autoDispose provider
      // alive once the synchronous call stack returns, so the
      // `Future<void>.delayed(Duration.zero)` await below would give
      // riverpod's scheduled disposal a chance to tear down and rebuild
      // the notifier from scratch, silently discarding the optimistic
      // state mutation this test is asserting on. A held subscription
      // keeps it alive across that gap.
      final sub = container.listen(provider, (_, _) {});
      addTearDown(sub.close);

      final completer = Completer<void>();
      when(() => api.updateCollection(1, collectionType: CollectionType.doing))
          .thenAnswer((_) => completer.future);

      final call = container.read(provider.notifier).setCollectionType(CollectionType.doing);
      // The optimistic `state = AsyncData(...)` assignment happens
      // synchronously before the `await api.updateCollection(...)` call --
      // give that a chance to run before asserting.
      await Future<void>.delayed(Duration.zero);

      expect(container.read(provider).value!.collectionType, CollectionType.doing);

      completer.complete();
      await call;
    });

    test('rolls back to the previous state when the PATCH fails', () async {
      when(() => api.getSubject(1)).thenAnswer((_) async => _detail);
      await container.read(provider.future);

      when(() => api.updateCollection(1, collectionType: CollectionType.dropped))
          .thenThrow(Exception('network error'));

      await expectLater(
        container.read(provider.notifier).setCollectionType(CollectionType.dropped),
        throwsA(isA<Exception>()),
      );

      expect(container.read(provider).value!.collectionType, isNull);
    });
  });

  group('removeFromCollection', () {
    test('optimistically clears collectionType and calls deleteCollection', () async {
      when(() => api.getSubject(1)).thenAnswer((_) async => _detailCollected);
      await container.read(provider.future);

      when(() => api.deleteCollection(1)).thenAnswer((_) async {});

      await container.read(provider.notifier).removeFromCollection();

      expect(container.read(provider).value!.collectionType, isNull);
      verify(() => api.deleteCollection(1)).called(1);
    });

    test('rolls back to the previous collectionType when the DELETE fails', () async {
      when(() => api.getSubject(1)).thenAnswer((_) async => _detailCollected);
      await container.read(provider.future);

      when(() => api.deleteCollection(1)).thenThrow(Exception('network error'));

      await expectLater(
        container.read(provider.notifier).removeFromCollection(),
        throwsA(isA<Exception>()),
      );

      expect(container.read(provider).value!.collectionType, CollectionType.doing);
    });
  });

  group('submitRating', () {
    test('rejects a score outside 1-10 without calling the API', () async {
      when(() => api.getSubject(1)).thenAnswer((_) async => _detail);
      await container.read(provider.future);

      await expectLater(container.read(provider.notifier).submitRating(0), throwsArgumentError);
      await expectLater(container.read(provider.notifier).submitRating(11), throwsArgumentError);
      verifyNever(() => api.updateCollection(any(), selfRating: any(named: 'selfRating')));
    });

    test('updates state only after the PATCH succeeds', () async {
      when(() => api.getSubject(1)).thenAnswer((_) async => _detail);
      await container.read(provider.future);

      when(() => api.updateCollection(1, selfRating: any(named: 'selfRating')))
          .thenAnswer((_) async {});

      await container.read(provider.notifier).submitRating(8, comment: '好看');

      final result = container.read(provider).value!;
      expect(result.selfRating.score, 8);
      expect(result.selfRating.comment, '好看');
    });

    test('leaves state unchanged when the PATCH fails', () async {
      when(() => api.getSubject(1)).thenAnswer((_) async => _detail);
      await container.read(provider.future);

      when(() => api.updateCollection(1, selfRating: any(named: 'selfRating')))
          .thenThrow(Exception('network error'));

      await expectLater(
        container.read(provider.notifier).submitRating(8),
        throwsA(isA<Exception>()),
      );

      expect(container.read(provider).value!.selfRating.score, 0);
    });
  });
}
