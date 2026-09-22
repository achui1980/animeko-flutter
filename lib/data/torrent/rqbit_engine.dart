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

/// Thrown when no usable `rqbit` executable can be located.
///
/// Carries a user-actionable message: the raw
/// `ProcessException: No such file or directory` that `Process.start` throws
/// says nothing about *which* binary is missing or how to install it, and it
/// is surfaced verbatim in the player's "播放失败" panel.
class RqbitBinaryNotFoundException implements Exception {
  const RqbitBinaryNotFoundException(this.searchedPaths);

  /// Every path that was probed, in resolution order.
  final List<String> searchedPaths;

  @override
  String toString() =>
      '未找到 rqbit 可执行文件，BT/磁力链接无法播放。\n'
      '请先安装：brew install rqbit\n'
      '若已安装在非标准位置，可设置环境变量 ANIMEKO_RQBIT_PATH 指向该可执行文件。\n'
      '已尝试以下路径：${searchedPaths.join(', ')}';
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

    final process = await Process.start(_rqbitBinaryPath(), [
      '--http-api-listen-addr',
      '127.0.0.1:0',
      // rqbit's `--listen-port 0` does NOT mean "pick a random port" for
      // the `server` subcommand -- it falls back to the hardcoded
      // default of 4240 regardless (verified empirically: two instances
      // both passed `--listen-port 0` and the second still failed with
      // "Address already in use" on 4240). So we reserve an actual free
      // ephemeral port ourselves and pass its number explicitly. This
      // avoids collisions with a leftover rqbit process from a previous
      // run (e.g. after a force-quit that skipped shutdown()), another
      // app using rqbit, etc. -- which otherwise makes rqbit exit before
      // ever printing "started HTTP API", and _readAssignedPort() throw
      // "Bad state: No element" on the exhausted stdout stream.
      '--listen-port',
      '${await _reserveEphemeralPort()}',
      '--disable-upnp-port-forward',
      '--disable-dht-persistence',
      'server',
      'start',
      await _downloadDir(),
    ]);
    unawaited(
      process.exitCode.then((_) {
        // Only clear state if this exit event belongs to the process we are
        // still tracking. Without this identity check, a late exit event from
        // a previously-killed process (e.g. right after shutdown() is followed
        // by a fresh ensureStarted() that started a new process) could wipe
        // out the new process's state.
        if (identical(_process, process)) {
          _process = null;
          _port = null;
        }
      }),
    );

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

  String _rqbitBinaryPath() => resolveBinaryPath(
    environment: Platform.environment,
    resolvedExecutable: Platform.resolvedExecutable,
    isExecutable: _isExecutableFile,
  );

  static bool _isExecutableFile(String path) {
    final file = File(path);
    if (!file.existsSync()) return false;
    // Directories report existsSync() == false through File, so an existing
    // File here is either a regular file or a symlink to one. We do not check
    // the exec bit: a present-but-not-executable binary should surface
    // rqbit's own ProcessException rather than be silently skipped in favour
    // of a different install.
    return true;
  }

  /// Locates the `rqbit` sidecar executable.
  ///
  /// A bare `Process.start('rqbit')` only works when the app inherits a
  /// developer shell's PATH (i.e. `flutter run` from a terminal). A macOS
  /// `.app` launched from Finder/Dock gets the minimal launchd PATH
  /// (`/usr/bin:/bin:/usr/sbin:/sbin`) which excludes `/opt/homebrew/bin`,
  /// so the same call fails with "ProcessException: No such file or
  /// directory" and every BT/magnet source becomes unplayable.
  ///
  /// Resolution order (first hit wins):
  /// 1. `ANIMEKO_RQBIT_PATH` env var — escape hatch for custom installs.
  /// 2. A binary bundled in the app (`Contents/Resources/rqbit` on macOS,
  ///    or next to the executable elsewhere) — for future self-contained
  ///    distribution.
  /// 3. Entries of `PATH`.
  /// 4. Well-known package-manager locations, since PATH is unreliable for
  ///    GUI launches.
  ///
  /// Throws [RqbitBinaryNotFoundException] with an actionable message when
  /// nothing is found. Exposed for testing; inject [isExecutable] to avoid
  /// touching the real filesystem.
  static String resolveBinaryPath({
    required Map<String, String> environment,
    required String resolvedExecutable,
    required bool Function(String path) isExecutable,
  }) {
    final executableName = Platform.isWindows ? 'rqbit.exe' : 'rqbit';
    final override = environment['ANIMEKO_RQBIT_PATH'];
    final candidates = <String>[
      if (override != null && override.isNotEmpty) override,
      // macOS bundle layout: Contents/MacOS/<exe> -> Contents/Resources/<exe>.
      _join([
        _dirname(_dirname(resolvedExecutable)),
        'Resources',
        executableName,
      ]),
      _join([_dirname(resolvedExecutable), executableName]),
      for (final dir in (environment['PATH'] ?? '').split(
        Platform.isWindows ? ';' : ':',
      ))
        if (dir.isNotEmpty) _join([dir, executableName]),
      '/opt/homebrew/bin/$executableName',
      '/usr/local/bin/$executableName',
      '/opt/local/bin/$executableName',
    ];

    for (final candidate in candidates) {
      if (isExecutable(candidate)) return candidate;
    }
    throw RqbitBinaryNotFoundException(candidates);
  }

  static String _dirname(String path) {
    final index = path.lastIndexOf(Platform.pathSeparator);
    if (index <= 0) return path;
    return path.substring(0, index);
  }

  static String _join(List<String> parts) => parts
      .map(
        (part) => part.endsWith(Platform.pathSeparator)
            ? part.substring(0, part.length - 1)
            : part,
      )
      .join(Platform.pathSeparator);

  Future<String> _downloadDir() async {
    final dir = await Directory.systemTemp.createTemp('animeko_bt_');
    return dir.path;
  }

  /// Binds an ephemeral socket to let the OS pick a free TCP port, reads
  /// back its number, then closes it immediately so rqbit can bind the
  /// same port for BT peer connections. Small TOCTOU race (another process
  /// could grab the port in between), but far safer than a hardcoded port.
  Future<int> _reserveEphemeralPort() async {
    final socket = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
    final port = socket.port;
    await socket.close();
    return port;
  }

  Future<int> _readAssignedPort(Process process) async {
    final stderrLines = <String>[];
    final stderrSubscription = process.stderr
        .transform(const SystemEncoding().decoder)
        .listen(stderrLines.add);
    try {
      final firstLine = await process.stdout
          .transform(const SystemEncoding().decoder)
          .firstWhere((line) => line.contains('started HTTP API'));
      final match = RegExp(r':(\d+)$').firstMatch(firstLine.trim());
      return int.parse(match!.group(1)!);
    } on StateError {
      // stdout ended without ever printing the expected line -- rqbit
      // exited early (e.g. a port conflict, missing binary permissions,
      // corrupt download dir). Surface *why* instead of the bare
      // "Bad state: No element" from the exhausted stream.
      final exitCode = await process.exitCode;
      final stderrText = stderrLines.join().trim();
      throw StateError(
        'rqbit exited with code $exitCode before printing "started HTTP '
        'API"${stderrText.isEmpty ? '' : ': $stderrText'}',
      );
    } finally {
      await stderrSubscription.cancel();
    }
  }
}

@Riverpod(keepAlive: true)
RqbitEngine rqbitEngine(Ref ref) => RqbitEngine();
