import 'package:animeko_flutter/data/subject/subject_api.dart';
import 'package:animeko_flutter/data/subject/subject_episode_models.dart';
import 'package:animeko_flutter/data/subject/subject_models.dart';
import 'package:animeko_flutter/domain/media/media_registry.dart';
import 'package:animeko_flutter/domain/media/media_source.dart';
import 'package:animeko_flutter/domain/play/subject_episodes_controller.dart';
import 'package:animeko_flutter/domain/subject/continue_watching_controller.dart';
import 'package:animeko_flutter/ui/subject/continue_watching_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockSubjectApi extends Mock implements SubjectApi {}

/// Minimal scraper-side episode: [MediaEpisode] is just these two
/// getters (`lib/domain/media/media_source.dart:21-27`).
class FakeMediaEpisode implements MediaEpisode {
  const FakeMediaEpisode(this.sourceId, this.title);

  @override
  final String sourceId;

  @override
  final String title;
}

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

SubjectEpisode ep(int n) => SubjectEpisode(
  episodeId: n,
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
    SharedPreferences.setMockInitialValues({'lastPlayedEpisode:1': 3});

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

    expect(find.byType(FilledButton), findsNothing);
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

    expect(find.byType(FilledButton), findsNothing);
  });

  // Covers what the button hands to `EpisodePlaybackSheet`: the target
  // episode, and its position in the full main-episode list (the
  // `ordinalIndex` contract playback-source matching keys on).
  //
  // The fixture makes the index observable: source `wide` lists three
  // episodes and source `narrow` only one, so position 2 matches `wide`
  // alone while position 0 would also match `narrow`
  // (`EpisodeSourceIndex.matchesAt`). `mediaSourcesProvider` is empty so
  // each row falls back to its raw `sourceId` as its label
  // (`sourceLabel`).
  testWidgets('opens the playback sheet for the target at its ordinal index', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'lastPlayedEpisode:1': 3});
    final merged = [
      for (var i = 1; i <= 3; i++)
        MergedEpisode(
          episode: FakeMediaEpisode('wide', 'wide-$i'),
          sourceId: 'wide',
        ),
      const MergedEpisode(
        episode: FakeMediaEpisode('narrow', 'narrow-1'),
        sourceId: 'narrow',
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          subjectApiProvider.overrideWithValue(api),
          mediaSourcesProvider.overrideWithValue(const []),
          subjectEpisodesControllerProvider(
            subjectId: 1,
            subjectName: 'A-cn',
          ).overrideWith(() => StubEpisodesController(merged)),
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

    // The sheet headlines the episode it was handed.
    expect(find.text('第3集'), findsOneWidget);
    expect(find.text('wide'), findsOneWidget);
    expect(find.text('narrow'), findsNothing);
  });
}
