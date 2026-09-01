import 'package:animeko_flutter/data/anime1/anime1_api.dart';
import 'package:animeko_flutter/data/anime1/anime1_models.dart';
import 'package:animeko_flutter/domain/play/subject_episodes_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

void main() {
  group('matchBestCategory', () {
    test('returns null for an empty candidate list', () {
      expect(matchBestCategory([], '葬送的芙莉蓮'), isNull);
    });

    test('returns the exact title match', () {
      const target = Anime1Category(id: 1, title: '葬送的芙莉蓮');
      const other = Anime1Category(id: 2, title: '無關的番劇');
      final result = matchBestCategory([other, target], '葬送的芙莉蓮');
      expect(result, target);
    });

    test('matches case-insensitively and ignores whitespace', () {
      const target = Anime1Category(id: 1, title: 'Attack On Titan');
      final result = matchBestCategory([target], 'attack  on titan');
      expect(result, target);
    });

    test('normalizes full-width Latin characters to half-width', () {
      const target = Anime1Category(id: 1, title: 'ＦＲＩＥＲＥＮ');
      final result = matchBestCategory([target], 'FRIEREN');
      expect(result, target);
    });

    test('matches when one title contains the other', () {
      const target = Anime1Category(id: 1, title: '葬送的芙莉蓮 第二季');
      final result = matchBestCategory([target], '葬送的芙莉蓮');
      expect(result, target);
    });

    test('returns null when no candidate is similar enough', () {
      const unrelated = Anime1Category(id: 1, title: '完全無關的標題');
      final result = matchBestCategory([unrelated], '葬送的芙莉蓮');
      expect(result, isNull);
    });

    test('picks the highest-scoring candidate among several', () {
      const exact = Anime1Category(id: 1, title: '葬送的芙莉蓮');
      const partial = Anime1Category(id: 2, title: '葬送的芙莉蓮 特別篇');
      final result = matchBestCategory([partial, exact], '葬送的芙莉蓮');
      expect(result, exact);
    });

    test(
      'matches a Simplified-Chinese subject name against anime1.me\'s '
      'Traditional-Chinese title even when word order differs and the '
      'subject name carries extra subtitle text',
      () {
        // Reported bug: Bangumi's Simplified title "恶女不才..." never
        // matched anime1.me's real Traditional title "我是不才惡女"
        // because (a) 恶/惡 are different characters and (b) the extra
        // subtitle text diluted the whole-string character overlap
        // below matchThreshold even after Simplified->Traditional
        // conversion.
        const target = Anime1Category(id: 1948, title: '我是不才惡女');
        final result = matchBestCategory(
          [target],
          '恶女不才，请多关照 〇雏宫蝶鼠换身传〇',
        );
        expect(result, target);
      },
    );

    test(
      'matches a reordered core title separated from an unrelated, '
      'much longer subtitle by a delimiter',
      () {
        // Isolates the segment-splitting behavior from Simplified/
        // Traditional conversion: the core title's characters are
        // reordered (an anagram) rather than a contiguous substring, so
        // plain containment can't match it, and the long unrelated
        // subtitle after the comma would otherwise dilute the
        // whole-string overlap score below matchThreshold.
        const target = Anime1Category(id: 1, title: '太喜泼');
        final result = matchBestCategory(
          [target],
          '泼喜太，某个不相关的很长副标题内容',
        );
        expect(result, target);
      },
    );
  });

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
