import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:animeko_flutter/data/rss/rss_media_source.dart';
import 'package:animeko_flutter/data/rss/rss_parser.dart';
import 'package:animeko_flutter/data/torrent/rqbit_engine.dart';
import 'package:animeko_flutter/data/torrent/torrent_playback_source.dart';
import 'package:animeko_flutter/domain/media/title_parser.dart';

class MockDio extends Mock implements Dio {}

class MockRqbitEngine extends Mock implements RqbitEngine {}

Response<List<int>> _bytesResponse(List<int> bytes) => Response(
      data: bytes,
      requestOptions: RequestOptions(path: '/'),
      statusCode: 200,
    );

void main() {
  late MockDio dio;
  late MockRqbitEngine engine;
  late RssRelease release;

  setUp(() {
    dio = MockDio();
    engine = MockRqbitEngine();
    when(() => engine.ensureStarted()).thenAnswer((_) async {});
    release = RssRelease(
      item: const RssItem(
        title: '[Group][Show][10][1080P]',
        torrentUrl: 'https://mikan.tangbai.cc/Download/x/x.torrent',
        contentLength: 1000,
      ),
      parsed: parseTitle('[Group][Show][10][1080P]'),
    );
  });

  test('prepare() downloads the torrent bytes, adds it to the engine, and '
      'returns the stream URL', () async {
    final torrentBytes = [1, 2, 3];
    when(() => dio.get<List<int>>(
          any(),
          options: any(named: 'options'),
        )).thenAnswer((_) async => _bytesResponse(torrentBytes));
    when(() => engine.addTorrent(torrentBytes)).thenAnswer(
      (_) async => const AddTorrentResult(
        id: 42,
        files: [TorrentFileInfo(index: 0, name: 'a.mp4', length: 1000)],
      ),
    );
    when(() => engine.streamUrl(42, fileIndex: 0))
        .thenReturn('http://127.0.0.1:3030/torrents/42/stream/0');

    final source = TorrentPlaybackSource(release: release, engine: engine, dio: dio);
    final url = await source.prepare();

    expect(url, 'http://127.0.0.1:3030/torrents/42/stream/0');
    verify(() => engine.addTorrent(torrentBytes)).called(1);
  });

  test('dispose() calls engine.deleteTorrent with the torrent id from prepare()', () async {
    when(() => dio.get<List<int>>(
          any(),
          options: any(named: 'options'),
        )).thenAnswer((_) async => _bytesResponse([1]));
    when(() => engine.addTorrent(any())).thenAnswer(
      (_) async => const AddTorrentResult(
        id: 9,
        files: [TorrentFileInfo(index: 0, name: 'a.mp4', length: 1)],
      ),
    );
    when(() => engine.streamUrl(9, fileIndex: 0)).thenReturn('http://x/stream/0');
    when(() => engine.deleteTorrent(9)).thenAnswer((_) async {});

    final source = TorrentPlaybackSource(release: release, engine: engine, dio: dio);
    await source.prepare();
    await source.dispose();

    verify(() => engine.deleteTorrent(9)).called(1);
  });

  test('dispose() before prepare() is a no-op', () async {
    final source = TorrentPlaybackSource(release: release, engine: engine, dio: dio);
    await expectLater(source.dispose(), completes);
    verifyNever(() => engine.deleteTorrent(any()));
  });

  test('prepare() propagates errors from the engine', () async {
    when(() => dio.get<List<int>>(
          any(),
          options: any(named: 'options'),
        )).thenAnswer((_) async => _bytesResponse([1]));
    when(() => engine.addTorrent(any())).thenThrow(Exception('boom'));

    final source = TorrentPlaybackSource(release: release, engine: engine, dio: dio);
    await expectLater(source.prepare(), throwsException);
  });

  test('url getter throws before prepare() has been called', () {
    final source = TorrentPlaybackSource(release: release, engine: engine, dio: dio);
    expect(() => source.url, throwsStateError);
  });

  test('headers is always empty', () {
    final source = TorrentPlaybackSource(release: release, engine: engine, dio: dio);
    expect(source.headers, isEmpty);
  });
}
