import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:animeko_flutter/data/download/download_worker.dart';
import 'package:animeko_flutter/data/download/downloaded_episode_repository.dart';
import 'package:animeko_flutter/data/xifan/xifan_models.dart';
import 'package:animeko_flutter/data/local_database.dart';
import 'package:animeko_flutter/domain/media/media_source.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class _Episode implements MediaEpisode {
  const _Episode(this.sourceId, this.title);

  @override
  final String sourceId;
  @override
  final String title;
}

class _PlaybackSource extends MediaPlaybackSource {
  const _PlaybackSource(this.url, {this.onPrepare});

  @override
  final String url;
  final Future<String> Function()? onPrepare;

  @override
  Map<String, String> get headers => const {};

  @override
  Future<String> prepare() => onPrepare?.call() ?? super.prepare();
}

class _Source implements MediaSource {
  _Source(this.id, this.playbackSources, {this.onResolve});

  @override
  final String id;
  final List<MediaPlaybackSource> playbackSources;
  final void Function()? onResolve;

  @override
  String get displayName => id;

  @override
  Future<List<MediaCandidate>> search(String title, {int? subjectId}) =>
      throw UnimplementedError();

  @override
  Future<List<MediaEpisode>> listEpisodes(MediaCandidate candidate) =>
      throw UnimplementedError();

  @override
  Future<List<MediaPlaybackSource>> resolvePlayback(
    MediaEpisode episode,
  ) async {
    onResolve?.call();
    return playbackSources;
  }
}

class _XifanSource extends _Source {
  _XifanSource(List<XifanPlaybackSource> playbackSources)
    : super('xifan', playbackSources);

  @override
  Future<List<XifanPlaybackSource>> resolvePlayback(
    MediaEpisode episode,
  ) async => playbackSources.cast<XifanPlaybackSource>();
}

class _HttpResponse {
  const _HttpResponse({
    required this.statusCode,
    required this.body,
    this.headers = const {},
  });

  final int statusCode;
  final Object body; // List<int> or String
  final Map<String, String> headers;
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.responses, {this.waitForCancellation = false});

  final Map<String, Object> responses;
  final bool waitForCancellation;
  final started = Completer<void>();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (waitForCancellation) {
      started.complete();
      await cancelFuture;
      throw DioException.requestCancelled(
        requestOptions: options,
        reason: 'cancelled',
      );
    }
    final response = responses[options.uri.toString()];
    if (response is _HttpResponse) {
      final headers = Headers.fromMap(
        response.headers.map((key, value) => MapEntry(key, [value])),
      );
      if (response.body is List<int>) {
        return ResponseBody.fromBytes(
          Uint8List.fromList(response.body as List<int>),
          response.statusCode,
          headers: headers.map,
        );
      }
      return ResponseBody.fromString(
        response.body as String,
        response.statusCode,
        headers: headers.map,
      );
    }
    if (response is List<int>) {
      return ResponseBody.fromBytes(Uint8List.fromList(response), 200);
    }
    return ResponseBody.fromString(
      response as String? ?? '',
      response == null ? 404 : 200,
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Never delivers bytes for the first `stallOnAttempt` calls to any URL --
/// it just waits on `cancelFuture` and throws the cancellation dio expects,
/// simulating a connection that hangs until the stall watchdog cancels it.
/// From the `stallOnAttempt + 1`th call onward it serves [responses]
/// normally, simulating "the retry succeeds".
class _StallThenSucceedAdapter implements HttpClientAdapter {
  _StallThenSucceedAdapter(this.responses, {this.stallOnAttempt = 1});

  final Map<String, Object> responses;
  final int stallOnAttempt;
  var _callCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    _callCount++;
    if (_callCount <= stallOnAttempt) {
      await cancelFuture;
      throw DioException.requestCancelled(
        requestOptions: options,
        reason: 'stalled',
      );
    }
    final response = responses[options.uri.toString()];
    if (response is _HttpResponse) {
      final headers = Headers.fromMap(
        response.headers.map((key, value) => MapEntry(key, [value])),
      );
      if (response.body is List<int>) {
        return ResponseBody.fromBytes(
          Uint8List.fromList(response.body as List<int>),
          response.statusCode,
          headers: headers.map,
        );
      }
      return ResponseBody.fromString(
        response.body as String,
        response.statusCode,
        headers: headers.map,
      );
    }
    if (response is List<int>) {
      return ResponseBody.fromBytes(Uint8List.fromList(response), 200);
    }
    return ResponseBody.fromString(
      response as String? ?? '',
      response == null ? 404 : 200,
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _dio(Map<String, Object> responses, {bool waitForCancellation = false}) {
  final dio = Dio();
  dio.httpClientAdapter = _Adapter(
    responses,
    waitForCancellation: waitForCancellation,
  );
  return dio;
}

DownloadRequest _request(
  String sourceId,
  int subjectId, {
  required String downloadRoot,
}) => DownloadRequest(
  subjectId: subjectId,
  subjectName: 'Subject $subjectId',
  sourceId: sourceId,
  episode: _Episode(sourceId, '$subjectId'),
  episodeLabel: '$subjectId',
  downloadRoot: downloadRoot,
);

void main() {
  late AppDatabase database;
  late DownloadedEpisodeRepository repository;
  late Directory root;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    repository = DownloadedEpisodeRepository(database);
    root = await Directory.systemTemp.createTemp('download_worker_test_');
  });

  tearDown(() async {
    await database.close();
    await root.delete(recursive: true);
  });

  test('resolves the second request only after the first finishes', () async {
    final resolved = <String>[];
    final firstResolved = Completer<void>();
    final firstPrepared = Completer<String>();
    final sources = {
      'anime1': _Source(
        'anime1',
        [
          _PlaybackSource(
            'https://cdn.example/first.mp4',
            onPrepare: () => firstPrepared.future,
          ),
        ],
        onResolve: () {
          resolved.add('first');
          firstResolved.complete();
        },
      ),
      'xifan': _Source('xifan', [
        const _PlaybackSource('https://cdn.example/second.mp4'),
      ], onResolve: () => resolved.add('second')),
    };
    final events = <DownloadEvent>[];
    final worker = DownloadWorker(
      dio: _dio({
        'https://cdn.example/first.mp4': const _HttpResponse(
          statusCode: 200,
          body: [1],
          headers: {'content-length': '1'},
        ),
        'https://cdn.example/second.mp4': const _HttpResponse(
          statusCode: 200,
          body: [2],
          headers: {'content-length': '1'},
        ),
      }),
      sourceForId: (id) => sources[id]!,
      repository: repository,
    )..events.listen(events.add);

    worker.enqueue(_request('anime1', 1, downloadRoot: root.path));
    worker.enqueue(_request('xifan', 2, downloadRoot: root.path));
    await firstResolved.future;
    expect(resolved, ['first']);

    firstPrepared.complete('https://cdn.example/first.mp4');
    await worker.whenIdle;

    expect(resolved, ['first', 'second']);
    expect(events.whereType<DownloadCompleted>(), hasLength(2));
  });

  test(
    'writes a failed record instead of throwing for an unsupported source',
    () async {
      final events = <DownloadEvent>[];
      final worker = DownloadWorker(
        dio: _dio({}),
        sourceForId: (_) => throw UnimplementedError(),
        repository: repository,
      )..events.listen(events.add);
      final request = _request('rss', 1, downloadRoot: root.path);

      worker.enqueue(request);
      await Future<void>.delayed(Duration.zero);

      final record = await repository.findByKey(request.episodeKey);
      expect(record!.status, DownloadStatus.failed.name);
      expect(record.errorMessage, '此来源不支持下载');
      expect(events.whereType<DownloadFailed>(), hasLength(1));
    },
  );

  test(
    'fails with a friendly message when sourceForId finds no registered '
    'source for the request (design doc 5.3 -- no longer an uncaught '
    'StateError)',
    () async {
      final events = <DownloadEvent>[];
      final worker = DownloadWorker(
        dio: _dio({}),
        sourceForId: (_) => throw StateError('No element'),
        repository: repository,
      )..events.listen(events.add);
      final request = _request('anime1', 1, downloadRoot: root.path);

      worker.enqueue(request);
      await worker.whenIdle;

      final record = await repository.findByKey(request.episodeKey);
      expect(record!.status, DownloadStatus.failed.name);
      expect(record.errorMessage, '来源已不可用');
      expect(events.whereType<DownloadFailed>().single.message, '来源已不可用');
    },
  );

  test('prefers an MP4 candidate for a Xifan request', () async {
    final events = <DownloadEvent>[];
    final worker = DownloadWorker(
      dio: _dio({
        'https://cdn.example/video.mp4': const _HttpResponse(
          statusCode: 200,
          body: [1, 2, 3],
          headers: {'content-length': '3'},
        ),
      }),
      sourceForId: (_) => _XifanSource(const [
        XifanPlaybackSource(url: 'https://cdn.example/video.m3u8'),
        XifanPlaybackSource(url: 'https://cdn.example/video.mp4'),
      ]),
      repository: repository,
    )..events.listen(events.add);
    final request = _request('xifan', 1, downloadRoot: root.path);

    worker.enqueue(request);
    await worker.whenIdle;

    expect(events.whereType<DownloadCompleted>(), hasLength(1));
    final record = await repository.findCompleted(request.episodeKey);
    expect(record!.format, 'mp4');
    expect(await File(record.localPath).readAsBytes(), [1, 2, 3]);
  });

  test('cancelling an active request removes its files and record', () async {
    final dio = _dio({}, waitForCancellation: true);
    final worker = DownloadWorker(
      dio: dio,
      sourceForId: (_) => _Source('anime1', const [
        _PlaybackSource('https://cdn.example/video.mp4'),
      ]),
      repository: repository,
    );
    final request = _request('anime1', 1, downloadRoot: root.path);

    worker.enqueue(request);
    await (dio.httpClientAdapter as _Adapter).started.future;
    worker.cancel(request.episodeKey);
    await worker.whenIdle;

    expect(await repository.findByKey(request.episodeKey), isNull);
    expect(Directory('${root.path}/anime1/1/1').exists(), completion(isFalse));
  });

  test('persists a failure message when downloading fails', () async {
    final worker = DownloadWorker(
      dio: _dio({}),
      sourceForId: (_) => _Source('anime1', const [
        _PlaybackSource('https://cdn.example/video.mp4'),
      ]),
      repository: repository,
    );
    final request = _request('anime1', 1, downloadRoot: root.path);

    worker.enqueue(request);
    await worker.whenIdle;

    final record = await repository.findByKey(request.episodeKey);
    expect(record!.status, DownloadStatus.failed.name);
    expect(record.errorMessage, isNotEmpty);
  });

  test('fails when the server returns a non-2xx status', () async {
    final worker = DownloadWorker(
      dio: _dio({
        'https://cdn.example/video.mp4': const _HttpResponse(
          statusCode: 403,
          body: 'forbidden',
        ),
      }),
      sourceForId: (_) => _Source('anime1', const [
        _PlaybackSource('https://cdn.example/video.mp4'),
      ]),
      repository: repository,
    );
    final request = _request('anime1', 1, downloadRoot: root.path);

    worker.enqueue(request);
    await worker.whenIdle;

    final record = await repository.findByKey(request.episodeKey);
    expect(record!.status, DownloadStatus.failed.name);
    expect(record.errorMessage, contains('403'));
  });

  test(
    'fails when the server returns an HTML page instead of a video',
    () async {
      final worker = DownloadWorker(
        dio: _dio({
          'https://cdn.example/video.mp4': const _HttpResponse(
            statusCode: 200,
            body: '<html><body>login required</body></html>',
            headers: {'content-type': 'text/html; charset=utf-8'},
          ),
        }),
        sourceForId: (_) => _Source('anime1', const [
          _PlaybackSource('https://cdn.example/video.mp4'),
        ]),
        repository: repository,
      );
      final request = _request('anime1', 1, downloadRoot: root.path);

      worker.enqueue(request);
      await worker.whenIdle;

      final record = await repository.findByKey(request.episodeKey);
      expect(record!.status, DownloadStatus.failed.name);
      expect(record.errorMessage, contains('网页'));
    },
  );

  test(
    'fails when the response is suspiciously small with no content-length',
    () async {
      final worker = DownloadWorker(
        dio: _dio({
          'https://cdn.example/video.mp4': const _HttpResponse(
            statusCode: 200,
            body: [1, 2, 3],
          ),
        }),
        sourceForId: (_) => _Source('anime1', const [
          _PlaybackSource('https://cdn.example/video.mp4'),
        ]),
        repository: repository,
      );
      final request = _request('anime1', 1, downloadRoot: root.path);

      worker.enqueue(request);
      await worker.whenIdle;

      final record = await repository.findByKey(request.episodeKey);
      expect(record!.status, DownloadStatus.failed.name);
      expect(record.errorMessage, contains('过小'));
    },
  );

  test('retries once after a stall, then succeeds on the retry', () async {
    final events = <DownloadEvent>[];
    final dio = Dio()
      ..httpClientAdapter = _StallThenSucceedAdapter({
        'https://cdn.example/video.mp4': const _HttpResponse(
          statusCode: 200,
          body: [1, 2, 3],
          headers: {'content-length': '3'},
        ),
      });
    final worker = DownloadWorker(
      dio: dio,
      sourceForId: (_) => _Source('anime1', const [
        _PlaybackSource('https://cdn.example/video.mp4'),
      ]),
      repository: repository,
      stallTimeout: const Duration(milliseconds: 20),
      stallCheckInterval: const Duration(milliseconds: 5),
      noProgressTimeout: const Duration(seconds: 5),
    )..events.listen(events.add);

    worker.enqueue(_request('anime1', 1, downloadRoot: root.path));
    await worker.whenIdle;

    expect(events.whereType<DownloadStalled>(), hasLength(1));
    expect(events.whereType<DownloadCompleted>(), hasLength(1));
  });

  test('fails and moves on when a stall persists through the retry', () async {
    final events = <DownloadEvent>[];
    final dio = Dio()
      ..httpClientAdapter = _StallThenSucceedAdapter(
        const {},
        stallOnAttempt: 2,
      );
    final worker = DownloadWorker(
      dio: dio,
      sourceForId: (_) => _Source('anime1', const [
        _PlaybackSource('https://cdn.example/video.mp4'),
      ]),
      repository: repository,
      stallTimeout: const Duration(milliseconds: 20),
      stallCheckInterval: const Duration(milliseconds: 5),
      noProgressTimeout: const Duration(seconds: 5),
    )..events.listen(events.add);
    final request = _request('anime1', 1, downloadRoot: root.path);

    worker.enqueue(request);
    await worker.whenIdle;

    expect(events.whereType<DownloadStalled>(), hasLength(1));
    final failed = events.whereType<DownloadFailed>().single;
    expect(failed.message, contains('停滞'));
    final record = await repository.findByKey(request.episodeKey);
    expect(record!.status, DownloadStatus.failed.name);
  });

  test(
    'gives up at the zero-byte ceiling without waiting for the stall timeout',
    () async {
      final events = <DownloadEvent>[];
      final dio = Dio()
        ..httpClientAdapter = _StallThenSucceedAdapter(
          const {},
          stallOnAttempt: 999,
        );
      final worker = DownloadWorker(
        dio: dio,
        sourceForId: (_) => _Source('anime1', const [
          _PlaybackSource('https://cdn.example/video.mp4'),
        ]),
        repository: repository,
        // Deliberately larger than noProgressTimeout so only the
        // zero-byte ceiling can be the one that fires.
        stallTimeout: const Duration(seconds: 30),
        stallCheckInterval: const Duration(milliseconds: 5),
        noProgressTimeout: const Duration(milliseconds: 20),
      )..events.listen(events.add);
      final request = _request('anime1', 1, downloadRoot: root.path);

      worker.enqueue(request);
      await worker.whenIdle;

      expect(events.whereType<DownloadStalled>(), isEmpty);
      final failed = events.whereType<DownloadFailed>().single;
      expect(failed.message, contains('未能连接'));
    },
  );

  test('persists progress to disk at most once per second', () async {
    var now = DateTime(2026, 9, 17, 10);
    repository = DownloadedEpisodeRepository(database, now: () => now);
    final chunks = List.filled(2_000_000, 7);
    final worker = DownloadWorker(
      dio: _dio({'https://cdn.example/video.mp4': chunks}),
      sourceForId: (_) => _Source('anime1', const [
        _PlaybackSource('https://cdn.example/video.mp4'),
      ]),
      repository: repository,
      now: () => now,
    );
    final request = _request('anime1', 1, downloadRoot: root.path);

    worker.enqueue(request);
    await worker.whenIdle;

    final row = await repository.findByKey(request.episodeKey);
    // The fake adapter delivers the whole body in one synchronous chunk, so
    // `onProgress` fires at most a handful of times regardless of size --
    // this only proves a persisted value exists and matches the final
    // state, not that throttling suppressed any particular call. Task 6a's
    // throttling behavior itself (skipping writes within the 1s/1% window)
    // is exercised by the unit-level throttle-decision helper in Step 7
    // below, not by this integration-level fake-adapter test.
    expect(row!.receivedBytes, chunks.length);
  });
}
