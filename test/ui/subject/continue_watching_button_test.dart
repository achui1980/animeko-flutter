import 'package:animeko_flutter/data/subject/subject_api.dart';
import 'package:animeko_flutter/data/subject/subject_episode_models.dart';
import 'package:animeko_flutter/data/subject/subject_models.dart';
import 'package:animeko_flutter/domain/play/subject_episodes_controller.dart';
import 'package:animeko_flutter/domain/subject/continue_watching_controller.dart';
import 'package:animeko_flutter/ui/subject/continue_watching_button.dart';
import 'package:animeko_flutter/ui/subject/episode_playback_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockSubjectApi extends Mock implements SubjectApi {}

/// Serves a fixed scraper result set so `EpisodePlaybackSheet` resolves
/// without touching the network.
class StubEpisodesController extends SubjectEpisodesController {
  StubEpisodesController(this.merged);

  final List<MergedEpisode> merged;

  @override
  Future<List<MergedEpisode>> build({
    required int subjectId,
    required String subjectName,
  }) async => merged;
}

/// `episodeId` and `sort` are deliberately given different values: they are
/// the two fields this widget juggles (it matches the target on `episodeId`
/// and renders the label from `sort`), so keeping them distinct stops an
/// assertion that reads the wrong one from passing by coincidence.
SubjectEpisode ep(int n) => SubjectEpisode(
  episodeId: 100 + n,
  sort: n,
  ep: '$n',
  type: 'MAIN',
  name: 'E$n',
  nameCn: '第$n集',
  airdate: '2026-01-01',
);

SubjectDetail detailWithEpisodes() => SubjectDetail(
  id: 1,
  name: 'A',
  nameCn: 'A-cn',
  summary: 'summary',
  airDate: '2026-01-01',
  tags: const [],
  selfRating: const SelfRating(score: 0, tags: [], isPrivate: false),
  episodes: [ep(1), ep(2), ep(3)],
);

void main() {
  late MockSubjectApi api;

  setUp(() {
    api = MockSubjectApi();
    when(() => api.getSubject(1)).thenAnswer((_) async => detailWithEpisodes());
  });

  Future<void> pumpButton(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [subjectApiProvider.overrideWithValue(api)],
        child: const MaterialApp(
          home: Scaffold(
            body: ContinueWatchingButton(subjectId: 1, subjectName: 'A-cn'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows 开始观看 when there is no stored episode', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await pumpButton(tester);

    expect(find.text('开始观看'), findsOneWidget);
  });

  testWidgets('shows 继续观看 第 N 集 for a stored episode', (tester) async {
    SharedPreferences.setMockInitialValues({'lastPlayedEpisode:1': 103});

    await pumpButton(tester);

    expect(find.text('继续观看 第 3 集'), findsOneWidget);
  });

  testWidgets('shows 开始观看 when the stored episode no longer exists', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'lastPlayedEpisode:1': 999});

    await pumpButton(tester);

    expect(find.text('开始观看'), findsOneWidget);
  });

  testWidgets('renders nothing when the subject has no episodes', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    when(() => api.getSubject(1)).thenAnswer(
      (_) async => SubjectDetail(
        id: 1,
        name: 'A',
        nameCn: 'A-cn',
        summary: 'summary',
        airDate: '2026-01-01',
        tags: const [],
        selfRating: const SelfRating(score: 0, tags: [], isPrivate: false),
        episodes: const [],
      ),
    );

    await pumpButton(tester);

    // Asserted on the labels rather than on the button type: a negative
    // `find.byType(FilledButton)` is satisfied by anything that is not a
    // `FilledButton`, so it stays green both when the button is merely
    // rendered as another widget type and when this guard stops hiding
    // anything at all.
    expect(find.text('开始观看'), findsNothing);
    expect(find.textContaining('继续观看'), findsNothing);
  });

  // Covers the stale-target guard: `continueWatchingProvider` normally
  // picks the target out of the very list this widget searches, but the
  // list settles one build before the provider that depends on it
  // recomputes, so a refresh can pair a new list with the old target.
  // Overriding the provider is the only way to reach that pairing
  // deterministically.
  testWidgets('renders nothing when the target is absent from the list', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          subjectApiProvider.overrideWithValue(api),
          continueWatchingProvider(
            subjectId: 1,
          ).overrideWith((ref) async => ep(999)),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ContinueWatchingButton(subjectId: 1, subjectName: 'A-cn'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('开始观看'), findsNothing);
    expect(find.textContaining('继续观看'), findsNothing);
  });

  // Covers what the button hands to `EpisodePlaybackSheet`: the target
  // episode, and its position in the full main-episode list (the
  // `ordinalIndex` contract playback-source matching keys on). Asserting on
  // the widget the button constructs, rather than on how that widget renders,
  // keeps this test independent of the sheet's own layout.
  //
  // The stub keeps the real scraper out of this test: the sheet watches
  // `subjectEpisodesControllerProvider`, whose real implementation fans out
  // over `mediaSourcesProvider`'s three live sources
  // (`lib/domain/media/media_registry.dart:147`). The test does still pass
  // without the override (verified), but only by relying on how those
  // unstubbed requests happen to behave in the harness. An empty list is
  // enough because the assertions read the widget's arguments rather than
  // the rows it renders.
  testWidgets('opens the playback sheet for the target at its ordinal index', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'lastPlayedEpisode:1': 103});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          subjectApiProvider.overrideWithValue(api),
          subjectEpisodesControllerProvider(
            subjectId: 1,
            subjectName: 'A-cn',
          ).overrideWith(() => StubEpisodesController(const [])),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ContinueWatchingButton(subjectId: 1, subjectName: 'A-cn'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('继续观看 第 3 集'));
    await tester.pumpAndSettle();

    final sheet = tester.widget<EpisodePlaybackSheet>(
      find.byType(EpisodePlaybackSheet),
    );
    expect(sheet.ordinalIndex, 2);
    expect(sheet.episode.episodeId, 103);
    expect(sheet.subjectName, 'A-cn');
  });
}
