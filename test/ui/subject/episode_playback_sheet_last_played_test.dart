import 'package:animeko_flutter/data/play/last_played_episode_storage.dart';
import 'package:animeko_flutter/data/subject/subject_episode_models.dart';
import 'package:animeko_flutter/domain/media/media_registry.dart';
import 'package:animeko_flutter/domain/media/media_source.dart';
import 'package:animeko_flutter/domain/play/subject_episodes_controller.dart';
import 'package:animeko_flutter/ui/subject/episode_playback_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _episode = SubjectEpisode(
  episodeId: 42,
  sort: 1,
  ep: '1',
  type: 'MAIN',
  name: 'EN 1',
  nameCn: '第一集',
  airdate: '2026-07-12',
);

/// `MediaEpisode` is an abstract interface, so tests implement it by hand
/// -- same pattern as `test/ui/subject/episode_playback_sheet_test.dart`.
class _FakeEpisode implements MediaEpisode {
  const _FakeEpisode({required this.sourceId, required this.title});
  @override
  final String sourceId;
  @override
  final String title;
}

const _merged = MergedEpisode(
  episode: _FakeEpisode(sourceId: 'src', title: '第1话'),
  sourceId: 'src',
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('tapping 播放 records the episode id and navigates', (
    tester,
  ) async {
    // `EpisodePlaybackSheet` is only ever opened via `showModalBottomSheet`
    // in production (e.g. `lib/ui/subject/continue_watching_button.dart`),
    // never rendered directly as a route's body -- its `播放` button's
    // `Navigator.of(context).pop()` pops that modal route, not a page
    // route. Rendering it directly under `MaterialApp.router` (as originally
    // drafted) leaves nothing but the GoRouter page for that same `pop()`
    // to hit, which trips GoRouter's "no pages left" assertion. Opening it
    // through a real `showModalBottomSheet` call mirrors production and
    // gives the sheet's own `pop()` a modal route to close.
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  builder: (_) => const EpisodePlaybackSheet(
                    subjectId: 1,
                    subjectName: '中文名',
                    ordinalIndex: 0,
                    episode: _episode,
                  ),
                ),
                child: const Text('open sheet'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/subject/:subjectId/play',
          builder: (context, state) =>
              const Scaffold(body: Text('player screen')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mediaSourcesProvider.overrideWithValue(const <MediaSource>[]),
          subjectEpisodesControllerProvider(
            subjectId: 1,
            subjectName: '中文名',
          ).overrideWith(() => _FakeEpisodes()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('open sheet'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('播放'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(LastPlayedEpisodeStorage(prefs).get(1), 42);
    expect(find.text('player screen'), findsOneWidget);
  });
}

class _FakeEpisodes extends SubjectEpisodesController {
  @override
  Future<List<MergedEpisode>> build({
    required int subjectId,
    required String subjectName,
  }) async => const [_merged];
}
