// lib/data/anime1/anime1_models.dart

/// A WordPress category page on anime1.me, corresponding to one anime
/// series. `id` is the value of the `cat` query parameter
/// (`https://anime1.me/?cat=<id>`).
class Anime1Category {
  const Anime1Category({required this.id, required this.title});

  final int id;
  final String title;
}

/// A single episode: one WordPress article inside an [Anime1Category].
class Anime1Episode {
  const Anime1Episode({required this.title, required this.pageUrl});

  /// Raw article title, e.g. `葬送的芙莉蓮 [12]`. anime1.me embeds the
  /// episode number in free-text form inside the title -- there is no
  /// separate structured episode-number field to parse it out of.
  final String title;

  /// Absolute URL of the article page. anime1.me has no separate episode
  /// ID concept, so this URL itself is the identifier passed to
  /// [Anime1Api.resolvePlaybackUrl].
  final String pageUrl;
}

/// A resolved, playable video source for one episode.
class Anime1PlaybackSource {
  const Anime1PlaybackSource({required this.url});

  /// Direct mp4/m3u8 URL.
  final String url;

  /// Parses the JSON body returned by `POST https://v.anime1.me/api`.
  ///
  /// NOTE: this shape (`{"s": [{"src": ..., "type": ...}, ...]}`) is an
  /// unverified assumption based on third-party reverse-engineering
  /// writeups, not confirmed against the live API in this repo -- see
  /// `Anime1Api.resolvePlaybackUrl`'s doc comment and the design doc's
  /// "测试策略" section. Adjust this parser if the live response disagrees.
  /// When multiple source entries are present, the *first* one is used;
  /// which entry is "highest quality" is also unconfirmed.
  factory Anime1PlaybackSource.fromApiResponse(Map<String, dynamic> json) {
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
    return Anime1PlaybackSource(url: first['src'] as String);
  }
}
