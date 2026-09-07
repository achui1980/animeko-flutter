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
  });
}
