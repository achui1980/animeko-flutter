// lib/data/anime1/anime1_models.dart

import '../../domain/media/media_source.dart';

/// A WordPress category page on anime1.me, corresponding to one anime
/// series. `id` is the value of the `cat` query parameter
/// (`https://anime1.me/?cat=<id>`).
class Anime1Category implements MediaCandidate {
  const Anime1Category({required this.id, required this.title});

  final int id;
  @override
  final String title;

  @override
  String get sourceId => 'anime1';
}

/// A single episode: one WordPress article inside an [Anime1Category].
class Anime1Episode implements MediaEpisode {
  const Anime1Episode({required this.title, required this.pageUrl});

  /// Raw article title, e.g. `葬送的芙莉蓮 [12]`. anime1.me embeds the
  /// episode number in free-text form inside the title -- there is no
  /// separate structured episode-number field to parse it out of.
  @override
  final String title;

  /// Absolute URL of the article page. anime1.me has no separate episode
  /// ID concept, so this URL itself is the identifier passed to
  /// [Anime1Api.resolvePlaybackUrl].
  final String pageUrl;

  @override
  String get sourceId => 'anime1';
}

/// A resolved, playable video source for one episode.
class Anime1PlaybackSource implements MediaPlaybackSource {
  const Anime1PlaybackSource({required this.url, this.headers = const {}});

  /// Direct mp4/m3u8 URL.
  @override
  final String url;

  /// HTTP headers that must be sent when actually requesting [url] (e.g.
  /// via media_kit's `Media(url, httpHeaders: ...)`).
  ///
  /// Verified against the live site (2026-09-01): the CDN host serving
  /// [url] rejects the request with `403 Forbidden` unless the exact
  /// `Set-Cookie` values returned by the `POST https://v.anime1.me/api`
  /// call (three short-lived, path-scoped access-token cookies named
  /// `e`/`p`/`h`) are echoed back as a `Cookie` header on the video
  /// request -- the `Referer` header alone is not sufficient. See
  /// `Anime1Api.resolvePlaybackUrl`, which builds this map from that
  /// response's headers.
  @override
  final Map<String, String> headers;

  /// Parses the JSON body returned by `POST https://v.anime1.me/api`.
  ///
  /// NOTE: this shape (`{"s": [{"src": ..., "type": ...}, ...]}`) is an
  /// unverified assumption based on third-party reverse-engineering
  /// writeups, not confirmed against the live API in this repo -- see
  /// `Anime1Api.resolvePlaybackUrl`'s doc comment and the design doc's
  /// "测试策略" section. Adjust this parser if the live response disagrees.
  /// When multiple source entries are present, the *first* one is used;
  /// which entry is "highest quality" is also unconfirmed.
  ///
  /// [headers] are not parsed from [json] -- they come from the HTTP
  /// response's headers (see [Anime1PlaybackSource.headers]) and are
  /// passed through unchanged by the caller.
  factory Anime1PlaybackSource.fromApiResponse(
    Map<String, dynamic> json, {
    Map<String, String> headers = const {},
  }) {
    final sources = json['s'];
    if (sources is! List || sources.isEmpty) {
      throw const FormatException(
        'anime1.me API response contained no playable sources (missing or empty "s")',
      );
    }
    final first = sources.first;
    if (first is! Map || first['src'] is! String) {
      throw const FormatException(
        'anime1.me API response source entry is missing a string "src"',
      );
    }
    var url = first['src'] as String;
    // Verified against the live site (2026-09-01): the API returns a
    // protocol-relative URL (e.g. "//chihaya.v.anime1.me/1468/8b.mp4"),
    // which media_kit/most HTTP clients cannot open directly -- add the
    // scheme back.
    if (url.startsWith('//')) {
      url = 'https:$url';
    }
    return Anime1PlaybackSource(url: url, headers: headers);
  }
}
