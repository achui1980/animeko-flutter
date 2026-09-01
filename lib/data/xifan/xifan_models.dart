import '../../domain/media/media_source.dart';

/// A search-result "bangumi" (anime series) page on 稀饭动漫.
/// `id` is the numeric ID used in `/bangumi/<id>.html`.
class XifanBangumi implements MediaCandidate {
  const XifanBangumi({required this.id, required this.title});

  final int id;
  @override
  final String title;

  @override
  String get sourceId => 'xifan';
}

/// A single episode: one entry in a bangumi's episode list.
class XifanEpisode implements MediaEpisode {
  const XifanEpisode({required this.title, required this.watchPageUrl});

  /// Episode label, e.g. `第01集`.
  @override
  final String title;

  /// Absolute URL of the watch page
  /// (`/watch/<bangumiId>/<line>/<episode>.html`), passed to
  /// [XifanApi.resolvePlaybackUrl].
  final String watchPageUrl;

  @override
  String get sourceId => 'xifan';
}

/// A resolved, playable video source for one episode. 稀饭动漫's video CDN
/// (`apn.moedot.net` -> `hydownload.pan.wo.cn`) is fully unauthenticated
/// and needs zero headers -- verified live (2026-09-01) via a plain,
/// header-less range request that returned `206 Partial Content` with
/// real MP4 bytes.
class XifanPlaybackSource implements MediaPlaybackSource {
  const XifanPlaybackSource({required this.url, this.headers = const {}});

  @override
  final String url;
  @override
  final Map<String, String> headers;
}
