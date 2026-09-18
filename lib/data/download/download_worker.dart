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

/// Emitted once per stall-triggered retry (not on the final give-up) so the
/// UI can show "已停滞，正在重试" -- see [DownloadQueueItem.isStalled] in
/// `download_queue_controller.dart`. Purely transient: never persisted to
/// the [DownloadedEpisodeRepository].
class DownloadStalled extends DownloadEvent {
  const DownloadStalled(super.request);
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

/// Thrown by [DownloadWorker._downloadFile] when the HTTP response is
/// well-formed (no network/cancel error) but clearly isn't the video it
/// claimed to be -- an expired-cookie/anti-leech HTML error page, a
/// non-2xx status, or a response too small to plausibly be a video.
/// Caught by the same generic failure path as any other download
/// error; [toString] is what ends up in the persisted `errorMessage`.
class DownloadValidationException implements Exception {
  const DownloadValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Threaded through [CancelToken.cancel] so `_attempt`'s catch block can
/// tell a stall-triggered cancellation apart from a real user-initiated
/// [DownloadWorker.cancel] call.
enum _StallSignal { retryOnce, giveUp }

enum _AttemptResult { done, stalledRetry }

class DownloadWorker {
  DownloadWorker({
    required Dio dio,
    required MediaSource Function(String sourceId) sourceForId,
    required DownloadedEpisodeRepository repository,
    this.stallTimeout = const Duration(seconds: 30),
    this.noProgressTimeout = const Duration(minutes: 2),
    this.stallCheckInterval = const Duration(seconds: 1),
    DateTime Function() now = DateTime.now,
  }) : _dio = dio,
       _sourceForId = sourceForId,
       _repository = repository,
       _now = now;

  final Dio _dio;
  final MediaSource Function(String) _sourceForId;
  final DownloadedEpisodeRepository _repository;
  final DateTime Function() _now;

  /// How long without a new [DownloadProgress] event before the active
  /// attempt is considered stalled. Production default 30s per the design
  /// doc; tests inject millisecond-scale values instead of waiting real
  /// seconds.
  final Duration stallTimeout;

  /// Absolute ceiling on how long a request may sit at zero received bytes
  /// (measured from the moment it is dequeued, not reset by the one
  /// automatic stall-retry) before it is failed outright. Production
  /// default 2 minutes.
  final Duration noProgressTimeout;

  /// How often the watchdog re-checks elapsed time.
  final Duration stallCheckInterval;

  final _queue = <DownloadRequest>[];
  final _events = StreamController<DownloadEvent>.broadcast();
  CancelToken? _cancelToken;
  DownloadRequest? _active;
  Completer<void>? _idle;

  Stream<DownloadEvent> get events => _events.stream;
  Future<void> get whenIdle => _idle?.future ?? Future.value();

  void enqueue(DownloadRequest request) {
    if (request.sourceId != 'anime1' && request.sourceId != 'xifan') {
      unawaited(_failUnsupportedSource(request));
      return;
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

  Future<void> _failUnsupportedSource(DownloadRequest request) async {
    const message = '此来源不支持下载';
    await _repository.upsert(
      DownloadedEpisodeWrite(
        sourceId: request.sourceId,
        subjectId: request.subjectId,
        episodeKey: request.episodeKey,
        subjectName: request.subjectName,
        episodeLabel: request.episodeLabel,
        localPath: '',
        episodeDir: null,
        format: 'mp4',
        status: DownloadStatus.failed,
        errorMessage: message,
      ),
    );
    _events.add(DownloadFailed(request, message));
  }

  void cancel(String episodeKey) {
    _queue.removeWhere((item) => item.episodeKey == episodeKey);
    if (_active?.episodeKey == episodeKey) _cancelToken?.cancel();
  }

  Future<void> _drain() async {
    while (_queue.isNotEmpty) {
      _active = _queue.removeAt(0);
      await _downloadWithStallRetry(_active!);
      _active = null;
    }
    _idle?.complete();
    _idle = null;
  }

  Future<void> _downloadWithStallRetry(DownloadRequest request) async {
    final first = await _attempt(request, hasRetried: false);
    if (first == _AttemptResult.stalledRetry) {
      await _attempt(request, hasRetried: true);
    }
  }

  Future<_AttemptResult> _attempt(
    DownloadRequest request, {
    required bool hasRetried,
  }) async {
    final directory = Directory(
      p.join(
        request.downloadRoot,
        request.sourceId,
        request.subjectId.toString(),
        request.episodeLabel,
      ),
    );
    _cancelToken = CancelToken();
    var lastProgressAt = _now();
    final startedAt = lastProgressAt;
    var receivedTotal = 0;
    // Which watchdog branch below actually triggered the give-up, so the
    // catch block can pick the right failure message. Deliberately tracked
    // as its own flag rather than re-derived from `receivedTotal == 0` at
    // catch time: a stall-repeat give-up (the second `if`, `hasRetried`
    // true) can *also* have received zero bytes overall (the connection
    // never delivered anything on either attempt), so `receivedTotal == 0`
    // alone can't tell the two give-up reasons apart.
    var gaveUpDueToZeroBytes = false;

    final watchdog = Timer.periodic(stallCheckInterval, (_) {
      final now = _now();
      if (receivedTotal == 0 &&
          now.difference(startedAt) >= noProgressTimeout) {
        gaveUpDueToZeroBytes = true;
        _cancelToken?.cancel(_StallSignal.giveUp);
        return;
      }
      if (now.difference(lastProgressAt) >= stallTimeout) {
        if (hasRetried) {
          _cancelToken?.cancel(_StallSignal.giveUp);
        } else {
          _events.add(DownloadStalled(request));
          _cancelToken?.cancel(_StallSignal.retryOnce);
        }
      }
    });

    var isHls = false;
    DateTime? lastPersistedAt;
    var lastPersistedPercent = -1;

    void onProgress(int received, int total) {
      receivedTotal = received;
      lastProgressAt = _now();
      _events.add(DownloadProgress(request, received, total));

      final percent = total > 0 ? received * 100 ~/ total : -1;
      final dueByTime =
          lastPersistedAt == null ||
          lastProgressAt.difference(lastPersistedAt!) >=
              const Duration(seconds: 1);
      final dueByPercent = percent >= 0 && percent != lastPersistedPercent;
      if (!dueByTime && !dueByPercent) return;
      lastPersistedAt = lastProgressAt;
      lastPersistedPercent = percent;
      unawaited(
        _repository.updateProgress(
          request.episodeKey,
          receivedBytes: isHls ? null : received,
          totalBytes: isHls ? null : (total > 0 ? total : null),
          downloadedSegments: isHls ? received : null,
          totalSegments: isHls ? (total > 0 ? total : null) : null,
        ),
      );
    }

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
          episodeDir: directory.path,
          format: 'mp4',
          status: DownloadStatus.downloading,
        ),
      );
      // `sourceForId` throws `StateError` (`Iterable.firstWhere`'s default
      // no-match behavior) when the caller's media-source registry no
      // longer has an entry for `request.sourceId` -- see the design doc's
      // decision (5.3) to turn this into a friendly failed record instead
      // of letting the raw `StateError` message reach the UI. Resolved as
      // its own try/catch (rather than folding into the outer catch below)
      // so only this lookup gets the friendly message; every other
      // failure in this attempt still reports its real error text.
      MediaSource source;
      try {
        source = _sourceForId(request.sourceId);
      } on StateError {
        const message = '来源已不可用';
        await _repository.upsert(
          DownloadedEpisodeWrite(
            sourceId: request.sourceId,
            subjectId: request.subjectId,
            episodeKey: request.episodeKey,
            subjectName: request.subjectName,
            episodeLabel: request.episodeLabel,
            localPath: directory.path,
            episodeDir: directory.path,
            format: 'mp4',
            status: DownloadStatus.failed,
            errorMessage: message,
          ),
        );
        _events.add(DownloadFailed(request, message));
        return _AttemptResult.done;
      }
      final candidates = List<MediaPlaybackSource>.of(
        await source.resolvePlayback(request.episode),
      );
      final selected = candidates.firstWhere(
        (item) => item.url.toLowerCase().contains('.mp4'),
        orElse: () => candidates.first,
      );
      final url = await selected.prepare();
      isHls = Uri.parse(url).path.toLowerCase().endsWith('.m3u8');
      final localPath = isHls
          ? p.join(directory.path, 'playlist.m3u8')
          : p.join(directory.path, 'video.mp4');
      final size = isHls
          ? (await HlsDownloader(_dio).download(
              manifestUrl: Uri.parse(url),
              targetDirectory: directory,
              headers: selected.headers,
              cancelToken: _cancelToken,
              onProgress: onProgress,
            )).fileSizeBytes
          : await _downloadFile(url, localPath, selected.headers, onProgress);
      await _repository.upsert(
        DownloadedEpisodeWrite(
          sourceId: request.sourceId,
          subjectId: request.subjectId,
          episodeKey: request.episodeKey,
          subjectName: request.subjectName,
          episodeLabel: request.episodeLabel,
          localPath: localPath,
          episodeDir: directory.path,
          format: isHls ? 'hls' : 'mp4',
          status: DownloadStatus.completed,
          fileSizeBytes: size,
        ),
      );
      _events.add(DownloadCompleted(request));
      return _AttemptResult.done;
    } catch (error) {
      if (error is DioException && CancelToken.isCancel(error)) {
        final reason = error.error;
        if (reason == _StallSignal.retryOnce) {
          return _AttemptResult.stalledRetry;
        }
        if (reason == _StallSignal.giveUp) {
          final message = gaveUpDueToZeroBytes
              ? '一直未能连接到下载源，已跳过'
              : '下载已停滞，重试后仍无进展，已跳过';
          await _repository.upsert(
            DownloadedEpisodeWrite(
              sourceId: request.sourceId,
              subjectId: request.subjectId,
              episodeKey: request.episodeKey,
              subjectName: request.subjectName,
              episodeLabel: request.episodeLabel,
              localPath: directory.path,
              episodeDir: directory.path,
              format: 'mp4',
              status: DownloadStatus.failed,
              errorMessage: message,
            ),
          );
          _events.add(DownloadFailed(request, message));
          return _AttemptResult.done;
        }
        // A real user-initiated cancel() call.
        if (await directory.exists()) await directory.delete(recursive: true);
        await _repository.delete(request.episodeKey);
        _events.add(DownloadCancelled(request));
        return _AttemptResult.done;
      }
      await _repository.upsert(
        DownloadedEpisodeWrite(
          sourceId: request.sourceId,
          subjectId: request.subjectId,
          episodeKey: request.episodeKey,
          subjectName: request.subjectName,
          episodeLabel: request.episodeLabel,
          localPath: directory.path,
          episodeDir: directory.path,
          format: 'mp4',
          status: DownloadStatus.failed,
          errorMessage: error.toString(),
        ),
      );
      _events.add(DownloadFailed(request, error.toString()));
      return _AttemptResult.done;
    } finally {
      watchdog.cancel();
      _cancelToken = null;
    }
  }

  Future<int> _downloadFile(
    String url,
    String path,
    Map<String, String> headers,
    void Function(int received, int total) onProgress,
  ) async {
    final response = await _dio.download(
      url,
      path,
      cancelToken: _cancelToken,
      options: Options(headers: headers, validateStatus: (_) => true),
      onReceiveProgress: onProgress,
    );

    if (response.statusCode == null ||
        response.statusCode! < 200 ||
        response.statusCode! >= 300) {
      throw DownloadValidationException('下载失败（HTTP ${response.statusCode}）');
    }

    final contentType = response.headers.value('content-type') ?? '';
    if (contentType.toLowerCase().contains('text/html')) {
      throw const DownloadValidationException('源返回了网页而非视频（可能是防盗链或登录失效）');
    }

    final size = await File(path).length();
    final hasContentLength = response.headers.value('content-length') != null;
    if (size < 100 * 1024 && !hasContentLength) {
      throw const DownloadValidationException('返回内容过小，可能不是视频');
    }

    return size;
  }
}
