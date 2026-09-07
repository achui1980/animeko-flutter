import 'package:animeko_flutter/data/subject/bangumi_episode_models.dart';
import 'package:animeko_flutter/domain/media/media_source.dart';
import 'package:animeko_flutter/domain/play/subject_episodes_controller.dart';
import 'package:animeko_flutter/ui/subject/bangumi_episode_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeEpisode implements MediaEpisode {
  const _FakeEpisode({required this.sourceId, required this.title});
  @override
  final String sourceId;
  @override
  final String title;
}

void main() {
  const episodes = [
    BangumiEpisode(
      id: 1,
      sort: 1,
      name: 'A',
      nameCn: '第1集',
      airdate: '',
      type: 0,
    ),
    BangumiEpisode(
      id: 2,
      sort: 2,
      name: 'B',
      nameCn: '第2集',
      airdate: '',
      type: 0,
    ),
  ];

  testWidgets('renders one button per episode, labeled by sort', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BangumiEpisodeGrid(
            episodes: episodes,
            mergedEpisodesAsync: const AsyncLoading(),
            onEpisodeTap: (_, _) {},
          ),
        ),
      ),
    );
    expect(find.text('01'), findsOneWidget);
    expect(find.text('02'), findsOneWidget);
  });

  testWidgets(
    'tapping a button calls onEpisodeTap with the right ordinal index and episode',
    (tester) async {
      int? tappedIndex;
      BangumiEpisode? tappedEpisode;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BangumiEpisodeGrid(
              episodes: episodes,
              mergedEpisodesAsync: const AsyncLoading(),
              onEpisodeTap: (index, episode) {
                tappedIndex = index;
                tappedEpisode = episode;
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('02'));
      expect(tappedIndex, 1);
      expect(tappedEpisode, episodes[1]);
    },
  );

  testWidgets(
    'dims a button (OutlinedButton) when no scraper source matched it',
    (tester) async {
      final merged = AsyncData<List<MergedEpisode>>([
        MergedEpisode(
          episode: const _FakeEpisode(sourceId: 'anime1', title: '第1集'),
          sourceId: 'anime1',
        ),
      ]);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BangumiEpisodeGrid(
              episodes: episodes,
              mergedEpisodesAsync: merged,
              onEpisodeTap: (_, _) {},
            ),
          ),
        ),
      );
      // Ordinal 0 (episode "01") has a match -> normal button. Ordinal 1
      // (episode "02") has no match -> dimmed OutlinedButton, still
      // present and tappable.
      expect(find.widgetWithText(OutlinedButton, '02'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, '01'), findsNothing);
    },
  );
}
