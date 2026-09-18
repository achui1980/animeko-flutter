import 'package:animeko_flutter/data/download/downloaded_episode_repository.dart';
import 'package:animeko_flutter/data/download/downloaded_episodes_provider.dart';
import 'package:animeko_flutter/data/local_database.dart';
import 'package:animeko_flutter/domain/download/download_queue_controller.dart';
import 'package:animeko_flutter/domain/media/media_source.dart';
import 'package:animeko_flutter/domain/play/subject_episodes_controller.dart';
import 'package:animeko_flutter/ui/download/download_panel.dart';
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

/// Used to verify the retry button's `onRetry` callback surfaces a
/// [StateError] from `retry()` as a SnackBar instead of letting it become
/// an unhandled async error (see the design doc's 3.2/download review
/// finding #1).
class _ThrowingRetryQueueController extends DownloadQueueController {
  @override
  Future<Map<String, DownloadQueueItem>> build() async => const {};
  @override
  void enqueue({
    required int subjectId,
    required String subjectName,
    required MergedEpisode episode,
  }) {}
  @override
  Future<void> retry(String episodeKey) async {
    throw StateError('源的剧集列表已变化，请在详情页重新选择这一集');
  }
}

void main() {
  late AppDatabase database;
  late DownloadedEpisodeRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = DownloadedEpisodeRepository(database);
  });

  tearDown(() => database.close());

  Future<void> pumpPanel(
    WidgetTester tester, {
    int? subjectId,
    List<MergedEpisode> episodes = const [],
  }) async {
    // downloadedEpisodesProvider is a real drift watchAll() stream; its
    // debounce Timer never fires under flutter_test's FakeAsync clock
    // before the tree is disposed, tripping the "Timer is still pending"
    // invariant. Snapshot the rows instead, matching the workaround
    // already used in download_manager_screen_test.dart.
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
          subjectEpisodesControllerProvider(
            subjectId: subjectId ?? 1,
            subjectName: '测试番剧',
          ).overrideWith(() => _StubEpisodesController(episodes)),
          downloadQueueControllerProvider.overrideWith(_FakeQueueController.new),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: DownloadPanel(
              subjectId: subjectId,
              subjectName: subjectId == null ? null : '测试番剧',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('hides the episode-selection tab when subjectId is null', (
    tester,
  ) async {
    await pumpPanel(tester);

    expect(find.text('选集下载'), findsNothing);
    expect(find.text('下载中 · 已下载(0)'), findsOneWidget);
  });

  testWidgets('shows both tabs when subjectId is given', (tester) async {
    const episode = MergedEpisode(
      episode: _FakeEpisode('anime1', '第1集'),
      sourceId: 'anime1',
    );
    await pumpPanel(tester, subjectId: 1, episodes: const [episode]);

    expect(find.text('选集下载'), findsOneWidget);
    expect(find.text('下载中 · 已下载(0)'), findsOneWidget);
  });

  testWidgets('list tab filters to the given subject only', (tester) async {
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
    await repository.upsert(
      const DownloadedEpisodeWrite(
        sourceId: 'anime1',
        subjectId: 2,
        episodeKey: '2::anime1::第1集',
        subjectName: '另一部番剧',
        episodeLabel: '第1集',
        localPath: '/tmp/b.mp4',
        episodeDir: '/tmp',
        format: 'mp4',
        status: DownloadStatus.completed,
      ),
    );

    await pumpPanel(tester, subjectId: 1);
    await tester.tap(find.text('下载中 · 已下载(1)'));
    await tester.pumpAndSettle();

    expect(find.text('测试番剧'), findsOneWidget);
    expect(find.text('另一部番剧'), findsNothing);
  });

  testWidgets(
    'shows a SnackBar with the error message when retry() throws',
    (tester) async {
      await repository.upsert(
        const DownloadedEpisodeWrite(
          sourceId: 'anime1',
          subjectId: 1,
          episodeKey: '1::anime1::第1集',
          subjectName: '测试番剧',
          episodeLabel: '第1集',
          localPath: '/tmp/a',
          episodeDir: '/tmp/a',
          format: 'mp4',
          status: DownloadStatus.failed,
          errorMessage: 'boom',
        ),
      );
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
            subjectEpisodesControllerProvider(
              subjectId: 1,
              subjectName: '测试番剧',
            ).overrideWith(() => _StubEpisodesController(const [])),
            downloadQueueControllerProvider.overrideWith(
              _ThrowingRetryQueueController.new,
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DownloadPanel(subjectId: 1, subjectName: '测试番剧'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('下载中 · 已下载(1)'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();

      expect(find.text('Bad state: 源的剧集列表已变化，请在详情页重新选择这一集'), findsOneWidget);
    },
  );
}
