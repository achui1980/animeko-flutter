import '../../domain/media/media_source.dart';

/// A search-result anime series on 嘀哩嘀哩. `slug` is the URL segment
/// used in `/anime/<slug>/` and `/watch/<slug>-ep<N>/` -- it is NOT
/// numeric and is not guessable from the title, only from the search
/// result's own link.
class DilidiliAnime implements MediaCandidate {
  const DilidiliAnime({required this.slug, required this.title});

  final String slug;
  @override
  final String title;

  @override
  String get sourceId => 'dilidili';
}

/// A single episode: one entry in an anime's episode list.
class DilidiliEpisode implements MediaEpisode {
  const DilidiliEpisode({required this.title, required this.watchPageUrl});

  /// Episode label, e.g. `第1176集`.
  @override
  final String title;

  /// Absolute URL of the watch page (`/watch/<slug>-ep<N>/`), passed to
  /// [DilidiliApi.resolvePlaybackUrl].
  final String watchPageUrl;

  @override
  String get sourceId => 'dilidili';
}

/// A resolved, playable video source for one episode. `play_data` from
/// `/_get_play` is already a plain, directly-playable `.m3u8` URL --
/// confirmed live (2026-09-05), no decrypt step needed. A `Referer`
/// header is sent defensively in case the CDN enforces hotlink
/// protection (not confirmed either way live).
class DilidiliPlaybackSource extends MediaPlaybackSource {
  const DilidiliPlaybackSource({required this.url, this.headers = const {}});

  @override
  final String url;
  @override
  final Map<String, String> headers;
}
