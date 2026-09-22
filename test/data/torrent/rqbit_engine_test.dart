import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:animeko_flutter/data/torrent/rqbit_engine.dart';

class MockDio extends Mock implements Dio {}

Response<Map<String, dynamic>> _jsonResponse(Map<String, dynamic> body) =>
    Response(
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

    test(
      'picks the largest file when there are multiple and no episodeInSet given',
      () {
        const result = AddTorrentResult(
          id: 0,
          files: [
            TorrentFileInfo(index: 0, name: 'sample.mp4', length: 10),
            TorrentFileInfo(index: 1, name: 'episode.mp4', length: 1000),
          ],
        );
        expect(result.pickVideoFile(), 1);
      },
    );
  });

  group('RqbitEngine (Dio request construction)', () {
    late MockDio dio;
    late RqbitEngine engine;

    setUp(() {
      dio = MockDio();
      engine = RqbitEngine.forTesting(dio, port: 3030);
    });

    test('addTorrent POSTs raw bytes to /torrents', () async {
      when(
        () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
      ).thenAnswer(
        (_) async => _jsonResponse({
          'id': 0,
          'details': {
            'files': [
              {'name': 'a.mp4', 'length': 100},
            ],
          },
        }),
      );

      final bytes = [1, 2, 3];
      final result = await engine.addTorrent(bytes);

      expect(result.id, 0);
      expect(result.files.single.name, 'a.mp4');
      expect(result.files.single.length, 100);

      final captured = verify(
        () => dio.post<Map<String, dynamic>>(
          captureAny(),
          data: captureAny(named: 'data'),
        ),
      ).captured;
      expect(captured[0], 'http://127.0.0.1:3030/torrents');
      expect(captured[1], bytes);
    });

    test('streamUrl builds the correct loopback URL', () {
      final url = engine.streamUrl(5, fileIndex: 2);
      expect(url, 'http://127.0.0.1:3030/torrents/5/stream/2');
    });

    test('deleteTorrent POSTs to /torrents/{id}/delete', () async {
      when(
        () => dio.post<dynamic>(any()),
      ).thenAnswer((_) async => _jsonResponse({}));

      await engine.deleteTorrent(7);

      verify(
        () => dio.post<dynamic>('http://127.0.0.1:3030/torrents/7/delete'),
      ).called(1);
    });

    test(
      'deleteTorrent swallows DioException (cleanup failures are non-fatal)',
      () async {
        when(
          () => dio.post<dynamic>(any()),
        ).thenThrow(DioException(requestOptions: RequestOptions(path: '/')));

        // Should not throw.
        await engine.deleteTorrent(7);
      },
    );

    test(
      'deleteTorrent rethrows non-Dio exceptions instead of swallowing them',
      () async {
        when(() => dio.post<dynamic>(any())).thenThrow(StateError('boom'));

        await expectLater(engine.deleteTorrent(7), throwsA(isA<StateError>()));
      },
    );
  });

  group('RqbitEngine.resolveBinaryPath', () {
    // A GUI-launched macOS .app inherits a minimal PATH that does NOT
    // include /opt/homebrew/bin, so a bare 'rqbit' lookup fails with
    // "ProcessException: No such file or directory".
    const guiPath = '/usr/bin:/bin:/usr/sbin:/sbin';
    const appExecutable = '/Applications/AniMeow.app/Contents/MacOS/AniMeow';
    const bundled = '/Applications/AniMeow.app/Contents/Resources/rqbit';

    String resolve({
      Map<String, String> environment = const {'PATH': guiPath},
      String resolvedExecutable = appExecutable,
      required Set<String> existing,
    }) => RqbitEngine.resolveBinaryPath(
      environment: environment,
      resolvedExecutable: resolvedExecutable,
      isExecutable: existing.contains,
    );

    test('prefers the binary bundled inside the .app Resources dir', () {
      expect(resolve(existing: {bundled, '/opt/homebrew/bin/rqbit'}), bundled);
    });

    test('honours the ANIMEKO_RQBIT_PATH override above everything else', () {
      expect(
        resolve(
          environment: const {'PATH': guiPath, 'ANIMEKO_RQBIT_PATH': '/tmp/rq'},
          existing: {'/tmp/rq', bundled, '/opt/homebrew/bin/rqbit'},
        ),
        '/tmp/rq',
      );
    });

    test('falls back to entries of PATH when nothing is bundled', () {
      expect(
        resolve(
          environment: const {'PATH': '/usr/bin:/my/tools'},
          existing: {'/my/tools/rqbit'},
        ),
        '/my/tools/rqbit',
      );
    });

    test('finds a Homebrew install even when it is absent from PATH', () {
      expect(
        resolve(existing: {'/opt/homebrew/bin/rqbit'}),
        '/opt/homebrew/bin/rqbit',
      );
    });

    test('finds an Intel-Homebrew / MacPorts install', () {
      expect(
        resolve(existing: {'/usr/local/bin/rqbit'}),
        '/usr/local/bin/rqbit',
      );
      expect(
        resolve(existing: {'/opt/local/bin/rqbit'}),
        '/opt/local/bin/rqbit',
      );
    });

    test('throws an actionable error listing where it looked', () {
      Object? error;
      try {
        resolve(existing: const {});
      } catch (e) {
        error = e;
      }
      expect(error, isA<RqbitBinaryNotFoundException>());
      final message = error.toString();
      // Must tell the user how to fix it, not just "No such file or directory".
      expect(message, contains('brew install rqbit'));
      expect(message, contains('ANIMEKO_RQBIT_PATH'));
      expect(message, contains('/opt/homebrew/bin/rqbit'));
      expect(
        (error as RqbitBinaryNotFoundException).searchedPaths,
        contains(bundled),
      );
    });
  });
}
