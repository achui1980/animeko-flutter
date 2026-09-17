import 'dart:io';
import 'dart:typed_data';

import 'package:animeko_flutter/data/download/hls_downloader.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.responses);

  final Map<String, Object> responses;
  final cancelFutures = <Future<void>?>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    cancelFutures.add(cancelFuture);
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
}
