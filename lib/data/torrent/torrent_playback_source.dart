import 'package:dio/dio.dart';

import '../../domain/media/media_source.dart';
import '../rss/rss_media_source.dart';
import 'rqbit_engine.dart';

/// A [MediaPlaybackSource] backed by a BT release. [prepare] downloads the
/// `.torrent` file's raw bytes, hands them to the rqbit sidecar, and returns
/// its local HTTP stream URL. [dispose] tells the engine to forget the
/// torrent and delete its downloaded files (v1 scope: no retained cache).
class TorrentPlaybackSource extends MediaPlaybackSource {
  TorrentPlaybackSource({
    required this.release,
    required this.engine,
    Dio? dio,
  }) : _dio = dio ?? Dio();

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
  Future<String> prepare() async {
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
      await engine.deleteTorrent(id);
    }
  }
}
