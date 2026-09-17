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

DownloadRequest _request(String sourceId, int subjectId) => DownloadRequest(
  subjectId: subjectId,
  subjectName: 'Subject $subjectId',
  sourceId: sourceId,
  episode: _Episode(sourceId, '$subjectId'),
  episodeLabel: '$subjectId',
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
        'https://cdn.example/first.mp4': [1],
        'https://cdn.example/second.mp4': [2],
      }),
      downloadRoot: root.path,
      sourceForId: (id) => sources[id]!,
      repository: repository,
    )..events.listen(events.add);

    worker.enqueue(_request('anime1', 1));
    worker.enqueue(_request('xifan', 2));
    await firstResolved.future;
    expect(resolved, ['first']);

    firstPrepared.complete('https://cdn.example/first.mp4');
    await worker.whenIdle;

    expect(resolved, ['first', 'second']);
    expect(events.whereType<DownloadCompleted>(), hasLength(2));
  });

  test('rejects a request from an unsupported source', () {
    final worker = DownloadWorker(
      dio: _dio({}),
      downloadRoot: root.path,
      sourceForId: (_) => throw UnimplementedError(),
      repository: repository,
    );

    expect(() => worker.enqueue(_request('rss', 1)), throwsArgumentError);
  });

  test('prefers an MP4 candidate for a Xifan request', () async {
    final events = <DownloadEvent>[];
    final worker = DownloadWorker(
      dio: _dio({
        'https://cdn.example/video.mp4': [1, 2, 3],
      }),
      downloadRoot: root.path,
      sourceForId: (_) => _XifanSource(const [
        XifanPlaybackSource(url: 'https://cdn.example/video.m3u8'),
        XifanPlaybackSource(url: 'https://cdn.example/video.mp4'),
      ]),
      repository: repository,
    )..events.listen(events.add);
    final request = _request('xifan', 1);

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
      downloadRoot: root.path,
      sourceForId: (_) => _Source('anime1', const [
        _PlaybackSource('https://cdn.example/video.mp4'),
      ]),
      repository: repository,
    );
    final request = _request('anime1', 1);

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
      downloadRoot: root.path,
      sourceForId: (_) => _Source('anime1', const [
        _PlaybackSource('https://cdn.example/video.mp4'),
      ]),
      repository: repository,
    );
    final request = _request('anime1', 1);

    worker.enqueue(request);
    await worker.whenIdle;

    final record = await repository.findByKey(request.episodeKey);
    expect(record!.status, DownloadStatus.failed.name);
    expect(record.errorMessage, isNotEmpty);
  });
}
