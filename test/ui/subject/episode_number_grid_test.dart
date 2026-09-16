import 'package:animeko_flutter/data/subject/subject_episode_models.dart';
import 'package:animeko_flutter/domain/media/media_source.dart';
import 'package:animeko_flutter/domain/play/subject_episodes_controller.dart';
import 'package:animeko_flutter/ui/subject/episode_number_grid.dart';
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

SubjectEpisode ep(int number, {String nameCn = ''}) => SubjectEpisode(
  episodeId: number,
  sort: number,
  ep: '$number',
  type: 'MAIN',
  name: 'E$number',
  nameCn: nameCn,
  airdate: '',
);

void main() {
  final episodes = [ep(1, nameCn: '第1集'), ep(2, nameCn: '第2集')];

  Widget grid(
    List<SubjectEpisode> episodes, {
    AsyncValue<List<MergedEpisode>> merged = const AsyncLoading(),
    void Function(int ordinalIndex, SubjectEpisode episode)? onTap,
  }) => MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: EpisodeNumberGrid(
          episodes: episodes,
          mergedEpisodesAsync: merged,
          onEpisodeTap: onTap ?? (_, _) {},
        ),
      ),
    ),
  );

  testWidgets('renders one button per episode, labeled by sort', (
    tester,
  ) async {
    await tester.pumpWidget(grid(episodes));

    expect(find.text('01'), findsOneWidget);
    expect(find.text('02'), findsOneWidget);
  });

  testWidgets(
    'tapping a button calls onEpisodeTap with the right ordinal index and episode',
    (tester) async {
      int? tappedIndex;
      SubjectEpisode? tappedEpisode;
      await tester.pumpWidget(
        grid(
          episodes,
          onTap: (index, episode) {
            tappedIndex = index;
            tappedEpisode = episode;
          },
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

      await tester.pumpWidget(grid(episodes, merged: merged));

      // Ordinal 0 (episode "01") has a match -> normal button. Ordinal 1
      // (episode "02") has no match -> dimmed OutlinedButton, still present
      // and tappable.
      expect(find.widgetWithText(OutlinedButton, '02'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, '01'), findsNothing);
    },
  );

  testWidgets(
    'dims all buttons (OutlinedButton) when mergedEpisodesAsync settled '
    'with an error and no data (e.g. no scraper source matched at all)',
    (tester) async {
      final merged = AsyncValue<List<MergedEpisode>>.error(
        Exception('no source'),
        StackTrace.current,
      );

      await tester.pumpWidget(grid(episodes, merged: merged));

      // Settled-with-error-and-no-data is a deterministic "no source will
      // ever be found" outcome, distinct from still-loading -- every button
      // should render dimmed, matching the no-match case above.
      expect(find.widgetWithText(OutlinedButton, '01'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, '02'), findsOneWidget);
    },
  );

  testWidgets('shows the title snippet below the number', (tester) async {
    await tester.pumpWidget(grid(episodes));

    expect(find.text('第1集'), findsOneWidget);
    expect(find.text('第2集'), findsOneWidget);
  });

  testWidgets('renders number-only (no title line) when displayName is empty', (
    tester,
  ) async {
    const untitled = SubjectEpisode(
      episodeId: 11,
      sort: 11,
      ep: '11',
      type: 'MAIN',
      name: '',
      nameCn: '',
      airdate: '',
    );

    await tester.pumpWidget(grid(const [untitled]));

    expect(find.text('11'), findsOneWidget);
    // No second, empty/blank Text line should be rendered for this button.
    expect(
      find.descendant(
        of: find.byType(FilledButton),
        matching: find.byType(Text),
      ),
      findsOneWidget,
    );
  });

  // Segmented rendering exists because the episode list is no longer capped
  // at 100 by the old api.bgm.tv `limit=100`: 航海王 returns 1155 episodes,
  // and the detail screen builds this grid eagerly inside a non-lazy
  // ListView, so every button would be laid out at once.
  group('segmented rendering', () {
    final many = [for (var i = 1; i <= 250; i++) ep(i)];

    testWidgets('shows no range selector when the list fits in one chunk', (
      tester,
    ) async {
      await tester.pumpWidget(
        grid([for (var i = 1; i <= EpisodeNumberGrid.chunkSize; i++) ep(i)]),
      );

      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.text('01'), findsOneWidget);
      expect(find.text('100'), findsOneWidget);
    });

    testWidgets(
      'shows one range chip per chunk, including a partial last one',
      (tester) async {
        await tester.pumpWidget(grid(many));

        expect(find.byType(ChoiceChip), findsNWidgets(3));
        expect(find.text('1-100'), findsOneWidget);
        expect(find.text('101-200'), findsOneWidget);
        expect(find.text('201-250'), findsOneWidget);
      },
    );

    testWidgets('renders only the first chunk initially', (tester) async {
      await tester.pumpWidget(grid(many));

      expect(find.text('01'), findsOneWidget);
      expect(find.text('100'), findsOneWidget);
      expect(find.text('101'), findsNothing);
      expect(find.text('250'), findsNothing);
    });

    testWidgets('selecting a later range swaps which episodes are rendered', (
      tester,
    ) async {
      await tester.pumpWidget(grid(many));

      await tester.tap(find.text('101-200'));
      await tester.pump();

      expect(find.text('101'), findsOneWidget);
      expect(find.text('200'), findsOneWidget);
      expect(find.text('01'), findsNothing);
      expect(find.text('100'), findsNothing);
    });

    // The global ordinal index is what maps a grid position back to a
    // scraper episode (see EpisodeSourceIndex); passing a within-chunk index
    // would silently play the wrong episode.
    testWidgets('passes the global ordinal index from a later chunk', (
      tester,
    ) async {
      int? tappedIndex;
      SubjectEpisode? tappedEpisode;
      await tester.pumpWidget(
        grid(
          many,
          onTap: (index, episode) {
            tappedIndex = index;
            tappedEpisode = episode;
          },
        ),
      );

      await tester.tap(find.text('101-200'));
      await tester.pump();
      await tester.tap(find.text('101'));

      expect(tappedIndex, 100);
      expect(tappedEpisode, many[100]);
    });

    testWidgets('dims buttons in a later chunk by their global ordinal', (
      tester,
    ) async {
      // 101 scraper episodes -> global ordinals 0..100 have a match, so in
      // the second chunk only episode 101 (ordinal 100) stays undimmed.
      final merged = AsyncData<List<MergedEpisode>>([
        for (var i = 1; i <= 101; i++)
          MergedEpisode(
            episode: _FakeEpisode(sourceId: 'anime1', title: '第$i集'),
            sourceId: 'anime1',
          ),
      ]);
      await tester.pumpWidget(grid(many, merged: merged));

      await tester.tap(find.text('101-200'));
      await tester.pump();

      expect(find.widgetWithText(OutlinedButton, '101'), findsNothing);
      expect(find.widgetWithText(OutlinedButton, '102'), findsOneWidget);
    });

    testWidgets('falls back to the first chunk when the list shrinks', (
      tester,
    ) async {
      await tester.pumpWidget(grid(many));
      await tester.tap(find.text('201-250'));
      await tester.pump();
      expect(find.text('201'), findsOneWidget);

      // e.g. the user pulls to refresh and the backend returns a shorter
      // list -- the previously selected chunk no longer exists.
      await tester.pumpWidget(grid([ep(1), ep(2)]));

      expect(find.text('01'), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNothing);
    });
  });

  testWidgets('a half-episode sort (1.5) does not collide with a neighboring '
      'integer sort (2) -- both render distinguishably', (tester) async {
    final half = SubjectEpisode(
      episodeId: 100,
      sort: 1.5,
      ep: '1.5',
      type: 'MAIN',
      name: 'E1.5',
      nameCn: '',
      airdate: '',
    );

    await tester.pumpWidget(grid([half, ep(2)]));

    // The half-episode keeps its fractional label (not rounded away),
    // and the integer-sort episode keeps its normal 2-digit label --
    // the old `.round().toString().padLeft(2, '0')` collapsed both to
    // "02", making them visually indistinguishable.
    expect(find.text('1.5'), findsOneWidget);
    expect(find.text('02'), findsOneWidget);
    // The private _EpisodeNumberButton type blocks widget-type-scoped
    // finders, so assert the total button count rather than trying to
    // disambiguate "the sort:2 button" from "the sort:1.5 button" by type.
    expect(
      find.byWidgetPredicate((w) => w is FilledButton || w is OutlinedButton),
      findsNWidgets(2),
    );
  });
}
