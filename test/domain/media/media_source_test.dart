import 'package:animeko_flutter/domain/media/media_source.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeCandidate implements MediaCandidate {
  const _FakeCandidate(this.title);
  @override
  final String title;
  @override
  String get sourceId => 'fake';
}

class _FakeEpisode implements MediaEpisode {
  const _FakeEpisode(this.title);
  @override
  final String title;
  @override
  String get sourceId => 'fake';
}

class _FakePlaybackSource extends MediaPlaybackSource {
  const _FakePlaybackSource();
  @override
  String get url => 'https://example.com/video.mp4';
  @override
  Map<String, String> get headers => const {};
}

class _FakeSource implements MediaSource {
  @override
  String get id => 'fake';
  @override
  String get displayName => 'Fake Source';
  @override
  Future<List<MediaCandidate>> search(String title, {int? subjectId}) async => [
    const _FakeCandidate('Fake Anime'),
  ];
  @override
  Future<List<MediaEpisode>> listEpisodes(MediaCandidate candidate) async => [
    const _FakeEpisode('Episode 1'),
  ];
  @override
  Future<List<MediaPlaybackSource>> resolvePlayback(
    MediaEpisode episode,
  ) async => const [_FakePlaybackSource()];
}

void main() {
  test(
    'a MediaSource implementation can search, list episodes, and resolve playback',
    () async {
      final source = _FakeSource();

      final candidates = await source.search('Fake Anime');
      expect(candidates.single.title, 'Fake Anime');
      expect(candidates.single.sourceId, 'fake');

      final episodes = await source.listEpisodes(candidates.single);
      expect(episodes.single.title, 'Episode 1');

      final playback = await source.resolvePlayback(episodes.single);
      expect(playback.single.url, 'https://example.com/video.mp4');
      expect(playback.single.headers, isEmpty);
    },
  );

  test('MediaPlaybackSource.prepare() defaults to returning url', () async {
    const source = _FakePlaybackSource();
    expect(await source.prepare(), 'https://example.com/video.mp4');
  });

  test('MediaPlaybackSource.dispose() defaults to a no-op', () async {
    const source = _FakePlaybackSource();
    await expectLater(source.dispose(), completes);
  });

  test('MediaPlaybackSource.label defaults to null', () async {
    const source = _FakePlaybackSource();
    expect(source.label, isNull);
  });

  // The default must stay false: `PlayerScreen._configureProxy` forwards
  // the app's proxy for every candidate that doesn't opt out, and 稀饭动漫's
  // CDN is only reachable *through* the proxy. Only sources measured to
  // need a direct connection override this (see `AgedmPlaybackSource`).
  test('MediaPlaybackSource.prefersDirectConnection defaults to false', () {
    const source = _FakePlaybackSource();
    expect(source.prefersDirectConnection, isFalse);
  });
}
