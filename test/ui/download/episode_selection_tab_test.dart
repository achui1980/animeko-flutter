import 'package:animeko_flutter/data/download/downloaded_episode_repository.dart';
import 'package:animeko_flutter/data/local_database.dart';
import 'package:animeko_flutter/domain/download/download_queue_controller.dart';
import 'package:animeko_flutter/domain/media/media_source.dart';
import 'package:animeko_flutter/domain/play/subject_episodes_controller.dart';
import 'package:animeko_flutter/ui/download/episode_selection_tab.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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

class _RecordingQueueController extends DownloadQueueController {
  _RecordingQueueController([this.items = const {}]);
  final Map<String, DownloadQueueItem> items;
  final enqueued = <MergedEpisode>[];

  @override
  Future<Map<String, DownloadQueueItem>> build() async => items;

  @override
  void enqueue({
    required int subjectId,
    required String subjectName,
    required MergedEpisode episode,
  }) => enqueued.add(episode);
}

void main() {
  late AppDatabase database;
  late DownloadedEpisodeRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = DownloadedEpisodeRepository(database);
  });

  tearDown(() => database.close());

  const anime1Ep1 = MergedEpisode(
    episode: _FakeEpisode('anime1', '第1集'),
    sourceId: 'anime1',
  );
  const anime1Ep2 = MergedEpisode(
    episode: _FakeEpisode('anime1', '第2集'),
    sourceId: 'anime1',
  );
  const mikanEp3 = MergedEpisode(
    episode: _FakeEpisode('mikan', '第3集'),
    sourceId: 'mikan',
  );

  Future<_RecordingQueueController> pumpTab(
    WidgetTester tester, {
    List<MergedEpisode> episodes = const [
      anime1Ep1,
      anime1Ep2,
      mikanEp3,
    ],
    Map<String, DownloadQueueItem> queueItems = const {},
  }) async {
    late _RecordingQueueController queue;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          downloadedEpisodeRepositoryProvider.overrideWithValue(repository),
          subjectEpisodesControllerProvider(
            subjectId: 1,
            subjectName: '测试番剧',
          ).overrideWith(() => _StubEpisodesController(episodes)),
          downloadQueueControllerProvider.overrideWith(() {
            queue = _RecordingQueueController(queueItems);
            return queue;
          }),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: EpisodeSelectionTab(subjectId: 1, subjectName: '测试番剧'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return queue;
  }

  testWidgets('shows a source label and lets the user check a downloadable '
      'episode', (tester) async {
    await pumpTab(tester);

    expect(find.text('第1集'), findsOneWidget);
    expect(find.text('anime1'), findsWidgets);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    expect(find.text('已选 1 集'), findsOneWidget);
  });

  testWidgets('greys out an episode with no downloadable source', (
    tester,
  ) async {
    await pumpTab(tester);

    expect(find.text('无可下载来源'), findsOneWidget);
    final checkboxes = tester.widgetList<Checkbox>(find.byType(Checkbox));
    // The third row (mikan-only) has a disabled (null onChanged) checkbox.
    expect(checkboxes.last.onChanged, isNull);
  });

  testWidgets('greys out an already-downloaded episode as non-selectable', (
    tester,
  ) async {
    await repository.upsert(
      const DownloadedEpisodeWrite(
        sourceId: 'anime1',
        subjectId: 1,
        episodeKey: '1::anime1::第1集',
        subjectName: '测试番剧',
        episodeLabel: '第1集',
        localPath: '/tmp/a.mp4',
        episodeDir: '/tmp',
        format: 'mp4',
        status: DownloadStatus.completed,
      ),
    );

    await pumpTab(tester);

    expect(find.text('已下载'), findsOneWidget);
    final checkboxes = tester.widgetList<Checkbox>(find.byType(Checkbox));
    expect(checkboxes.first.onChanged, isNull);
  });

  testWidgets('greys out a currently-downloading episode with its percent', (
    tester,
  ) async {
    await pumpTab(
      tester,
      queueItems: {
        '1::anime1::第1集': const DownloadQueueItem(
          status: DownloadQueueStatus.downloading,
          received: 42,
          total: 100,
        ),
      },
    );

    expect(find.textContaining('下载中'), findsOneWidget);
    expect(find.textContaining('42'), findsOneWidget);
  });

  testWidgets('select all only checks downloadable, not-yet-downloaded '
      'episodes, then downloads them on tap', (tester) async {
    final queue = await pumpTab(tester);

    await tester.tap(find.text('全选'));
    await tester.pumpAndSettle();

    expect(find.text('已选 2 集'), findsOneWidget);

    await tester.tap(find.text('下载选中 2 集'));
    await tester.pumpAndSettle();

    expect(queue.enqueued.map((e) => e.title), ['第1集', '第2集']);
  });

  testWidgets('clear deselects everything', (tester) async {
    await pumpTab(tester);
    await tester.tap(find.text('全选'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('清空'));
    await tester.pumpAndSettle();

    expect(find.text('已选 0 集'), findsOneWidget);
  });
}
