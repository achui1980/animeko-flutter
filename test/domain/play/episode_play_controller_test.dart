// test/domain/play/episode_play_controller_test.dart
import 'package:animeko_flutter/data/download/downloaded_episode_repository.dart';
import 'package:animeko_flutter/data/local_database.dart';
import 'package:animeko_flutter/domain/download/local_file_playback_source.dart';
import 'package:animeko_flutter/domain/media/media_registry.dart';
import 'package:animeko_flutter/domain/media/media_source.dart';
import 'package:animeko_flutter/domain/play/episode_play_controller.dart';
import 'package:animeko_flutter/domain/play/subject_episodes_controller.dart';
import 'package:drift/native.dart';
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

class _FakePlaybackSource extends MediaPlaybackSource {
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
    late AppDatabase db;
    late DownloadedEpisodeRepository repository;

    setUp(() {
      sourceA = MockMediaSource();
      sourceB = MockMediaSource();
      db = AppDatabase(NativeDatabase.memory());
      repository = DownloadedEpisodeRepository(db);
      when(() => sourceA.id).thenReturn('a');
      when(() => sourceB.id).thenReturn('b');
      container = ProviderContainer(
        overrides: [
          mediaSourcesProvider.overrideWithValue([sourceA, sourceB]),
          downloadedEpisodeRepositoryProvider.overrideWithValue(repository),
        ],
        retry: (retryCount, error) => null,
      );
      addTearDown(container.dispose);
      addTearDown(db.close);
    });

    test(
      'resolves via the MediaSource matching the episode\'s sourceId',
      () async {
        final episode = MergedEpisode(
          episode: const _FakeEpisode('b', 'ep1'),
          sourceId: 'b',
        );
        when(() => sourceB.resolvePlayback(episode.episode)).thenAnswer(
          (_) async => const [_FakePlaybackSource('https://example.com/v.mp4')],
        );

        final source = await container.read(
          episodePlayControllerProvider(episode: episode, subjectId: 1).future,
        );

        expect(source, hasLength(1));
        expect(source.first.url, 'https://example.com/v.mp4');
        verifyNever(() => sourceA.resolvePlayback(any()));
      },
    );

    test('propagates a resolvePlayback exception', () async {
      final episode = MergedEpisode(
        episode: const _FakeEpisode('a', 'ep1'),
        sourceId: 'a',
      );
      when(
        () => sourceA.resolvePlayback(episode.episode),
      ).thenThrow(Exception('resolve failed'));

      await expectLater(
        container.read(
          episodePlayControllerProvider(episode: episode, subjectId: 1).future,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test(
      'inserts a completed local download before resolved candidates',
      () async {
        final episode = MergedEpisode(
          episode: const _FakeEpisode('b', '1'),
          sourceId: 'b',
        );
        await repository.upsert(
          const DownloadedEpisodeWrite(
            sourceId: 'xifan',
            subjectId: 42,
            episodeKey: '42::b::1',
            subjectName: '测试番剧',
            episodeLabel: '1',
            localPath: '/offline/video.mp4',
            format: 'mp4',
            status: DownloadStatus.completed,
          ),
        );
        when(() => sourceB.resolvePlayback(episode.episode)).thenAnswer(
          (_) async => const [_FakePlaybackSource('https://cdn/video.mp4')],
        );
        final candidates = await container.read(
          episodePlayControllerProvider(episode: episode, subjectId: 42).future,
        );
        expect(candidates.first, isA<LocalFilePlaybackSource>());
        expect(candidates.first.url, '/offline/video.mp4');
      },
    );

    test(
      'finds a local download made from a different source than the one '
      'currently being played (design doc 2.4 -- cross-source lookup by '
      'subjectId+title, not the exact episodeKey)',
      () async {
        // Playing from source "b" (e.g. mikan, not downloadable), but the
        // completed download on disk was auto-selected from source "a"
        // (e.g. anime1) for the same subject+title -- its episodeKey
        // therefore does NOT match `'42::b::1'`.
        final episode = MergedEpisode(
          episode: const _FakeEpisode('b', '1'),
          sourceId: 'b',
        );
        await repository.upsert(
          const DownloadedEpisodeWrite(
            sourceId: 'a',
            subjectId: 42,
            episodeKey: '42::a::1',
            subjectName: '测试番剧',
            episodeLabel: '1',
            localPath: '/offline/video.mp4',
            format: 'mp4',
            status: DownloadStatus.completed,
          ),
        );
        when(() => sourceB.resolvePlayback(episode.episode)).thenAnswer(
          (_) async => const [_FakePlaybackSource('https://cdn/video.mp4')],
        );

        final candidates = await container.read(
          episodePlayControllerProvider(episode: episode, subjectId: 42).future,
        );

        expect(candidates.first, isA<LocalFilePlaybackSource>());
        expect(candidates.first.url, '/offline/video.mp4');
      },
    );
  });
}
