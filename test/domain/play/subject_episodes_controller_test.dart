import 'package:animeko_flutter/data/anime1/anime1_api.dart';
import 'package:animeko_flutter/data/anime1/anime1_models.dart';
import 'package:animeko_flutter/domain/play/subject_episodes_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

void main() {
  group('SubjectEpisodesController', () {
    late _MockAnime1Api api;
    late ProviderContainer container;

    setUp(() {
      api = _MockAnime1Api();
      container = ProviderContainer(
        overrides: [anime1ApiProvider.overrideWithValue(api)],
        // riverpod 3.x's default `retry` re-runs a failed build() several
        // times with exponential backoff (see
        // `ProviderContainer.defaultRetry`), which would make the
        // "throws"/"propagates" tests below spend ~30s retrying against a
        // mock that always fails before finally giving up. Disable it so
        // failures surface immediately.
        retry: (retryCount, error) => null,
      );
      addTearDown(container.dispose);
    });

    test('matches a category then returns its episodes', () async {
      when(() => api.searchCategories('葬送的芙莉蓮')).thenAnswer(
        (_) async => [const Anime1Category(id: 87, title: '葬送的芙莉蓮')],
      );
      when(() => api.fetchCategoryEpisodes(87)).thenAnswer(
        (_) async => [
          const Anime1Episode(title: '葬送的芙莉蓮 [1]', pageUrl: 'https://anime1.me/?p=1'),
        ],
      );

      final result = await container.read(
        subjectEpisodesControllerProvider(subjectId: 1, subjectName: '葬送的芙莉蓮').future,
      );

      expect(result, hasLength(1));
      expect(result.single.title, '葬送的芙莉蓮 [1]');
    });

    test('throws Anime1NotFoundException when no category matches', () async {
      when(() => api.searchCategories(any())).thenAnswer((_) async => []);

      await expectLater(
        container.read(
          subjectEpisodesControllerProvider(subjectId: 1, subjectName: 'unmatched').future,
        ),
        throwsA(isA<Anime1NotFoundException>()),
      );
      verifyNever(() => api.fetchCategoryEpisodes(any()));
    });

    test('propagates a searchCategories API exception', () async {
      when(() => api.searchCategories(any())).thenThrow(Exception('network down'));

      await expectLater(
        container.read(
          subjectEpisodesControllerProvider(subjectId: 1, subjectName: 'x').future,
        ),
        throwsA(isA<Exception>()),
      );
    });
  });
}

class _MockAnime1Api extends Mock implements Anime1Api {}
