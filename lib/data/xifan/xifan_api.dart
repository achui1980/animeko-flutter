import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'xifan_models.dart';
import '../settings/proxy_dio_config.dart';

part 'xifan_api.g.dart';

/// Client for 稀饭动漫, backed by two independent, undocumented APIs (see
/// [XifanBackend]): `next.xifanacg.com`'s Supabase-backed API (PRIMARY,
/// reverse-engineered 2026-09-10) and the legacy `dm1.xfdm.pro`
/// HTML-scraping mirror (FALLBACK, investigated 2026-09-01). There is no
/// official API or documentation for either -- every parsing rule here
/// is a best-effort assumption based on live-site investigation and
/// needs re-verification before this is trusted in production (see
/// design doc's "测试策略" section).
///
/// The backend swap only happens once, at [search]: whichever backend
/// produces a result for a given title "owns" the rest of that title's
/// pipeline -- [listEpisodes] and [resolvePlaybackUrl] both dispatch on
/// [XifanBangumi.backend]/[XifanEpisode.backend] rather than re-trying
/// the other backend mid-pipeline. In practice this means a Supabase
/// search hit stays on Supabase end-to-end (search, episode list,
/// playback all via `next.xifanacg.com`), and only titles that Supabase
/// itself can't find fall through to the legacy dm1.xfdm.pro pipeline.
class XifanApi {
  XifanApi(this._dio, [Dio? supabaseDio]) : _supabaseDio = supabaseDio ?? Dio();
  final Dio _dio;
  final Dio _supabaseDio;

  static const _searchBaseUrl = 'https://dm1.xfdm.pro';
  static const _supabaseSearchUrl =
      'https://rzmsnqblptbceicadbyd.supabase.co/rest/v1/rpc/search_animes';
  static const _nextSiteBaseUrl = 'https://next.xifanacg.com';
  static const _supabasePlaybackUrl =
      'https://rzmsnqblptbceicadbyd.supabase.co/functions/v1/issue-web-playback'
      '?forceFunctionRegion=ap-southeast-1';

  /// Searches 稀饭动漫 for [title]. Tries the Supabase-backed
  /// `search_animes` RPC first (see [_searchViaSupabase]) -- this is the
  /// PRIMARY path as of 2026-09-10, since the legacy dm1.xfdm.pro domain
  /// has been observed fully down (HTTP 522, a Cloudflare
  /// source-server-timeout error) for extended periods. If Supabase
  /// throws (network error, timeout, etc.) or returns nothing, falls
  /// back to dm1.xfdm.pro's HTML search (see [_searchViaHtml]).
  ///
  /// The returned [XifanBangumi.backend] records which path produced
  /// each result; [listEpisodes] and [resolvePlaybackUrl] dispatch on it
  /// to call the matching follow-up API -- see this class's doc comment.
  Future<List<XifanBangumi>> search(String title) async {
    try {
      final results = await _searchViaSupabase(title);
      if (results.isNotEmpty) return results;
    } catch (_) {
      // Fall through to the dm1.xfdm.pro mirror below.
    }

    try {
      return await _searchViaHtml(title);
    } catch (_) {
      return const [];
    }
  }

  /// POSTs to the `search_animes` RPC used by `next.xifanacg.com`
  /// (reverse-engineered 2026-09-10: the site calls
  /// `createClient().rpc('search_animes', {search_term: ...})` against
  /// Supabase project `rzmsnqblptbceicadbyd`). Rows missing a valid
  /// numeric `id` or string `title` are skipped rather than aborting the
  /// whole search.
  Future<List<XifanBangumi>> _searchViaSupabase(String title) async {
    final response = await _supabaseDio.post<List<dynamic>>(
      _supabaseSearchUrl,
      data: {'search_term': title},
    );
    final rows = response.data ?? const [];

    final results = <XifanBangumi>[];
    for (final row in rows) {
      if (row is! Map) continue;
      final id = row['id'];
      final rowTitle = row['title'];
      if (id is! int || rowTitle is! String) continue;
      results.add(
        XifanBangumi(id: id, title: rowTitle, backend: XifanBackend.supabase),
      );
    }
    return results;
  }

  /// GET https://dm1.xfdm.pro/search.html?wd=`<title>`
  ///
  /// **Do not** use `anime.xifanacg.com/search/wd/<title>.html` -- that
  /// path is CAPTCHA-gated (verified live 2026-09-01, via a real browser
  /// render: it shows a "请输入验证码" modal with no underlying search-data
  /// API call at all). `dm1.xfdm.pro` is a confirmed mirror domain that
  /// serves the same numeric bangumi IDs via a different, un-gated
  /// search path.
  ///
  /// NOTE (unverified): assumes each result's title (`.thumb-txt`) and
  /// its detail-page link (`.thumb-menu > a`) appear in matching order
  /// across the whole page, rather than nested inside one shared
  /// container -- no single enclosing element for one result was
  /// confirmed live. If this proves wrong, re-scope both selectors to a
  /// shared parent instead of pairing by index.
  Future<List<XifanBangumi>> _searchViaHtml(String title) async {
    final response = await _dio.get<String>(
      '$_searchBaseUrl/search.html',
      queryParameters: {'wd': title},
      options: Options(responseType: ResponseType.plain),
    );
    final document = html_parser.parse(response.data ?? '');

    final titles = document
        .querySelectorAll('.thumb-txt')
        .map((e) => e.text.trim())
        .toList();
    final links = document
        .querySelectorAll('.thumb-menu > a')
        .map((e) => e.attributes['href'])
        .toList();

    final idPattern = RegExp(r'/bangumi/(\d+)\.html');
    final seenIds = <int>{};
    final results = <XifanBangumi>[];
    for (var i = 0; i < titles.length && i < links.length; i++) {
      final href = links[i];
      if (href == null) continue;
      final match = idPattern.firstMatch(href);
      if (match == null) continue;
      final id = int.parse(match.group(1)!);
      if (!seenIds.add(id)) continue;
      if (titles[i].isEmpty) continue;
      results.add(
        XifanBangumi(
          id: id,
          title: titles[i],
          backend: XifanBackend.htmlMirror,
        ),
      );
    }
    return results;
  }

  static const _watchBaseUrl = 'https://dm1.xfdm.pro';

  /// Lists episodes for [bangumi], dispatching on
  /// [XifanBangumi.backend] to call the matching backend's API -- see
  /// this class's doc comment.
  Future<List<XifanEpisode>> listEpisodes(XifanBangumi bangumi) {
    switch (bangumi.backend) {
      case XifanBackend.supabase:
        return _listEpisodesViaSupabase(bangumi.id);
      case XifanBackend.htmlMirror:
        return _listEpisodesViaHtml(bangumi.id);
    }
  }

  /// GET https://next.xifanacg.com/anime/`<animeId>` with request header
  /// `RSC: 1` (reverse-engineered 2026-09-10). The Next.js App Router
  /// server responds with a React Server Components stream
  /// (`Content-Type: text/x-component`) that has the full episode list
  /// embedded as plain JSON objects -- there is no separate REST
  /// endpoint for this. Each episode object looks like:
  /// `{"id":123603,"kind":"main","title":"第02集",...,"episode_number":2,...}`.
  /// Because the RSC stream re-serializes shared references, the same
  /// episode object can legitimately appear more than once verbatim, so
  /// results are de-duplicated by `id` and then sorted by
  /// `episode_number` (stream order is not guaranteed to be ascending).
  Future<List<XifanEpisode>> _listEpisodesViaSupabase(int animeId) async {
    final response = await _supabaseDio.get<String>(
      '$_nextSiteBaseUrl/anime/$animeId',
      options: Options(responseType: ResponseType.plain, headers: {'RSC': '1'}),
    );
    final body = response.data ?? '';

    final pattern = RegExp(
      r'"id":(\d+),"kind":"main","title":"([^"]*)"[^}]*?"episode_number":(\d+)',
    );
    final seenIds = <int>{};
    final raw = <_RawEpisode>[];
    for (final match in pattern.allMatches(body)) {
      final id = int.parse(match.group(1)!);
      if (!seenIds.add(id)) continue;
      raw.add(
        _RawEpisode(
          id: id,
          title: match.group(2)!,
          episodeNumber: int.parse(match.group(3)!),
        ),
      );
    }
    raw.sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber));

    return [
      for (final episode in raw)
        XifanEpisode(
          title: episode.title,
          backend: XifanBackend.supabase,
          supabaseEpisodeId: episode.id,
        ),
    ];
  }

  /// GET https://dm1.xfdm.pro/bangumi/`<bangumiId>`.html
  ///
  /// Lists episodes merged across ALL "线路" (line) lists on the bangumi
  /// page. Each line is its own `<ul class="anthology-list-play">`
  /// sibling under `.anthology-list-box`; the same logical episode
  /// appears in multiple lists under a different URL (the line is
  /// encoded in the URL's middle path segment). Episodes are merged
  /// across lists by EXACT title match, in the order lists appear on the
  /// page -- so [XifanEpisode.watchPageUrls] is ordered with the
  /// first-encountered line first (the default/primary line).
  Future<List<XifanEpisode>> _listEpisodesViaHtml(int bangumiId) async {
    final response = await _dio.get<String>(
      '$_watchBaseUrl/bangumi/$bangumiId.html',
      options: Options(responseType: ResponseType.plain),
    );
    final document = html_parser.parse(response.data ?? '');

    final lists = document.querySelectorAll('.anthology-list-play');

    final urlsByTitle = <String, List<String>>{};
    final titleOrder = <String>[];
    for (final list in lists) {
      for (final link in list.querySelectorAll('a')) {
        final href = link.attributes['href'];
        final title = link.text.trim();
        if (href == null || title.isEmpty) continue;
        final url = href.startsWith('http') ? href : '$_watchBaseUrl$href';
        final urls = urlsByTitle.putIfAbsent(title, () {
          titleOrder.add(title);
          return <String>[];
        });
        urls.add(url);
      }
    }

    return titleOrder
        .map(
          (title) => XifanEpisode(
            title: title,
            backend: XifanBackend.htmlMirror,
            watchPageUrls: urlsByTitle[title]!,
          ),
        )
        .toList();
  }

  /// Resolves ALL playable candidates for [episode], dispatching on
  /// [XifanEpisode.backend] to call the matching backend's API -- see
  /// this class's doc comment.
  Future<List<XifanPlaybackSource>> resolvePlaybackUrl(XifanEpisode episode) {
    switch (episode.backend) {
      case XifanBackend.supabase:
        return _resolvePlaybackViaSupabase(episode.supabaseEpisodeId!);
      case XifanBackend.htmlMirror:
        return _resolvePlaybackViaHtml(episode.watchPageUrls);
    }
  }

  /// POSTs to the `issue-web-playback` Supabase edge function used by
  /// `next.xifanacg.com` (reverse-engineered 2026-09-10). Confirmed live
  /// to require NO auth header at all -- unlike [_searchViaSupabase],
  /// which needs `apikey`. Body is `{"action": "fallback", "episode_id":
  /// episodeId}`; the response's top-level `url` field duplicates its
  /// first `candidates[].url`, so all `candidates[].url` entries are
  /// collected as fallback lines (mirroring the "线路" concept from the
  /// legacy HTML mirror) rather than using the top-level `url`
  /// separately.
  Future<List<XifanPlaybackSource>> _resolvePlaybackViaSupabase(
    int episodeId,
  ) async {
    final response = await _supabaseDio.post<Map<String, dynamic>>(
      _supabasePlaybackUrl,
      data: {'action': 'fallback', 'episode_id': episodeId},
    );
    final candidates = response.data?['candidates'];

    final sources = <XifanPlaybackSource>[];
    if (candidates is List) {
      for (final candidate in candidates) {
        if (candidate is! Map) continue;
        final url = candidate['url'];
        if (url is String && url.isNotEmpty) {
          sources.add(XifanPlaybackSource(url: url));
        }
      }
    }

    if (sources.isEmpty) {
      throw const FormatException(
        '稀饭动漫: issue-web-playback returned no playable candidates',
      );
    }
    return sources;
  }

  /// Resolves ALL playable line candidates for a logical episode, in the
  /// order given by [watchPageUrls] (see [XifanEpisode]). Each URL is
  /// requested, decrypted per its own `encrypt` field, and parsed
  /// independently; a URL that fails is skipped rather than aborting the
  /// whole call -- an exception is only thrown if EVERY URL fails.
  Future<List<XifanPlaybackSource>> _resolvePlaybackViaHtml(
    List<String> watchPageUrls,
  ) async {
    final sources = <XifanPlaybackSource>[];
    for (final watchPageUrl in watchPageUrls) {
      try {
        final response = await _dio.get<String>(
          watchPageUrl,
          options: Options(responseType: ResponseType.plain),
        );
        final body = response.data ?? '';

        final json = _extractPlayerJson(body);
        if (json == null) continue;

        final playerData = jsonDecode(json) as Map<String, dynamic>;
        final rawUrl = playerData['url'] as String?;
        if (rawUrl == null || rawUrl.isEmpty) continue;

        final encrypt = playerData['encrypt']?.toString() ?? '0';
        sources.add(XifanPlaybackSource(url: _decryptUrl(rawUrl, encrypt)));
      } catch (_) {
        continue;
      }
    }

    if (sources.isEmpty) {
      throw const FormatException(
        '稀饭动漫: none of the candidate lines resolved to a playable url',
      );
    }
    return sources;
  }
}

/// One parsed episode row from a `next.xifanacg.com` RSC payload, before
/// sorting/de-duplication. See [XifanApi._listEpisodesViaSupabase].
class _RawEpisode {
  const _RawEpisode({
    required this.id,
    required this.title,
    required this.episodeNumber,
  });

  final int id;
  final String title;
  final int episodeNumber;
}

const _xifanConnectTimeout = Duration(seconds: 15);
const _xifanReceiveTimeout = Duration(seconds: 15);

@riverpod
Dio xifanDio(Ref ref) {
  final dio = Dio(
    BaseOptions(
      headers: {'User-Agent': 'Mozilla/5.0'},
      connectTimeout: _xifanConnectTimeout,
      receiveTimeout: _xifanReceiveTimeout,
    ),
  );
  configureProxy(dio, ref);
  return dio;
}

const _xifanSupabaseConnectTimeout = Duration(seconds: 10);
const _xifanSupabaseReceiveTimeout = Duration(seconds: 10);

/// This is Supabase's "publishable" key (the modern replacement for the
/// old JWT-format "anon" key) for the `rzmsnqblptbceicadbyd` project
/// backing `next.xifanacg.com`. By Supabase's design this key is meant
/// to be embedded client-side -- access control is enforced server-side
/// via row-level security, not by keeping this value secret.
const _xifanSupabaseApiKey = 'sb_publishable_aCb7uwyLN6H-sMjze4dRGA_2MDuROLF';

/// Dio for 稀饭动漫's Supabase-backed API (`next.xifanacg.com`) --
/// PRIMARY backend for [XifanApi.search]/[XifanApi.listEpisodes]/
/// [XifanApi.resolvePlaybackUrl] as of 2026-09-10 (see [XifanBackend]).
@riverpod
Dio xifanSupabaseDio(Ref ref) {
  final dio = Dio(
    BaseOptions(
      headers: {
        'apikey': _xifanSupabaseApiKey,
        'Content-Type': 'application/json',
      },
      connectTimeout: _xifanSupabaseConnectTimeout,
      receiveTimeout: _xifanSupabaseReceiveTimeout,
    ),
  );
  configureProxy(dio, ref);
  return dio;
}

@riverpod
XifanApi xifanApi(Ref ref) =>
    XifanApi(ref.watch(xifanDioProvider), ref.watch(xifanSupabaseDioProvider));

/// Scans forward from `var player_aaaa` for its `{...}` object literal,
/// tracking brace depth so a nested object (e.g. `vod_data`) doesn't
/// cause extraction to stop early. Returns `null` if the marker isn't
/// found or its braces never balance.
String? _extractPlayerJson(String html) {
  const marker = 'var player_aaaa';
  final markerIndex = html.indexOf(marker);
  if (markerIndex == -1) return null;

  final braceStart = html.indexOf('{', markerIndex);
  if (braceStart == -1) return null;

  var depth = 0;
  for (var i = braceStart; i < html.length; i++) {
    final char = html[i];
    if (char == '{') depth++;
    if (char == '}') {
      depth--;
      if (depth == 0) return html.substring(braceStart, i + 1);
    }
  }
  return null;
}

/// Mirrors the real `MacPlayer.Init()` decrypt rule read from the live
/// `player.js` source (2026-09-01): `'1'` -> percent-decode (JS
/// `unescape()`); `'2'` -> base64-decode then percent-decode; anything
/// else (including `'0'`/missing) -> use [url] as-is.
String _decryptUrl(String url, String encrypt) {
  switch (encrypt) {
    case '1':
      return Uri.decodeComponent(url);
    case '2':
      return Uri.decodeComponent(latin1.decode(base64Decode(url)));
    default:
      return url;
  }
}
