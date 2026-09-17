import 'dart:async';

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/download/download_worker.dart';
import '../../data/download/downloaded_episode_repository.dart';
import '../media/media_registry.dart';
import '../play/subject_episodes_controller.dart';
import '../settings/download_settings_controller.dart';

part 'download_queue_controller.g.dart';

enum DownloadQueueStatus { queued, downloading, completed, failed }

class DownloadQueueItem {
  const DownloadQueueItem({
    required this.status,
    this.received = 0,
    this.total = 0,
    this.errorMessage,
  });

  final DownloadQueueStatus status;
  final int received;
  final int total;
  final String? errorMessage;

  double? get progress => total <= 0 ? null : received / total;
}

@riverpod
Dio downloadDio(Ref ref) => Dio();

@riverpod
class DownloadQueueController extends _$DownloadQueueController {
  StreamSubscription<DownloadEvent>? _subscription;
  late DownloadWorker _worker;

  @override
  Future<Map<String, DownloadQueueItem>> build() async {
    final root = await ref.watch(downloadSettingsControllerProvider.future);
    final sources = ref.watch(mediaSourcesProvider);
    _worker = DownloadWorker(
      dio: ref.read(downloadDioProvider),
      downloadRoot: root,
      sourceForId: (id) => sources.firstWhere((source) => source.id == id),
      repository: ref.read(downloadedEpisodeRepositoryProvider),
    );
    _subscription = _worker.events.listen(_onEvent);
    ref.onDispose(() {
      _subscription?.cancel();
    });
    return const {};
  }

  void enqueue({
    required int subjectId,
    required String subjectName,
    required MergedEpisode episode,
  }) => _worker.enqueue(
    DownloadRequest(
      subjectId: subjectId,
      subjectName: subjectName,
      sourceId: episode.sourceId,
      episode: episode.episode,
      episodeLabel: episode.title,
    ),
  );

  void cancel(String episodeKey) => _worker.cancel(episodeKey);

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
