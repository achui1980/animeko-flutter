import 'package:animeko_flutter/domain/media/media_source.dart';
import 'package:animeko_flutter/domain/play/subject_episodes_controller.dart';
import 'package:animeko_flutter/ui/subject/episode_source_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeEpisode implements MediaEpisode {
  const _FakeEpisode({required this.sourceId, required this.title});

  @override
  final String sourceId;

  @override
  final String title;
}

class _FakeSource implements MediaSource {
  const _FakeSource({required this.id, required this.displayName});

  @override
  final String id;

  @override
  final String displayName;

  @override
  Future<List<MediaCandidate>> search(String title) async => const [];

  @override
  Future<List<MediaEpisode>> listEpisodes(MediaCandidate candidate) async =>
      const [];

  @override
  Future<MediaPlaybackSource> resolvePlayback(MediaEpisode episode) {
    throw UnimplementedError();
  }
}

void main() {
  final episode1 = MergedEpisode(
    episode: const _FakeEpisode(sourceId: 'anime1', title: '第1集'),
    sourceId: 'anime1',
  );
  final episode2 = MergedEpisode(
    episode: const _FakeEpisode(sourceId: 'xifan', title: '第1集'),
    sourceId: 'xifan',
  );
  const sources = [
    _FakeSource(id: 'anime1', displayName: 'anime1.me'),
    _FakeSource(id: 'xifan', displayName: '稀饭动漫'),
  ];

  group('sourceLabel', () {
    test('falls back to the raw sourceId when no source matches', () {
      expect(sourceLabel(const [], 'unknown'), 'unknown');
    });

    test('returns the matching source displayName', () {
      expect(sourceLabel(sources, 'anime1'), 'anime1.me');
    });
  });

  group('EpisodeSourceGrid', () {
    testWidgets('shows an "全部" chip plus one chip per distinct source', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EpisodeSourceGrid(
              episodes: [episode1, episode2],
              sources: sources,
              onEpisodeSelected: (_) {},
            ),
          ),
        ),
      );

      expect(find.widgetWithText(ChoiceChip, '全部'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'anime1.me'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, '稀饭动漫'), findsOneWidget);
      expect(find.text('第1集'), findsNWidgets(2));
    });

    testWidgets('tapping a source chip filters the episode grid', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EpisodeSourceGrid(
              episodes: [episode1, episode2],
              sources: sources,
              onEpisodeSelected: (_) {},
            ),
          ),
        ),
      );

      await tester.tap(find.widgetWithText(ChoiceChip, '稀饭动漫'));
      await tester.pump();

      expect(find.text('第1集'), findsOneWidget);
    });

    testWidgets('tapping "全部" after filtering restores every episode', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EpisodeSourceGrid(
              episodes: [episode1, episode2],
              sources: sources,
              onEpisodeSelected: (_) {},
            ),
          ),
        ),
      );

      await tester.tap(find.widgetWithText(ChoiceChip, '稀饭动漫'));
      await tester.pump();
      await tester.tap(find.widgetWithText(ChoiceChip, '全部'));
      await tester.pump();

      expect(find.text('第1集'), findsNWidgets(2));
    });

    testWidgets('highlights the current episode with a filled pill', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EpisodeSourceGrid(
              episodes: [episode1, episode2],
              sources: sources,
              onEpisodeSelected: (_) {},
              currentEpisode: episode2,
            ),
          ),
        ),
      );

      expect(find.widgetWithText(FilledButton, '第1集'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, '第1集'), findsOneWidget);
    });

    testWidgets('tapping an episode calls onEpisodeSelected with that episode', (
      tester,
    ) async {
      MergedEpisode? selected;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EpisodeSourceGrid(
              episodes: [episode1],
              sources: sources,
              onEpisodeSelected: (episode) => selected = episode,
            ),
          ),
        ),
      );

      await tester.tap(find.text('第1集'));

      expect(selected, same(episode1));
    });
  });
}
