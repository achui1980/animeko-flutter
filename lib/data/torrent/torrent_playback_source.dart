import 'package:dio/dio.dart';

import '../../domain/media/media_source.dart';
import '../rss/rss_media_source.dart';
import 'rqbit_engine.dart';

/// A [MediaPlaybackSource] backed by a BT release. [prepare] downloads the
/// `.torrent` file's raw bytes, hands them to the rqbit sidecar, and returns
/// its local HTTP stream URL. [dispose] tells the engine to forget the
/// torrent and delete its downloaded files (v1 scope: no retained cache).
///
/// Both [prepare] and [dispose] are safe to call more than once:
/// - Calling [prepare] again after it has already succeeded returns the
///   cached stream URL instead of adding a second torrent to the engine
///   (which would otherwise leak the first one, since only the most recent
///   `_torrentId` would remain reachable for cleanup).
/// - Calling [dispose] again after it has already run (or before [prepare]
///   ever completed) is a no-op; it never issues a second
///   `engine.deleteTorrent` call for the same id.
class TorrentPlaybackSource extends MediaPlaybackSource {
  TorrentPlaybackSource({required this.release, required this.engine, Dio? dio})
    : _dio = dio ?? Dio();

  final RssRelease release;
  final RqbitEngine engine;
  final Dio _dio;

  int? _torrentId;
  String? _preparedUrl;

  @override
  String get url {
    final prepared = _preparedUrl;
    if (prepared == null) {
      throw StateError(
        'TorrentPlaybackSource.url read before prepare() completed',
      );
    }
    return prepared;
  }

  @override
  Map<String, String> get headers => const {};

  @override
  String? get label {
    final parsed = release.parsed;
    final parts = <String>[
      if (parsed.alliance.isNotEmpty) parsed.alliance,
      if (parsed.resolution != null) parsed.resolution!,
      if (parsed.subtitleLanguages.isNotEmpty)
        parsed.subtitleLanguages.join('/'),
    ];
    return parts.isEmpty ? null : parts.join(' ');
  }

  @override
  Future<String> prepare() async {
    final alreadyPrepared = _preparedUrl;
    if (alreadyPrepared != null) {
      return alreadyPrepared;
    }
    await engine.ensureStarted();
    final response = await _dio.get<List<int>>(
      release.item.torrentUrl,
      options: Options(responseType: ResponseType.bytes),
    );
    final result = await engine.addTorrent(response.data!);
    _torrentId = result.id;
    final fileIndex = result.pickVideoFile(episodeInSet: null);
    _preparedUrl = engine.streamUrl(result.id, fileIndex: fileIndex);
    return _preparedUrl!;
  }

  @override
  Future<void> dispose() async {
    final id = _torrentId;
    if (id != null) {
      _torrentId = null;
      await engine.deleteTorrent(id);
    }
  }
}
