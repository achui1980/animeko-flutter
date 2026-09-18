import 'package:animeko_flutter/data/download/downloaded_episodes_provider.dart';
import 'package:animeko_flutter/data/subject/collection_type.dart';
import 'package:animeko_flutter/data/subject/review_models.dart';
import 'package:animeko_flutter/data/subject/subject_api.dart';
import 'package:animeko_flutter/data/subject/subject_episode_models.dart';
import 'package:animeko_flutter/data/subject/subject_models.dart';
import 'package:animeko_flutter/domain/download/download_queue_controller.dart';
import 'package:animeko_flutter/domain/media/media_source.dart';
import 'package:animeko_flutter/domain/play/subject_episodes_controller.dart';
import 'package:animeko_flutter/ui/subject/subject_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockSubjectApi extends Mock implements SubjectApi {}

class _FakeEpisode implements MediaEpisode {
  const _FakeEpisode(this.sourceId, this.title);

  @override
  final String sourceId;

  @override
  final String title;
}

class _StubEpisodesController extends SubjectEpisodesController {
  _StubEpisodesController(this.episodes);

  final List<MergedEpisode> episodes;

  @override
  Future<List<MergedEpisode>> build({
    required int subjectId,
    required String subjectName,
  }) async => episodes;
}

class _FakeQueueController extends DownloadQueueController {
  _FakeQueueController([this.items = const {}]);

  final Map<String, DownloadQueueItem> items;

  @override
  Future<Map<String, DownloadQueueItem>> build() async => items;

  @override
  void enqueue({
    required int subjectId,
    required String subjectName,
    required MergedEpisode episode,
  }) {}
}

// Gives `SubjectMainEpisodesController` (derived from `SubjectDetail.
// episodes`, not from the merged-episode stub below) a non-empty main
// episode list -- without this `SubjectEpisodesSection` bails out via its
// `if (episodes.isEmpty) return SizedBox.shrink()` guard and the badge
// button under test never mounts.
const _mainEpisode = SubjectEpisode(
  episodeId: 11,
  sort: 1,
  ep: '1',
  type: 'MAIN',
  name: 'EN 1',
  nameCn: '第一集',
  airdate: '2026-01-01',
);

SubjectDetail _detail() => SubjectDetail(
  id: 1,
  name: 'Original Name',
  nameCn: '中文名',
  summary: 'summary',
  airDate: '2026-01-01',
  tags: const [],
  collectionType: CollectionType.doing,
  selfRating: const SelfRating(score: 0, tags: [], isPrivate: false),
  episodes: const [_mainEpisode],
);

Future<void> _pump(
  WidgetTester tester, {
  Map<String, DownloadQueueItem> queueItems = const {},
  List<MergedEpisode> episodes = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  final api = _MockSubjectApi();
  when(() => api.getSubject(1)).thenAnswer((_) async => _detail());
  when(() => api.getCharacters(1)).thenAnswer((_) async => []);
  when(
    () => api.getReviews(
      subjectId: any(named: 'subjectId'),
      offset: any(named: 'offset'),
      limit: any(named: 'limit'),
    ),
  ).thenAnswer((_) async => const PaginatedReviews(total: 0, items: []));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        subjectApiProvider.overrideWithValue(api),
        subjectEpisodesControllerProvider(
          subjectId: 1,
          subjectName: '中文名',
        ).overrideWith(() => _StubEpisodesController(episodes)),
        downloadQueueControllerProvider.overrideWith(
          () => _FakeQueueController(queueItems),
        ),
        // downloadedEpisodesProvider is a real drift watchAll() stream; its
        // debounce Timer never fires under flutter_test's FakeAsync clock
        // before the tree is disposed, tripping the "Timer is still
        // pending" invariant when the download panel (which reads it)
        // gets opened. See the same workaround in download_panel_test.dart.
        downloadedEpisodesProvider.overrideWith(
          (ref) => Stream.value(const <DownloadedEpisodeSummary>[]),
        ),
      ],
      child: const MaterialApp(
        home: SubjectDetailScreen(subjectId: 1, subjectName: '中文名'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the AppBar no longer has a 全部下载 button', (tester) async {
    await _pump(tester);

    expect(find.byTooltip('全部下载'), findsNothing);
  });

  testWidgets('the 选集 row shows a download badge button', (tester) async {
    final episodes = [
      const MergedEpisode(
        episode: _FakeEpisode('anime1', '第1集'),
        sourceId: 'anime1',
      ),
    ];

    await _pump(tester, episodes: episodes);

    expect(find.byTooltip('下载'), findsOneWidget);
  });

  testWidgets('tapping the badge button opens the download panel', (
    tester,
  ) async {
    final episodes = [
      const MergedEpisode(
        episode: _FakeEpisode('anime1', '第1集'),
        sourceId: 'anime1',
      ),
    ];

    await _pump(tester, episodes: episodes);
    await tester.tap(find.byTooltip('下载'));
    await tester.pumpAndSettle();

    expect(find.text('选集下载'), findsOneWidget);
  });
}
