// test/domain/play/subject_episodes_controller_test.dart
import 'package:animeko_flutter/domain/media/media_registry.dart';
import 'package:animeko_flutter/domain/media/media_source.dart';
import 'package:animeko_flutter/domain/play/subject_episodes_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class _FakeCandidate implements MediaCandidate {
  const _FakeCandidate(this.sourceId, this.title);
  @override
  final String sourceId;
  @override
  final String title;
}

class _FakeEpisode implements MediaEpisode {
  const _FakeEpisode(this.sourceId, this.title);
  @override
  final String sourceId;
  @override
  final String title;
}

class MockMediaSource extends Mock implements MediaSource {}

void main() {
  setUpAll(() {
    registerFallbackValue(const _FakeCandidate('fallback', 'fallback'));
  });

  group('SubjectEpisodesController', () {
    late MockMediaSource sourceA;
    late MockMediaSource sourceB;
    late ProviderContainer container;

    setUp(() {
      sourceA = MockMediaSource();
      sourceB = MockMediaSource();
      when(() => sourceA.id).thenReturn('a');
      when(() => sourceB.id).thenReturn('b');
      container = ProviderContainer(
        overrides: [mediaSourcesProvider.overrideWithValue([sourceA, sourceB])],
        // See Task 7's precedent (Plan 1c) for why riverpod 3.x's default
        // retry must be disabled for tests that expect a thrown
        // exception to propagate immediately from a bare
        // `container.read(provider.future)`.
        retry: (retryCount, error) => null,
      );
      addTearDown(container.dispose);
    });

    Future<List<MergedEpisode>> read() => container.read(
          subjectEpisodesControllerProvider(subjectId: 1, subjectName: '目标番剧').future,
        );

    test('merges episodes from every source that finds a match', () async {
      when(() => sourceA.search('目标番剧')).thenAnswer(
        (_) async => [const _FakeCandidate('a', '目标番剧')],
      );
      when(() => sourceA.listEpisodes(any())).thenAnswer(
        (_) async => [const _FakeEpisode('a', 'A的第1集')],
      );
      when(() => sourceB.search('目标番剧')).thenAnswer(
        (_) async => [const _FakeCandidate('b', '目标番剧')],
      );
      when(() => sourceB.listEpisodes(any())).thenAnswer(
        (_) async => [const _FakeEpisode('b', 'B的第1集')],
      );

      final result = await read();

      expect(result.map((e) => e.sourceId), containsAll(['a', 'b']));
      expect(result.map((e) => e.episode.title), containsAll(['A的第1集', 'B的第1集']));
    });

    test('silently ignores a source that finds no matching candidate', () async {
      when(() => sourceA.search('目标番剧')).thenAnswer((_) async => []);
      when(() => sourceB.search('目标番剧')).thenAnswer(
        (_) async => [const _FakeCandidate('b', '目标番剧')],
      );
      when(() => sourceB.listEpisodes(any())).thenAnswer(
        (_) async => [const _FakeEpisode('b', 'B的第1集')],
      );

      final result = await read();

      expect(result, hasLength(1));
      expect(result.single.sourceId, 'b');
      verifyNever(() => sourceA.listEpisodes(any()));
    });

    test('silently ignores a source whose search throws', () async {
      when(() => sourceA.search('目标番剧')).thenThrow(Exception('network down'));
      when(() => sourceB.search('目标番剧')).thenAnswer(
        (_) async => [const _FakeCandidate('b', '目标番剧')],
      );
      when(() => sourceB.listEpisodes(any())).thenAnswer(
        (_) async => [const _FakeEpisode('b', 'B的第1集')],
      );

      final result = await read();

      expect(result, hasLength(1));
      expect(result.single.sourceId, 'b');
    });

    test('throws MediaNotFoundException when every source finds nothing', () async {
      when(() => sourceA.search(any())).thenAnswer((_) async => []);
      when(() => sourceB.search(any())).thenThrow(Exception('also down'));

      await expectLater(read(), throwsA(isA<MediaNotFoundException>()));
    });

    test('queries all sources concurrently, not sequentially', () async {
      final order = <String>[];
      when(() => sourceA.search(any())).thenAnswer((_) async {
        order.add('a-start');
        await Future<void>.delayed(const Duration(milliseconds: 20));
        order.add('a-end');
        return [];
      });
      when(() => sourceB.search(any())).thenAnswer((_) async {
        order.add('b-start');
        return [];
      });

      await expectLater(read(), throwsA(isA<MediaNotFoundException>()));

      // If the sources were queried sequentially, 'b-start' could only
      // appear after 'a-end'. Concurrent querying starts both before
      // either finishes.
      expect(order.indexOf('b-start'), lessThan(order.indexOf('a-end')));
    });
  });
}
