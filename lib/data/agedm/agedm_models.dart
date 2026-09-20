import '../../domain/media/media_source.dart';

/// A search hit from agedm.io's mobile JSON API (`/v2/search`). [id] is the
/// site's numeric anime id (e.g. `20000001`), which is what
/// `AgedmApi.listEpisodes` needs.
class AgedmAnime implements MediaCandidate {
  const AgedmAnime({required this.id, required this.title});

  /// Numeric anime id used by `/v2/detail/{id}`.
  final int id;

  @override
  final String title;

  @override
  String get sourceId => 'agedm';
}

/// One playable "line" (CDN mirror) for a single episode.
///
/// agedm.io serves every episode through a third-party parser ("jx"). The
/// detail payload hands out a per-line, per-episode opaque token; appending
/// it to the non-VIP parser prefix (`player_jx.zj`) yields [playPageUrl],
/// an HTML page whose inline `var Vurl = '...'` is the plaintext direct
/// video URL. See `AgedmApi.resolvePlayback`.
class AgedmLine {
  const AgedmLine({
    required this.key,
    required this.label,
    required this.playPageUrl,
  });

  /// Raw line key from the detail payload, e.g. `ffm3u8`/`hnm3u8`.
  final String key;

  /// Human-readable line name from `player_label_arr`, e.g. `非凡`/`红牛`.
  /// Falls back to [key] when the site has no label for it.
  final String label;

  /// Absolute URL of the parser page for this line+episode, already built
  /// as `player_jx.zj + token`.
  final String playPageUrl;
}

/// An episode merged across every non-VIP line that carries it. [lines] is
/// ordered as the detail payload lists the lines, and each entry becomes an
/// independent playback fallback candidate.
class AgedmEpisode implements MediaEpisode {
  const AgedmEpisode({required this.title, required this.lines});

  @override
  final String title;

  /// Every non-VIP line that has this episode. Never empty.
  final List<AgedmLine> lines;

  @override
  String get sourceId => 'agedm';
}

/// A resolved direct video URL (usually an AES-128 HLS `index.m3u8`, which
/// libmpv decrypts natively).
///
/// [headers] is deliberately empty: the parser page declares
/// `<meta name="referrer" content="no-referrer">`, so the browser reaches
/// these CDNs with no `Referer` at all, and sending one was measured
/// (2026-09-19) to either change nothing or break the TLS handshake.
class AgedmPlaybackSource extends MediaPlaybackSource {
  const AgedmPlaybackSource({
    required this.url,
    required this.label,
    this.headers = const {},
  });

  @override
  final String url;

  @override
  final Map<String, String> headers;

  @override
  final String? label;

  /// True: every agedm CDN measured (2026-09-19) is mainland-China-only
  /// and dies behind a typical overseas proxy exit. A/B-tested with
  /// libmpv itself on 尼古喵喵's four lines (非凡/暴风/无尽/计算云):
  /// direct 4/4 play, `--http-proxy=<local proxy>` 4/4 fail with
  /// `Failed to open <url>.` -- the exact error the app surfaced once
  /// every candidate had been exhausted.
  @override
  bool get prefersDirectConnection => true;
}
