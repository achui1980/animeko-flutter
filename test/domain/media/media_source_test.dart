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

class _FakePlaybackSource implements MediaPlaybackSource {
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
  Future<List<MediaCandidate>> search(String title) async =>
      [const _FakeCandidate('Fake Anime')];
  @override
  Future<List<MediaEpisode>> listEpisodes(MediaCandidate candidate) async =>
      [const _FakeEpisode('Episode 1')];
  @override
  Future<MediaPlaybackSource> resolvePlayback(MediaEpisode episode) async =>
      const _FakePlaybackSource();
}

void main() {
  test('a MediaSource implementation can search, list episodes, and resolve playback', () async {
    final source = _FakeSource();

    final candidates = await source.search('Fake Anime');
    expect(candidates.single.title, 'Fake Anime');
    expect(candidates.single.sourceId, 'fake');

    final episodes = await source.listEpisodes(candidates.single);
    expect(episodes.single.title, 'Episode 1');

    final playback = await source.resolvePlayback(episodes.single);
    expect(playback.url, 'https://example.com/video.mp4');
    expect(playback.headers, isEmpty);
  });
}
