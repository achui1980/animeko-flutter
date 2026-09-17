import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import '../../domain/media/media_source.dart';
import 'downloaded_episode_repository.dart';
import 'hls_downloader.dart';

class DownloadRequest {
  const DownloadRequest({
    required this.subjectId,
    required this.subjectName,
    required this.sourceId,
    required this.episode,
    required this.episodeLabel,
    required this.downloadRoot,
  });

  final int subjectId;
  final String subjectName;
  final String sourceId;
  final MediaEpisode episode;
  final String episodeLabel;

  /// Snapshotted at enqueue time from `DownloadSettingsController`. Reading
  /// it here (rather than `DownloadWorker` reading a single shared root at
  /// construction time) means an in-flight download keeps writing to the
  /// directory the user had configured when they started it, even if they
  /// change the setting mid-download -- see the design doc's decision to
  /// stop `DownloadQueueController.build()` from watching the download
  /// directory (otherwise every settings change would rebuild the worker
  /// and silently drop the whole queue).
  final String downloadRoot;

  String get episodeKey => '$subjectId::$sourceId::${episode.title}';
}

sealed class DownloadEvent {
  const DownloadEvent(this.request);

  final DownloadRequest request;
}

class DownloadQueued extends DownloadEvent {
  const DownloadQueued(super.request);
}

class DownloadProgress extends DownloadEvent {
  const DownloadProgress(super.request, this.received, this.total);

  final int received;
  final int total;
}

class DownloadCompleted extends DownloadEvent {
  const DownloadCompleted(super.request);
}

class DownloadFailed extends DownloadEvent {
  const DownloadFailed(super.request, this.message);

  final String message;
}

class DownloadCancelled extends DownloadEvent {
  const DownloadCancelled(super.request);
}

class DownloadWorker {
  DownloadWorker({
    required Dio dio,
    required MediaSource Function(String sourceId) sourceForId,
    required DownloadedEpisodeRepository repository,
  }) : _dio = dio,
       _sourceForId = sourceForId,
       _repository = repository;

  final Dio _dio;
  final MediaSource Function(String) _sourceForId;
  final DownloadedEpisodeRepository _repository;
  final _queue = <DownloadRequest>[];
  final _events = StreamController<DownloadEvent>.broadcast();
  CancelToken? _cancelToken;
  DownloadRequest? _active;
  Completer<void>? _idle;

  Stream<DownloadEvent> get events => _events.stream;
  Future<void> get whenIdle => _idle?.future ?? Future.value();

  void enqueue(DownloadRequest request) {
    if (request.sourceId != 'anime1' && request.sourceId != 'xifan') {
      throw ArgumentError.value(
        request.sourceId,
        'sourceId',
        'Unsupported source',
      );
    }
    if (_active?.episodeKey == request.episodeKey ||
        _queue.any((item) => item.episodeKey == request.episodeKey)) {
      return;
    }
    _queue.add(request);
    _events.add(DownloadQueued(request));
    _idle ??= Completer<void>();
    if (_active == null) unawaited(_drain());
  }

  void cancel(String episodeKey) {
    _queue.removeWhere((item) => item.episodeKey == episodeKey);
    if (_active?.episodeKey == episodeKey) _cancelToken?.cancel();
  }

  Future<void> _drain() async {
    while (_queue.isNotEmpty) {
      _active = _queue.removeAt(0);
      await _download(_active!);
      _active = null;
    }
    _idle?.complete();
    _idle = null;
  }

  Future<void> _download(DownloadRequest request) async {
    final directory = Directory(
      p.join(
        request.downloadRoot,
        request.sourceId,
        request.subjectId.toString(),
        request.episodeLabel,
      ),
    );
    _cancelToken = CancelToken();
    try {
      await directory.create(recursive: true);
      await _repository.upsert(
        DownloadedEpisodeWrite(
          sourceId: request.sourceId,
          subjectId: request.subjectId,
          episodeKey: request.episodeKey,
          subjectName: request.subjectName,
          episodeLabel: request.episodeLabel,
          localPath: directory.path,
          format: 'mp4',
          status: DownloadStatus.downloading,
        ),
      );
      final candidates = List<MediaPlaybackSource>.of(
        await _sourceForId(request.sourceId).resolvePlayback(request.episode),
      );
      final selected = candidates.firstWhere(
        (item) => item.url.toLowerCase().contains('.mp4'),
        orElse: () => candidates.first,
      );
      final url = await selected.prepare();
      final isHls = Uri.parse(url).path.toLowerCase().endsWith('.m3u8');
      final localPath = isHls
          ? p.join(directory.path, 'playlist.m3u8')
          : p.join(directory.path, 'video.mp4');
      final size = isHls
          ? (await HlsDownloader(_dio).download(
              manifestUrl: Uri.parse(url),
              targetDirectory: directory,
              headers: selected.headers,
              cancelToken: _cancelToken,
              onProgress: (received, total) =>
                  _events.add(DownloadProgress(request, received, total)),
            )).fileSizeBytes
          : await _downloadFile(url, localPath, selected.headers, request);
      await _repository.upsert(
        DownloadedEpisodeWrite(
          sourceId: request.sourceId,
          subjectId: request.subjectId,
          episodeKey: request.episodeKey,
          subjectName: request.subjectName,
          episodeLabel: request.episodeLabel,
          localPath: localPath,
          format: isHls ? 'hls' : 'mp4',
          status: DownloadStatus.completed,
          fileSizeBytes: size,
        ),
      );
      _events.add(DownloadCompleted(request));
    } catch (error) {
      if (error is DioException && CancelToken.isCancel(error)) {
        if (await directory.exists()) await directory.delete(recursive: true);
        await _repository.delete(request.episodeKey);
        _events.add(DownloadCancelled(request));
        return;
      }
      await _repository.upsert(
        DownloadedEpisodeWrite(
          sourceId: request.sourceId,
          subjectId: request.subjectId,
          episodeKey: request.episodeKey,
          subjectName: request.subjectName,
          episodeLabel: request.episodeLabel,
          localPath: directory.path,
          format: 'mp4',
          status: DownloadStatus.failed,
          errorMessage: error.toString(),
        ),
      );
      _events.add(DownloadFailed(request, error.toString()));
    } finally {
      _cancelToken = null;
    }
  }

  Future<int> _downloadFile(
    String url,
    String path,
    Map<String, String> headers,
    DownloadRequest request,
  ) async {
    await _dio.download(
      url,
      path,
      cancelToken: _cancelToken,
      options: Options(headers: headers),
      onReceiveProgress: (received, total) =>
          _events.add(DownloadProgress(request, received, total)),
    );
    return File(path).length();
  }
}
