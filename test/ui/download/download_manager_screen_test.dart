import 'package:animeko_flutter/data/download/downloaded_episode_repository.dart';
import 'package:animeko_flutter/data/download/downloaded_episodes_provider.dart';
import 'package:animeko_flutter/domain/download/download_queue_controller.dart';
import 'package:animeko_flutter/domain/play/subject_episodes_controller.dart';
import 'package:animeko_flutter/data/local_database.dart';
import 'package:animeko_flutter/ui/download/download_manager_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeQueueController extends DownloadQueueController {
  @override
  Future<Map<String, DownloadQueueItem>> build() async => const {};
  @override
  void enqueue({
    required int subjectId,
    required String subjectName,
    required MergedEpisode episode,
  }) {}
}

void main() {
  late AppDatabase database;
  late DownloadedEpisodeRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = DownloadedEpisodeRepository(database);
  });

  tearDown(() => database.close());

  // downloadedEpisodesProvider is a real drift watchAll() stream; its
  // debounce Timer never fires under flutter_test's FakeAsync clock before
  // the tree is disposed, tripping the "Timer is still pending" invariant.
  // Snapshot the rows instead, matching the workaround already used in
  // download_panel_test.dart.
  Future<void> pumpScreen(WidgetTester tester) async {
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
          downloadQueueControllerProvider.overrideWith(_FakeQueueController.new),
        ],
        child: const MaterialApp(home: DownloadManagerScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the 下载管理 title and an empty state, with no '
      'episode-selection tab (subjectId is null)', (tester) async {
    await pumpScreen(tester);

    expect(find.text('下载管理'), findsOneWidget);
    expect(find.text('暂无下载'), findsOneWidget);
    expect(find.text('选集下载'), findsNothing);
  });

  testWidgets('lists a completed download across every subject', (
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

    await pumpScreen(tester);

    expect(find.text('测试番剧'), findsOneWidget);
  });
}
