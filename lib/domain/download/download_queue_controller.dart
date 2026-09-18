import 'dart:async';

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/download/download_worker.dart';
import '../../data/download/downloaded_episode_repository.dart';
import '../media/media_registry.dart';
import '../play/subject_episodes_controller.dart';
import '../settings/download_settings_controller.dart';
import 'download_source_resolver.dart';

part 'download_queue_controller.g.dart';

enum DownloadQueueStatus { queued, downloading, completed, failed }

class DownloadQueueItem {
  const DownloadQueueItem({
    required this.status,
    this.received = 0,
    this.total = 0,
    this.errorMessage,
    this.isStalled = false,
  });

  final DownloadQueueStatus status;
  final int received;
  final int total;
  final String? errorMessage;

  /// Transient UI flag set by a [DownloadStalled] event and cleared on the
  /// next [DownloadProgress]/[DownloadCompleted]/[DownloadFailed] for the
  /// same key. Never persisted -- see the design doc's decision to keep
  /// "stalled" purely in-memory.
  final bool isStalled;

  double? get progress => total <= 0 ? null : received / total;
}

@riverpod
Dio downloadDio(Ref ref) => Dio();

@riverpod
class DownloadQueueController extends _$DownloadQueueController {
  StreamSubscription<DownloadEvent>? _subscription;
  late DownloadWorker _worker;
  late DownloadedEpisodeRepository _repository;

  @override
  Future<Map<String, DownloadQueueItem>> build() async {
    // Keeps this controller (and its DownloadWorker) alive across
    // navigation -- without this, leaving the player/download panel
    // disposes the notifier while the worker's dio download keeps running
    // unobserved (see design doc bug #1).
    ref.keepAlive();
    // Warms downloadSettingsControllerProvider so enqueue()'s own read of
    // it later resolves instantly -- the value itself isn't needed here
    // since Task 5 moved the download root into a per-request snapshot
    // (DownloadRequest.downloadRoot) rather than a shared worker field.
    await ref.read(downloadSettingsControllerProvider.future);
    final sources = ref.read(mediaSourcesProvider);
    _repository = ref.read(downloadedEpisodeRepositoryProvider);
    _worker = DownloadWorker(
      dio: ref.read(downloadDioProvider),
      sourceForId: (id) => sources.firstWhere((source) => source.id == id),
      repository: _repository,
    );
    _subscription = _worker.events.listen(_onEvent);
    ref.onDispose(() {
      _subscription?.cancel();
    });
    // Rows still `downloading` at this point survived a crash/force-quit --
    // nothing is actually writing to them. keepAlive() above guarantees
    // build() runs exactly once per app lifetime, so this never re-runs on
    // a later rebuild.
    await _repository.reconcileInterrupted();
    return const {};
  }

  void enqueue({
    required int subjectId,
    required String subjectName,
    required MergedEpisode episode,
  }) async {
    final root = await ref.read(downloadSettingsControllerProvider.future);
    _worker.enqueue(
      DownloadRequest(
        subjectId: subjectId,
        subjectName: subjectName,
        sourceId: episode.sourceId,
        episode: episode.episode,
        episodeLabel: episode.title,
        downloadRoot: root,
      ),
    );
  }

  void cancel(String episodeKey) => _worker.cancel(episodeKey);

  /// Re-resolves a downloadable source for the episode behind [episodeKey]
  /// (which may no longer be the same source the original download used --
  /// see `download_source_resolver.dart`) and re-enqueues it. If the newly
  /// resolved source differs from the stale record's source, the stale
  /// record and its files are deleted first so a failed/half-downloaded
  /// attempt from an abandoned source doesn't linger on disk.
  ///
  /// Throws [StateError] if no downloadable source has this episode
  /// anymore (e.g. every source's episode list changed).
  Future<void> retry(String episodeKey) async {
    final row = await _repository.findByKey(episodeKey);
    if (row == null) return;
    final merged = await ref.read(
      subjectEpisodesControllerProvider(
        subjectId: row.subjectId,
        subjectName: row.subjectName,
      ).future,
    );
    final match = resolvePreferredDownloadSource(merged, row.episodeLabel);
    if (match == null) {
      throw StateError('源的剧集列表已变化，请在详情页重新选择这一集');
    }
    if (match.sourceId != row.sourceId) {
      await _repository.deleteWithFiles(row.episodeKey);
    }
    enqueue(
      subjectId: row.subjectId,
      subjectName: row.subjectName,
      episode: match,
    );
  }

  void emit(DownloadEvent event) => _onEvent(event);

  void _onEvent(DownloadEvent event) {
    final key = event.request.episodeKey;
    final current = state.value ?? const <String, DownloadQueueItem>{};
    if (event is DownloadCancelled) {
      state = AsyncData({...current}..remove(key));
    } else if (event is DownloadQueued) {
      state = AsyncData({
        ...current,
        key: const DownloadQueueItem(status: DownloadQueueStatus.queued),
      });
    } else if (event is DownloadStalled) {
      final existing = current[key];
      state = AsyncData({
        ...current,
        key: DownloadQueueItem(
          status: DownloadQueueStatus.downloading,
          received: existing?.received ?? 0,
          total: existing?.total ?? 0,
          isStalled: true,
        ),
      });
    } else if (event is DownloadProgress) {
      state = AsyncData({
        ...current,
        key: DownloadQueueItem(
          status: DownloadQueueStatus.downloading,
          received: event.received,
          total: event.total,
        ),
      });
    } else if (event is DownloadCompleted) {
      state = AsyncData({
        ...current,
        key: const DownloadQueueItem(status: DownloadQueueStatus.completed),
      });
    } else if (event is DownloadFailed) {
      state = AsyncData({
        ...current,
        key: DownloadQueueItem(
          status: DownloadQueueStatus.failed,
          errorMessage: event.message,
        ),
      });
    }
  }
}
