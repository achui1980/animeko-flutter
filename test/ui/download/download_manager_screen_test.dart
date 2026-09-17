import 'package:animeko_flutter/data/download/downloaded_episode_repository.dart';
import 'package:animeko_flutter/data/download/downloaded_episodes_provider.dart';
import 'package:animeko_flutter/data/local_database.dart';
import 'package:animeko_flutter/domain/download/download_queue_controller.dart';
import 'package:animeko_flutter/domain/media/media_source.dart';
import 'package:animeko_flutter/domain/play/subject_episodes_controller.dart';
import 'package:animeko_flutter/ui/download/download_manager_screen.dart';
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

class _FakeQueueController extends DownloadQueueController {
  _FakeQueueController(this.items);

  final Map<String, DownloadQueueItem> items;
  final cancelled = <String>[];
  final enqueued = <MergedEpisode>[];

  @override
  Future<Map<String, DownloadQueueItem>> build() async => items;

  @override
  void cancel(String episodeKey) => cancelled.add(episodeKey);

  @override
  void enqueue({
    required int subjectId,
    required String subjectName,
    required MergedEpisode episode,
  }) => enqueued.add(episode);
}

class _FakeEpisodesController extends SubjectEpisodesController {
  _FakeEpisodesController(this.episodes);

  final List<MergedEpisode> episodes;

  @override
  Future<List<MergedEpisode>> build({
    required int subjectId,
    required String subjectName,
  }) async => episodes;
}

void main() {
  late AppDatabase database;
  late DownloadedEpisodeRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = DownloadedEpisodeRepository(database);
  });

  tearDown(() => database.close());

  Future<_FakeQueueController> pumpScreen(
    WidgetTester tester, {
    Map<String, DownloadQueueItem> queueItems = const {},
    List<MergedEpisode> episodes = const [],
  }) async {
    late _FakeQueueController queue;
    final rows = await repository.getAll();
    final summaries = rows
        .map(
          (row) => DownloadedEpisodeSummary(
            sourceId: row.sourceId,
            subjectId: row.subjectId,
            episodeKey: row.episodeKey,
            subjectName: row.subjectName,
            episodeLabel: row.episodeLabel,
            localPath: row.localPath,
            status: row.status,
            errorMessage: row.errorMessage,
          ),
        )
        .toList();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          downloadedEpisodeRepositoryProvider.overrideWithValue(repository),
          downloadedEpisodesProvider.overrideWith(
            (ref) => Stream.value(summaries),
          ),
          downloadQueueControllerProvider.overrideWith(() {
            queue = _FakeQueueController(queueItems);
            return queue;
          }),
          subjectEpisodesControllerProvider(
            subjectId: 1,
            subjectName: '测试番剧',
          ).overrideWith(() => _FakeEpisodesController(episodes)),
        ],
        child: const MaterialApp(home: DownloadManagerScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return queue;
  }

  testWidgets('shows an empty download state', (tester) async {
    await pumpScreen(tester);

    expect(find.text('暂无下载'), findsOneWidget);
  });

  testWidgets('shows progress and cancels a downloading item', (tester) async {
    const key = '1::anime1::1';
    await repository.upsert(
      const DownloadedEpisodeWrite(
        sourceId: 'anime1',
        subjectId: 1,
        episodeKey: key,
        subjectName: '测试番剧',
        episodeLabel: '1',
        localPath: '/tmp/one.mp4',
        format: 'mp4',
        status: DownloadStatus.downloading,
      ),
    );

    final queue = await pumpScreen(
      tester,
      queueItems: const {
        key: DownloadQueueItem(
          status: DownloadQueueStatus.downloading,
          received: 50,
          total: 100,
        ),
      },
    );

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await tester.tap(find.text('取消'));
    expect(queue.cancelled, [key]);
  });

  testWidgets('shows retry details for a failed download', (tester) async {
    await repository.upsert(
      const DownloadedEpisodeWrite(
        sourceId: 'xifan',
        subjectId: 1,
        episodeKey: '1::xifan::1',
        subjectName: '测试番剧',
        episodeLabel: '1',
        localPath: '/tmp/one.mp4',
        format: 'mp4',
        status: DownloadStatus.failed,
        errorMessage: '网络错误',
      ),
    );
    final episode = MergedEpisode(
      episode: const _FakeEpisode('xifan', '1'),
      sourceId: 'xifan',
    );

    final queue = await pumpScreen(tester, episodes: [episode]);

    expect(find.text('网络错误'), findsOneWidget);
    await tester.tap(find.text('重试'));
    expect(queue.enqueued, [episode]);
  });

  testWidgets('shows delete for a completed download', (tester) async {
    await repository.upsert(
      const DownloadedEpisodeWrite(
        sourceId: 'anime1',
        subjectId: 1,
        episodeKey: '1::anime1::1',
        subjectName: '测试番剧',
        episodeLabel: '1',
        localPath: '/tmp/one.mp4',
        format: 'mp4',
        status: DownloadStatus.completed,
      ),
    );

    await pumpScreen(tester);

    expect(find.text('删除'), findsOneWidget);
  });
}
