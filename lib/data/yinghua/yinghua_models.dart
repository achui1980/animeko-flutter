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

/// A single episode: one entry in a bangumi's episode list (only the
/// *first* line/route -- see [YinghuaApi.listEpisodes]'s doc comment).
class YinghuaEpisode implements MediaEpisode {
  const YinghuaEpisode({required this.title, required this.playPageUrl});

  /// Episode label, e.g. `第01集`.
  @override
  final String title;

  /// Absolute URL of the play page
  /// (`/index.php/vod/play/id/<id>/sid/<line>/nid/<episode>.html`),
  /// passed to [YinghuaApi.resolvePlaybackUrl].
  final String playPageUrl;

  @override
  String get sourceId => 'yinghua';
}

/// A resolved, playable video source for one episode. Unlike 稀饭动漫,
/// 樱花动漫's `player_aaaa.url` is never encrypted (`encrypt: 0` on every
/// play page checked live) -- it's already a plain, directly-playable
/// `.m3u8` URL, so no decrypt step is needed. A `Referer` header is sent
/// defensively in case the CDN enforces hotlink protection (not
/// confirmed either way live).
class YinghuaPlaybackSource implements MediaPlaybackSource {
  const YinghuaPlaybackSource({required this.url, this.headers = const {}});

  @override
  final String url;
  @override
  final Map<String, String> headers;
}
