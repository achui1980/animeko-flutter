import 'package:animeko_flutter/data/download/downloaded_episode_repository.dart';
import 'package:animeko_flutter/data/download/download_worker.dart';
import 'package:animeko_flutter/data/local_database.dart';
import 'package:animeko_flutter/domain/download/download_queue_controller.dart';
import 'package:animeko_flutter/domain/media/media_registry.dart';
import 'package:animeko_flutter/domain/media/media_source.dart';
import 'package:animeko_flutter/domain/play/subject_episodes_controller.dart';
import 'package:animeko_flutter/domain/settings/download_settings_controller.dart';
import 'package:animeko_flutter/data/settings/settings_storage.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class _SettingsStorage extends Mock implements SettingsStorage {}

class _Episode implements MediaEpisode {
  const _Episode(this.sourceId, this.title);

  @override
  final String sourceId;

  @override
  final String title;
}

class _StubMediaSource implements MediaSource {
  _StubMediaSource(this.id);

  @override
  final String id;

  @override
  String get displayName => id;

  @override
  Future<List<MediaCandidate>> search(String title, {int? subjectId}) =>
      throw UnimplementedError();

  @override
  Future<List<MediaEpisode>> listEpisodes(MediaCandidate candidate) =>
      throw UnimplementedError();

  @override
  Future<List<MediaPlaybackSource>> resolvePlayback(MediaEpisode episode) =>
      throw UnimplementedError();
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

const request = DownloadRequest(
  subjectId: 1,
  subjectName: 'Subject',
  sourceId: 'xifan',
  episode: _Episode('xifan', '1'),
  episodeLabel: 'Episode 1',
  downloadRoot: '/downloads',
);

void main() {
  late AppDatabase database;
  late ProviderContainer container;
  late _SettingsStorage settingsStorage;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    settingsStorage = _SettingsStorage();
    when(settingsStorage.getDownloadDirectory).thenReturn('/downloads');
    container = ProviderContainer(
      overrides: [
        settingsStorageProvider.overrideWith((ref) async => settingsStorage),
        mediaSourcesProvider.overrideWithValue(const []),
        downloadDioProvider.overrideWithValue(Dio()),
        downloadedEpisodeRepositoryProvider.overrideWithValue(
          DownloadedEpisodeRepository(database),
        ),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(database.close);
  });

  test('maps worker progress into state indexed by episode key', () async {
    final subscription = container.listen(
      downloadQueueControllerProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);
    await container.read(downloadQueueControllerProvider.future);
    final controller = container.read(downloadQueueControllerProvider.notifier);

    controller.emit(const DownloadProgress(request, 50, 100));
    await container.pump();

    expect(
      container
          .read(downloadQueueControllerProvider)
          .value!['1::xifan::1']!
          .progress,
      .5,
    );
  });

  test('maps worker statuses and removes cancelled entries', () async {
    final subscription = container.listen(
      downloadQueueControllerProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);
    await container.read(downloadQueueControllerProvider.future);
    final controller = container.read(downloadQueueControllerProvider.notifier);

    controller.emit(const DownloadQueued(request));
    expect(
      container
          .read(downloadQueueControllerProvider)
          .value!['1::xifan::1']!
          .status,
      DownloadQueueStatus.queued,
    );

    controller.emit(const DownloadCompleted(request));
    expect(
      container
          .read(downloadQueueControllerProvider)
          .value!['1::xifan::1']!
          .status,
      DownloadQueueStatus.completed,
    );

    controller.emit(const DownloadFailed(request, 'network error'));
    final failed = container
        .read(downloadQueueControllerProvider)
        .value!['1::xifan::1']!;
    expect(failed.status, DownloadQueueStatus.failed);
    expect(failed.errorMessage, 'network error');

    controller.emit(const DownloadCancelled(request));
    expect(
      container.read(downloadQueueControllerProvider).value,
      isNot(contains('1::xifan::1')),
    );
  });

  test('the controller survives disposal of its last listener', () async {
    final subscription = container.listen(
      downloadQueueControllerProvider,
      (_, _) {},
    );
    await container.read(downloadQueueControllerProvider.future);
    final before = container.read(downloadQueueControllerProvider.notifier);

    // Simulate "the widget that was watching this provider got popped" --
    // without ref.keepAlive() in build(), this disposes the whole notifier.
    subscription.close();
    await container.pump();

    final after = container.read(downloadQueueControllerProvider.notifier);
    expect(after, same(before));
  });

  test('changing the download directory setting does not rebuild the '
      'controller or drop its state', () async {
    final subscription = container.listen(
      downloadQueueControllerProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);
    await container.read(downloadQueueControllerProvider.future);
    final controller = container.read(downloadQueueControllerProvider.notifier);
    controller.emit(const DownloadQueued(request));
    await container.pump();
    expect(
      container.read(downloadQueueControllerProvider).value,
      contains('1::xifan::1'),
    );

    // build() must not `watch` downloadSettingsControllerProvider -- if it
    // does, invalidating that provider rebuilds this one too and the
    // DownloadQueued entry above is lost.
    container.invalidate(downloadSettingsControllerProvider);
    await container.pump();

    expect(
      container.read(downloadQueueControllerProvider.notifier),
      same(controller),
    );
    expect(
      container.read(downloadQueueControllerProvider).value,
      contains('1::xifan::1'),
    );
  });

  test('build() reconciles interrupted rows from a previous run', () async {
    final repository = DownloadedEpisodeRepository(database);
    await repository.upsert(
      const DownloadedEpisodeWrite(
        sourceId: 'anime1',
        subjectId: 9,
        episodeKey: '9::anime1::1',
        subjectName: '测试番剧',
        episodeLabel: '1',
        localPath: '/tmp/nine',
        format: 'mp4',
        status: DownloadStatus.downloading,
      ),
    );

    final subscription = container.listen(
      downloadQueueControllerProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);
    await container.read(downloadQueueControllerProvider.future);

    final row = await repository.findByKey('9::anime1::1');
    expect(row!.status, DownloadStatus.interrupted.name);
  });

  test('retry re-resolves a preferred source and enqueues with it', () async {
    final repository = DownloadedEpisodeRepository(database);
    await repository.upsert(
      const DownloadedEpisodeWrite(
        sourceId: 'anime1',
        subjectId: 7,
        episodeKey: '7::anime1::第1集',
        subjectName: '测试番剧',
        episodeLabel: '第1集',
        localPath: '/tmp/seven',
        format: 'mp4',
        status: DownloadStatus.failed,
        errorMessage: 'boom',
      ),
    );
    final episode = MergedEpisode(
      episode: const _Episode('anime1', '第1集'),
      sourceId: 'anime1',
    );
    final testContainer = ProviderContainer(
      overrides: [
        settingsStorageProvider.overrideWith((ref) async => settingsStorage),
        mediaSourcesProvider.overrideWithValue([_StubMediaSource('anime1')]),
        downloadDioProvider.overrideWithValue(Dio()),
        downloadedEpisodeRepositoryProvider.overrideWithValue(repository),
        subjectEpisodesControllerProvider(
          subjectId: 7,
          subjectName: '测试番剧',
        ).overrideWith(() => _StubEpisodesController([episode])),
      ],
    );
    addTearDown(testContainer.dispose);
    final subscription = testContainer.listen(
      downloadQueueControllerProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);
    await testContainer.read(downloadQueueControllerProvider.future);
    final queueController = testContainer.read(
      downloadQueueControllerProvider.notifier,
    );

    await queueController.retry('7::anime1::第1集');
    await testContainer.pump();

    // resolvePreferredDownloadSource matches the same source ('anime1') the
    // stale row already used, so retry() must not delete-and-recreate it --
    // only enqueue() should have run. Asserting via the real
    // downloadQueueControllerProvider's emitted state (rather than the DB
    // row, which the real DownloadWorker keeps mutating asynchronously via
    // genuine filesystem I/O well past this point, making its exact status
    // at any given instant non-deterministic in a test) is what actually
    // proves retry() re-resolved the source and called enqueue with it.
    expect(
      testContainer.read(downloadQueueControllerProvider).value,
      contains('7::anime1::第1集'),
    );
    expect(await repository.findByKey('7::anime1::第1集'), isNotNull);
  });

  test(
    'retry deletes the stale record on the old source when the '
    're-resolved preferred source has changed',
    () async {
      final repository = DownloadedEpisodeRepository(database);
      await repository.upsert(
        const DownloadedEpisodeWrite(
          sourceId: 'anime1',
          subjectId: 8,
          episodeKey: '8::anime1::第1集',
          subjectName: '测试番剧',
          episodeLabel: '第1集',
          localPath: '/tmp/eight-anime1',
          format: 'mp4',
          status: DownloadStatus.failed,
          errorMessage: 'boom',
        ),
      );
      // anime1 no longer has this episode (simulated by simply omitting it
      // from the merged episode list) -- xifan is the only remaining
      // downloadable candidate, so resolvePreferredDownloadSource must
      // return it instead of the stale row's original source.
      final episode = MergedEpisode(
        episode: const _Episode('xifan', '第1集'),
        sourceId: 'xifan',
      );
      final testContainer = ProviderContainer(
        overrides: [
          settingsStorageProvider.overrideWith((ref) async => settingsStorage),
          mediaSourcesProvider.overrideWithValue([_StubMediaSource('xifan')]),
          downloadDioProvider.overrideWithValue(Dio()),
          downloadedEpisodeRepositoryProvider.overrideWithValue(repository),
          subjectEpisodesControllerProvider(
            subjectId: 8,
            subjectName: '测试番剧',
          ).overrideWith(() => _StubEpisodesController([episode])),
        ],
      );
      addTearDown(testContainer.dispose);
      final subscription = testContainer.listen(
        downloadQueueControllerProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      await testContainer.read(downloadQueueControllerProvider.future);
      final queueController = testContainer.read(
        downloadQueueControllerProvider.notifier,
      );

      await queueController.retry('8::anime1::第1集');
      await testContainer.pump();

      // The stale anime1 record must be gone -- retry() detected the
      // preferred source changed and cleaned it up via deleteWithFiles.
      expect(await repository.findByKey('8::anime1::第1集'), isNull);
      // A new download must have been enqueued against the newly-resolved
      // xifan source.
      expect(
        testContainer.read(downloadQueueControllerProvider).value,
        contains('8::xifan::第1集'),
      );
    },
  );
}
