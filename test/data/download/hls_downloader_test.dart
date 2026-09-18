import 'dart:io';
import 'dart:typed_data';

import 'package:animeko_flutter/data/download/hls_downloader.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.responses);

  final Map<String, Object> responses;
  final cancelFutures = <Future<void>?>[];
  final fetchedUrls = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    cancelFutures.add(cancelFuture);
    fetchedUrls.add(options.uri.toString());
    final response = responses[options.uri.toString()];
    if (response is String) return ResponseBody.fromString(response, 200);
    if (response is List<int>) {
      return ResponseBody.fromBytes(Uint8List.fromList(response), 200);
    }
    return ResponseBody.fromString('', 404);
  }

  @override
  void close({bool force = false}) {}
}

Dio fakeDio(Map<String, Object> responses) {
  final dio = Dio();
  dio.httpClientAdapter = _FakeAdapter(responses);
  return dio;
}

void main() {
  test('downloads media segments and rewrites their URI lines', () async {
    final target = await Directory.systemTemp.createTemp('hls_test_');
    addTearDown(() => target.delete(recursive: true));
    final dio = fakeDio({
      'https://cdn.example/episode/index.m3u8':
          '#EXTM3U\n#EXTINF:1,\npart-a.ts\n#EXTINF:1,\npart-b.ts\n#EXT-X-ENDLIST\n',
      'https://cdn.example/episode/part-a.ts': [1, 2],
      'https://cdn.example/episode/part-b.ts': [3, 4],
    });

    final result = await HlsDownloader(dio).download(
      manifestUrl: Uri.parse('https://cdn.example/episode/index.m3u8'),
      targetDirectory: target,
    );

    expect(await result.playlist.readAsString(), contains('segment_0000.ts'));
    expect(await File('${target.path}/segment_0001.ts').readAsBytes(), [3, 4]);
  });

  test('downloads the first variant from a master playlist', () async {
    final target = await Directory.systemTemp.createTemp('hls_test_');
    addTearDown(() => target.delete(recursive: true));
    final dio = fakeDio({
      'https://cdn.example/master.m3u8':
          '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1\nlow/index.m3u8\n#EXT-X-STREAM-INF:BANDWIDTH=2\nhigh/index.m3u8\n',
      'https://cdn.example/low/index.m3u8': '#EXTM3U\nfirst.ts\n',
      'https://cdn.example/low/first.ts': [1],
    });

    final result = await HlsDownloader(dio).download(
      manifestUrl: Uri.parse('https://cdn.example/master.m3u8'),
      targetDirectory: target,
    );

    expect(await result.playlist.readAsString(), contains('segment_0000.ts'));
    expect(await File('${target.path}/segment_0000.ts').readAsBytes(), [1]);
  });

  test('passes the cancellation token to segment downloads', () async {
    final target = await Directory.systemTemp.createTemp('hls_test_');
    addTearDown(() => target.delete(recursive: true));
    final dio = fakeDio({
      'https://cdn.example/episode/index.m3u8': '#EXTM3U\npart-a.ts\n',
      'https://cdn.example/episode/part-a.ts': [1],
    });
    final cancelToken = CancelToken();

    await HlsDownloader(dio).download(
      manifestUrl: Uri.parse('https://cdn.example/episode/index.m3u8'),
      targetDirectory: target,
      cancelToken: cancelToken,
    );

    final adapter = dio.httpClientAdapter as _FakeAdapter;
    expect(adapter.cancelFutures.last, same(cancelToken.whenCancel));
  });

  test('reports true downloaded/total segment counts via onProgress', () async {
    final target = await Directory.systemTemp.createTemp('hls_test_');
    addTearDown(() => target.delete(recursive: true));
    final dio = fakeDio({
      'https://cdn.example/episode/index.m3u8':
          '#EXTM3U\n#EXTINF:1,\npart-a.ts\n#EXTINF:1,\npart-b.ts\n#EXT-X-ENDLIST\n',
      'https://cdn.example/episode/part-a.ts': [1, 2],
      'https://cdn.example/episode/part-b.ts': [3, 4],
    });
    final calls = <(int, int)>[];

    await HlsDownloader(dio).download(
      manifestUrl: Uri.parse('https://cdn.example/episode/index.m3u8'),
      targetDirectory: target,
      onProgress: (received, total) => calls.add((received, total)),
    );

    // The old bug reported (received, 0) on every call, making progress
    // permanently indeterminate. Every call must now carry the real,
    // stable total segment count (2), and the final call must report
    // both segments as downloaded.
    expect(calls, isNotEmpty);
    for (final call in calls) {
      expect(call.$2, 2, reason: 'total segment count must never be 0');
    }
    expect(calls.last, (2, 2));
  });

  test('skips a segment that already exists and is non-empty on retry', () async {
    final target = await Directory.systemTemp.createTemp('hls_test_');
    addTearDown(() => target.delete(recursive: true));
    // Simulate a previous, interrupted attempt: segment 0 already saved,
    // segment 1 never started.
    await File(
      p.join(target.path, 'segment_0000.ts'),
    ).writeAsBytes([9, 9], flush: true);
    final dio = fakeDio({
      'https://cdn.example/episode/index.m3u8':
          '#EXTM3U\n#EXTINF:1,\npart-a.ts\n#EXTINF:1,\npart-b.ts\n#EXT-X-ENDLIST\n',
      // Deliberately no entry for part-a.ts: if the downloader tries to
      // re-fetch it, the fake adapter falls through to its 404 branch and
      // dio.downloadUri throws, failing the test.
      'https://cdn.example/episode/part-b.ts': [3, 4],
    });

    await HlsDownloader(dio).download(
      manifestUrl: Uri.parse('https://cdn.example/episode/index.m3u8'),
      targetDirectory: target,
    );

    final adapter = dio.httpClientAdapter as _FakeAdapter;
    expect(
      adapter.fetchedUrls,
      isNot(contains('https://cdn.example/episode/part-a.ts')),
    );
    // The pre-existing segment's bytes must be untouched.
    expect(
      await File(p.join(target.path, 'segment_0000.ts')).readAsBytes(),
      [9, 9],
    );
    expect(
      await File(p.join(target.path, 'segment_0001.ts')).readAsBytes(),
      [3, 4],
    );
  });
}
