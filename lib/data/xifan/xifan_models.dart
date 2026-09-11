import '../../domain/media/media_source.dart';

/// Which backend a [XifanBangumi] or [XifanEpisode] came from. The two
/// backends have unrelated ID spaces and different follow-up APIs, so
/// call sites must dispatch on this rather than assuming one shape.
enum XifanBackend {
  /// `next.xifanacg.com`'s Supabase-backed API (reverse-engineered
  /// 2026-09-10): the `search_animes` RPC, RSC-embedded episode data on
  /// the anime detail page, and the `issue-web-playback` edge function.
  /// PRIMARY backend as of 2026-09-10, since the legacy [htmlMirror]
  /// domain has been observed fully down (HTTP 522, Cloudflare
  /// source-server timeout) for extended periods.
  supabase,

  /// The legacy `dm1.xfdm.pro` HTML-scraping mirror (investigated
  /// 2026-09-01). FALLBACK backend, used only when [supabase] search
  /// itself fails or returns nothing for a given title.
  htmlMirror,
}

/// A search-result "bangumi" (anime series) page on 稀饭动漫.
///
/// [id] means different things depending on [backend]: the Supabase
/// `anime_id` when [backend] is [XifanBackend.supabase], or the numeric
/// ID used in dm1.xfdm.pro's `/bangumi/<id>.html` when [backend] is
/// [XifanBackend.htmlMirror]. The two ID spaces are unrelated -- always
/// check [backend] before interpreting [id].
class XifanBangumi implements MediaCandidate {
  const XifanBangumi({
    required this.id,
    required this.title,
    required this.backend,
  });

  final int id;
  @override
  final String title;

  /// Which backend produced this candidate -- determines [id]'s
  /// meaning and which API [XifanApi.listEpisodes] calls next.
  final XifanBackend backend;

  @override
  String get sourceId => 'xifan';
}

/// One logical episode.
///
/// When [backend] is [XifanBackend.supabase], [supabaseEpisodeId] is the
/// Supabase episode id used to call `issue-web-playback`, and
/// [watchPageUrls] is empty. When [backend] is [XifanBackend.htmlMirror],
/// [watchPageUrls] holds the dm1.xfdm.pro watch-page URLs -- merged
/// across all "线路" (line) lists that expose this episode under the
/// same title, ordered by line appearance on the bangumi page (index 0
/// is the default/primary line) -- and [supabaseEpisodeId] is null.
class XifanEpisode implements MediaEpisode {
  const XifanEpisode({
    required this.title,
    required this.backend,
    this.watchPageUrls = const [],
    this.supabaseEpisodeId,
  });

  /// Episode label, e.g. `第01集`.
  @override
  final String title;

  /// Which backend produced this episode -- determines which fields
  /// above are populated and which API [XifanApi.resolvePlaybackUrl]
  /// calls next.
  final XifanBackend backend;

  /// Populated only when [backend] is [XifanBackend.htmlMirror]. Passed
  /// to [XifanApi.resolvePlaybackUrl].
  final List<String> watchPageUrls;

  /// Populated only when [backend] is [XifanBackend.supabase]. Passed
  /// to [XifanApi.resolvePlaybackUrl].
  final int? supabaseEpisodeId;

  @override
  String get sourceId => 'xifan';
}

/// A resolved, playable video source for one episode. 稀饭动漫's video CDNs
/// -- both the legacy `apn.moedot.net` -> `hydownload.pan.wo.cn` path and
/// the additional CDN lines surfaced by the Supabase `issue-web-playback`
/// function (e.g. `play.xfvod.pro`, `dl.playxf.top`) -- are fully
/// unauthenticated and need zero headers. Verified live: 2026-09-01 for
/// the legacy path (a plain, header-less range request returned `206
/// Partial Content` with real MP4 bytes); 2026-09-10 for the
/// Supabase-issued candidates (a plain, header-less request followed
/// redirects to a real ~512MB video file with a matching
/// `Content-Length`).
class XifanPlaybackSource extends MediaPlaybackSource {
  const XifanPlaybackSource({required this.url, this.headers = const {}});

  @override
  final String url;
  @override
  final Map<String, String> headers;
}
