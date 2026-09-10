import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:animeko_flutter/data/torrent/rqbit_engine.dart';

class MockDio extends Mock implements Dio {}

Response<Map<String, dynamic>> _jsonResponse(Map<String, dynamic> body) => Response(
      data: body,
      requestOptions: RequestOptions(path: '/'),
      statusCode: 200,
    );

void main() {
  group('AddTorrentResult.pickVideoFile', () {
    test('picks the single file when there is only one', () {
      const result = AddTorrentResult(
        id: 0,
        files: [TorrentFileInfo(index: 0, name: 'movie.mp4', length: 1000)],
      );
      expect(result.pickVideoFile(), 0);
    });

    test('picks the largest file when there are multiple and no episodeInSet given', () {
      const result = AddTorrentResult(
        id: 0,
        files: [
          TorrentFileInfo(index: 0, name: 'sample.mp4', length: 10),
          TorrentFileInfo(index: 1, name: 'episode.mp4', length: 1000),
        ],
      );
      expect(result.pickVideoFile(), 1);
    });
  });

  group('RqbitEngine (Dio request construction)', () {
    late MockDio dio;
    late RqbitEngine engine;

    setUp(() {
      dio = MockDio();
      engine = RqbitEngine.forTesting(dio, port: 3030);
    });

    test('addTorrent POSTs raw bytes to /torrents', () async {
      when(() => dio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
          )).thenAnswer((_) async => _jsonResponse({
            'id': 0,
            'details': {
              'files': [
                {'name': 'a.mp4', 'length': 100},
              ],
            },
          }));

      final bytes = [1, 2, 3];
      final result = await engine.addTorrent(bytes);

      expect(result.id, 0);
      expect(result.files.single.name, 'a.mp4');

      final captured = verify(() => dio.post<Map<String, dynamic>>(
            captureAny(),
            data: captureAny(named: 'data'),
          )).captured;
      expect(captured[0], 'http://127.0.0.1:3030/torrents');
      expect(captured[1], bytes);
    });

    test('streamUrl builds the correct loopback URL', () {
      final url = engine.streamUrl(5, fileIndex: 2);
      expect(url, 'http://127.0.0.1:3030/torrents/5/stream/2');
    });

    test('deleteTorrent POSTs to /torrents/{id}/delete', () async {
      when(() => dio.post<dynamic>(any())).thenAnswer((_) async => _jsonResponse({}));

      await engine.deleteTorrent(7);

      verify(() => dio.post<dynamic>('http://127.0.0.1:3030/torrents/7/delete')).called(1);
    });
  });
}
