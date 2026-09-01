// test/domain/play/episode_play_controller_test.dart
import 'package:animeko_flutter/data/anime1/anime1_api.dart';
import 'package:animeko_flutter/data/anime1/anime1_models.dart';
import 'package:animeko_flutter/domain/play/episode_play_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class _MockAnime1Api extends Mock implements Anime1Api {}

void main() {
  group('EpisodePlayController', () {
    late _MockAnime1Api api;
    late ProviderContainer container;

    setUp(() {
      api = _MockAnime1Api();
      container = ProviderContainer(
        overrides: [anime1ApiProvider.overrideWithValue(api)],
        // riverpod 3.x's default `retry` re-runs a failed build() several
        // times with exponential backoff (see
        // `ProviderContainer.defaultRetry`), which races with autoDispose
        // teardown for the "propagates ..." test below since it reads via a
        // bare `container.read(...future)` without a persistent listener.
        // Disable it so failures surface immediately instead of a disposal
        // error/hang.
        retry: (retryCount, error) => null,
      );
      addTearDown(container.dispose);
    });

    test('resolves the playback source via Anime1Api', () async {
      when(() => api.resolvePlaybackUrl('https://anime1.me/?p=1')).thenAnswer(
        (_) async => const Anime1PlaybackSource(url: 'https://video.example.com/1.mp4'),
      );

      final result = await container.read(
        episodePlayControllerProvider(episodePageUrl: 'https://anime1.me/?p=1').future,
      );

      expect(result.url, 'https://video.example.com/1.mp4');
    });

    test('propagates a resolvePlaybackUrl exception', () async {
      when(() => api.resolvePlaybackUrl(any())).thenThrow(const FormatException('bad'));

      await expectLater(
        container.read(
          episodePlayControllerProvider(episodePageUrl: 'https://anime1.me/?p=1').future,
        ),
        throwsFormatException,
      );
    });
  });
}
