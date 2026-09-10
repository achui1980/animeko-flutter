import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'rqbit_engine.g.dart';

class TorrentFileInfo {
  const TorrentFileInfo({
    required this.index,
    required this.name,
    required this.length,
  });

  final int index;
  final String name;
  final int length;
}

/// Result of adding a torrent to the rqbit sidecar.
class AddTorrentResult {
  const AddTorrentResult({required this.id, required this.files});

  final int id;
  final List<TorrentFileInfo> files;

  /// Picks which file inside a (possibly multi-file) torrent to stream.
  /// v1 heuristic: pick the largest file. [episodeInSet] is accepted for
  /// forward-compatibility with multi-file-per-episode torrents but is not
  /// yet used to disambiguate (see design doc Limitations section).
  int pickVideoFile({int? episodeInSet}) {
    var best = files.first;
    for (final file in files) {
      if (file.length > best.length) best = file;
    }
    return best.index;
  }
}

/// Manages a single `rqbit` sidecar process and talks to its JSON HTTP API.
///
/// v1 scope: online stream-only. [deleteTorrent] always forgets the torrent
/// and deletes its downloaded files (no retained/offline cache).
class RqbitEngine {
  RqbitEngine();

  /// Test-only constructor that skips process management and talks to a
  /// pre-configured [Dio] on a fixed port.
  RqbitEngine.forTesting(Dio dio, {required int port})
      : _dio = dio,
        _port = port;

  Dio? _dio;
  int? _port;
  Process? _process;

  Future<void> ensureStarted() async {
    if (_process != null && _port != null) return;

    final process = await Process.start(
      _rqbitBinaryPath(),
      [
        '--http-api-listen-addr',
        '127.0.0.1:0',
        '--disable-upnp-port-forward',
        '--disable-dht-persistence',
        'server',
        'start',
        await _downloadDir(),
      ],
    );
    unawaited(process.exitCode.then((_) {
      // Only clear state if this exit event belongs to the process we are
      // still tracking. Without this identity check, a late exit event from
      // a previously-killed process (e.g. right after shutdown() is followed
      // by a fresh ensureStarted() that started a new process) could wipe
      // out the new process's state.
      if (identical(_process, process)) {
        _process = null;
        _port = null;
      }
    }));

    try {
      _port = await _readAssignedPort(process);
    } catch (e) {
      // Failed to read the assigned port (e.g. rqbit crashed before
      // printing the expected "started HTTP API" line). Kill the
      // half-started process and leave fields null so a later
      // ensureStarted() call starts fresh instead of leaking this process.
      process.kill();
      rethrow;
    }
    _process = process;
    // Bounded so a hung rqbit sidecar (or a request that never completes,
    // e.g. an unreachable tracker during add) fails within a fixed time
    // instead of leaving prepare() hanging indefinitely (see design doc
    // 4.4: "POST /torrents: 设定一个保守超时（如 10 秒）防止极端情况卡死").
    _dio = Dio(
      BaseOptions(
        baseUrl: 'http://127.0.0.1:$_port',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );
  }

  Future<AddTorrentResult> addTorrent(List<int> torrentBytes) async {
    final response = await _dioClient.post<Map<String, dynamic>>(
      '$_base/torrents',
      data: torrentBytes,
    );
    final data = response.data!;
    final details = data['details'] as Map<String, dynamic>;
    final filesJson = details['files'] as List<dynamic>;
    final files = [
      for (var i = 0; i < filesJson.length; i++)
        TorrentFileInfo(
          index: i,
          name: filesJson[i]['name'] as String,
          length: filesJson[i]['length'] as int,
        ),
    ];
    return AddTorrentResult(id: data['id'] as int, files: files);
  }

  String streamUrl(int torrentId, {required int fileIndex}) {
    return '$_base/torrents/$torrentId/stream/$fileIndex';
  }

  Future<void> deleteTorrent(int torrentId) async {
    try {
      await _dioClient.post<dynamic>('$_base/torrents/$torrentId/delete');
    } on DioException {
      // Cleanup failures are non-fatal: worst case is extra disk usage.
      // Deliberately narrower than a blanket `catch` so that programming
      // errors (e.g. calling this before ensureStarted() has completed,
      // which would throw a null-check error on `_dioClient`/`_base`) are
      // not silently swallowed.
    }
  }

  Future<void> shutdown() async {
    _process?.kill();
    _process = null;
    _port = null;
  }

  Dio get _dioClient => _dio!;
  String get _base => 'http://127.0.0.1:${_port!}';

  String _rqbitBinaryPath() {
    // TODO(实施阶段): 确定 rqbit 二进制在打包后的 macOS .app 内的实际路径
    // （例如 macos/Runner/Resources/rqbit），当前返回占位路径，供 ensureStarted()
    // 在未打包环境下于 PATH 中查找同名可执行文件。
    return 'rqbit';
  }

  Future<String> _downloadDir() async {
    final dir = await Directory.systemTemp.createTemp('animeko_bt_');
    return dir.path;
  }

  Future<int> _readAssignedPort(Process process) async {
    final firstLine = await process.stdout
        .transform(const SystemEncoding().decoder)
        .firstWhere((line) => line.contains('started HTTP API'));
    final match = RegExp(r':(\d+)$').firstMatch(firstLine.trim());
    return int.parse(match!.group(1)!);
  }
}

@Riverpod(keepAlive: true)
RqbitEngine rqbitEngine(Ref ref) => RqbitEngine();
