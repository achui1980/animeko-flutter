import 'package:animeko_flutter/data/rss/rss_media_source.dart';
import 'package:animeko_flutter/domain/media/media_source.dart';
import 'package:animeko_flutter/domain/play/episode_source_matcher.dart';
import 'package:animeko_flutter/domain/play/subject_episodes_controller.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeEpisode implements MediaEpisode {
  const _FakeEpisode(this.sourceId, this.title);
  @override
  final String sourceId;
  @override
  final String title;
}

void main() {
  group('matchEpisodeSources', () {
    test('returns one match per source at the same ordinal position', () {
      final merged = [
        const MergedEpisode(episode: _FakeEpisode('a', 'A第1集'), sourceId: 'a'),
        const MergedEpisode(episode: _FakeEpisode('a', 'A第2集'), sourceId: 'a'),
        const MergedEpisode(episode: _FakeEpisode('b', 'B第1集'), sourceId: 'b'),
        const MergedEpisode(episode: _FakeEpisode('b', 'B第2集'), sourceId: 'b'),
      ];

      final result = matchEpisodeSources(ordinalIndex: 1, allMerged: merged);

      expect(result.map((e) => e.episode.title), ['A第2集', 'B第2集']);
    });

    test('skips a source that has fewer episodes than ordinalIndex', () {
      final merged = [
        const MergedEpisode(episode: _FakeEpisode('a', 'A第1集'), sourceId: 'a'),
        const MergedEpisode(episode: _FakeEpisode('b', 'B第1集'), sourceId: 'b'),
        const MergedEpisode(episode: _FakeEpisode('b', 'B第2集'), sourceId: 'b'),
      ];

      final result = matchEpisodeSources(ordinalIndex: 1, allMerged: merged);

      expect(result.map((e) => e.episode.title), ['B第2集']);
    });

    test('returns an empty list when no source has an episode at that position', () {
      final merged = [
        const MergedEpisode(episode: _FakeEpisode('a', 'A第1集'), sourceId: 'a'),
      ];

      final result = matchEpisodeSources(ordinalIndex: 5, allMerged: merged);

      expect(result, isEmpty);
    });

    test('returns an empty list for an empty input list', () {
      final result = matchEpisodeSources(ordinalIndex: 0, allMerged: const []);

      expect(result, isEmpty);
    });

    test('matches an RssEpisode by episodeNumber rather than by position', () {
      final rssEpisode10 = RssEpisode(
        sourceId: 'mikan',
        title: '第 10 集',
        episodeNumber: 10,
        releases: const [],
      );
      final rssEpisode11 = RssEpisode(
        sourceId: 'mikan',
        title: '第 11 集',
        episodeNumber: 11,
        releases: const [],
      );
      // Deliberately out of position order: index 0 is episode 11, index 1 is
      // episode 10, to prove matching is by episodeNumber, not list position.
      final merged = [
        MergedEpisode(episode: rssEpisode11, sourceId: 'mikan'),
        MergedEpisode(episode: rssEpisode10, sourceId: 'mikan'),
      ];

      // Bangumi grid ordinalIndex 9 (0-based) == episode number 10 (1-based).
      final matches = matchEpisodeSources(ordinalIndex: 9, allMerged: merged);

      expect(matches, hasLength(1));
      expect((matches.single.episode as RssEpisode).episodeNumber, 10);
    });

    test('returns no match for an RssEpisode source when the requested episode '
        'number was never published', () {
      final rssEpisode5 = RssEpisode(
        sourceId: 'mikan',
        title: '第 5 集',
        episodeNumber: 5,
        releases: const [],
      );
      final merged = [MergedEpisode(episode: rssEpisode5, sourceId: 'mikan')];

      // ordinalIndex 6 -> wanted episode number 7, which does not exist.
      final matches = matchEpisodeSources(ordinalIndex: 6, allMerged: merged);

      expect(matches, isEmpty);
    });

    test('non-RssEpisode sources continue to match purely by position', () {
      const episodeA = _FakeEpisode('anime1', 'Episode A');
      const episodeB = _FakeEpisode('anime1', 'Episode B');
      final merged = [
        MergedEpisode(episode: episodeA, sourceId: 'anime1'),
        MergedEpisode(episode: episodeB, sourceId: 'anime1'),
      ];

      final matches = matchEpisodeSources(ordinalIndex: 1, allMerged: merged);

      expect(matches, hasLength(1));
      expect(matches.single.episode.title, 'Episode B');
    });
  });
}
