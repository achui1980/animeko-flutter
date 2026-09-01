// test/domain/play/episode_play_controller_test.dart
import 'package:animeko_flutter/domain/media/media_registry.dart';
import 'package:animeko_flutter/domain/media/media_source.dart';
import 'package:animeko_flutter/domain/play/episode_play_controller.dart';
import 'package:animeko_flutter/domain/play/subject_episodes_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class _FakeEpisode implements MediaEpisode {
  const _FakeEpisode(this.sourceId, this.title);
  @override
  final String sourceId;
  @override
  final String title;
}

class _FakePlaybackSource implements MediaPlaybackSource {
  const _FakePlaybackSource(this.url);
  @override
  final String url;
  @override
  Map<String, String> get headers => const {};
}

class MockMediaSource extends Mock implements MediaSource {}

void main() {
  setUpAll(() {
    registerFallbackValue(const _FakeEpisode('fallback', 'fallback'));
  });

  group('EpisodePlayController', () {
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
        retry: (retryCount, error) => null,
      );
      addTearDown(container.dispose);
    });

    test('resolves via the MediaSource matching the episode\'s sourceId', () async {
      final episode = MergedEpisode(episode: const _FakeEpisode('b', 'ep1'), sourceId: 'b');
      when(() => sourceB.resolvePlayback(episode.episode)).thenAnswer(
        (_) async => const _FakePlaybackSource('https://example.com/v.mp4'),
      );

      final source = await container.read(
        episodePlayControllerProvider(episode: episode).future,
      );

      expect(source.url, 'https://example.com/v.mp4');
      verifyNever(() => sourceA.resolvePlayback(any()));
    });

    test('propagates a resolvePlayback exception', () async {
      final episode = MergedEpisode(episode: const _FakeEpisode('a', 'ep1'), sourceId: 'a');
      when(() => sourceA.resolvePlayback(episode.episode)).thenThrow(Exception('resolve failed'));

      await expectLater(
        container.read(episodePlayControllerProvider(episode: episode).future),
        throwsA(isA<Exception>()),
      );
    });
  });
}
