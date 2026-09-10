import '../../domain/media/media_source.dart';

/// A search-result "bangumi" (anime series) page on 樱花动漫.
/// `id` is the numeric ID used in `/index.php/vod/detail/id/<id>.html`.
class YinghuaBangumi implements MediaCandidate {
  const YinghuaBangumi({required this.id, required this.title});

  final int id;
  @override
  final String title;

  @override
  String get sourceId => 'yinghua';
}

/// One logical episode, merged across all "线路" (line) blocks that
/// expose it under the same title. [playPageUrls] is ordered by line
/// appearance on the detail page; index 0 is the default/primary line,
/// the rest are fallback candidates.
class YinghuaEpisode implements MediaEpisode {
  const YinghuaEpisode({required this.title, required this.playPageUrls});

  /// Episode label, e.g. `第01集`.
  @override
  final String title;

  /// Absolute URLs of the play page, one per "线路" (line) that exposes
  /// this episode under the same title
  /// (`/index.php/vod/play/id/<id>/sid/<line>/nid/<episode>.html`),
  /// ordered by line appearance on the detail page. Passed to
  /// [YinghuaApi.resolvePlaybackUrl].
  final List<String> playPageUrls;

  @override
  String get sourceId => 'yinghua';
}

/// A resolved, playable video source for one episode. Unlike 稀饭动漫,
/// 樱花动漫's `player_aaaa.url` is never encrypted (`encrypt: 0` on every
/// play page checked live) -- it's already a plain, directly-playable
/// `.m3u8` URL, so no decrypt step is needed. A `Referer` header is sent
/// defensively in case the CDN enforces hotlink protection (not
/// confirmed either way live).
class YinghuaPlaybackSource extends MediaPlaybackSource {
  const YinghuaPlaybackSource({required this.url, this.headers = const {}});

  @override
  final String url;
  @override
  final Map<String, String> headers;
}
