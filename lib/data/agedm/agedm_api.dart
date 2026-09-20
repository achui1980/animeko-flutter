import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'agedm_models.dart';

part 'agedm_api.g.dart';

/// Client for agedm.io (AGE动漫).
///
/// agedm.io has no documented API. This client targets the **mobile web
/// app's** JSON API (`https://api.agedm.io/v2/`, discovered by reading
/// `m.agedm.io`'s webpack bundle on 2026-09-19) rather than the desktop
/// HTML site, for two reasons:
///
///  * The desktop player embeds a third-party parser at
///    `jx.wuzhoupai.com:8443/vip/`, whose request signing lives in a
///    307 KB Go-compiled WASM module. The mobile API instead hands out
///    ready-made tokens for the parser's **non-VIP** `/m3u8/` path, which
///    returns the direct video URL in plaintext -- no cipher involved.
///  * Popular titles' desktop pages refuse to render a player at all
///    ("暂不提供PC端播放，请下载APP"), while the API still returns every
///    non-VIP line for them.
///
/// Every rule below was established by live investigation on the date
/// noted and may silently break if the site changes.
class AgedmApi {
  AgedmApi(this._dio);

  final Dio _dio;

  static const _apiBaseUrl = 'https://api.agedm.io/v2';

  /// The `query` parameter's hard limit, in characters (not bytes) --
  /// anything longer answers `40050 参数错误！` (measured 2026-09-19:
  /// `Fate/Zer` succeeds, `Fate/Zero` does not; CJK counts as one
  /// character each).
  static const _maxQueryLength = 8;

  /// Episode titles are `第<n>集`, but the zero-padding width differs per
  /// line (`第1集`/`第01集`/`第001集`/`第0001集` all observed on one anime),
  /// so lines can only be merged on the parsed number.
  static final _episodeNumber = RegExp(r'^第(\d+)集$');

  /// The parser page's plaintext direct URL, e.g.
  /// `var Vurl = 'https://hn.bfvvs.com/play/penZrB7e/index.m3u8';`.
  static final _vurl = RegExp(r"""var\s+Vurl\s*=\s*'([^']*)'""");

  /// GET `https://api.agedm.io/v2/search?query=<q>&page=1`
  ///
  /// Reads `data.videos[].id` and `data.videos[].name`. Only page 1 is
  /// fetched (page size 24), matching every other source in this repo:
  /// [_sanitizeQuery] keeps queries short enough that real matches land on
  /// the first page, and `matchBest` filters from there.
  ///
  /// Returns an empty list -- not an error -- on `code: 40050`, because the
  /// API overloads that code for both "malformed query" and "no results"
  /// (measured 2026-09-19: `zzqqxx` and `鬼滅之刃` both answer 40050).
  Future<List<AgedmAnime>> search(String title) async {
    final query = _sanitizeQuery(title);
    if (query.isEmpty) return const [];

    final response = await _dio.get<String>(
      '$_apiBaseUrl/search',
      queryParameters: {'query': query, 'page': '1'},
      options: Options(responseType: ResponseType.plain),
    );
    final payload = _decodeJson(response.data);

    if (payload['code'] == 40050) return const [];

    final data = payload['data'];
    if (data is! Map) {
      throw const FormatException('agedm search response has no data object');
    }
    final videos = data['videos'];
    if (videos is! List) return const [];

    final results = <AgedmAnime>[];
    for (final video in videos) {
      if (video is! Map) continue;
      final id = video['id'];
      final name = video['name'];
      if (id is! int || name is! String || name.isEmpty) continue;
      results.add(AgedmAnime(id: id, title: name));
    }
    return results;
  }

  /// GET `https://api.agedm.io/v2/detail/{animeId}`
  ///
  /// Unlike `/v2/search`, this endpoint returns its payload at the **top
  /// level** with no `{code, message, data}` envelope. Reads:
  ///
  ///  * `video.playlists` -- a line key to a list of
  ///    `[episodeTitle, token]` pairs.
  ///  * `player_vip` -- comma-separated line keys that need the WASM-signed
  ///    `/vip/` parser. Those are dropped; this client only handles the
  ///    non-VIP lines.
  ///  * `player_jx.zj` -- URL prefix for the non-VIP parser.
  ///  * `player_label_arr` -- line key to Chinese display label.
  ///
  /// Lines disagree on both episode count and zero-padding, so the result
  /// is the union of all non-VIP lines: numbered episodes in ascending
  /// numeric order first, then any non-numbered entry (e.g. `特别篇`) in
  /// the order first encountered. Each episode's display title comes from
  /// whichever line has the most episodes, so the padding stays consistent
  /// down the list.
  Future<List<AgedmEpisode>> listEpisodes(int animeId) async {
    final response = await _dio.get<String>(
      '$_apiBaseUrl/detail/$animeId',
      options: Options(responseType: ResponseType.plain),
    );
    final payload = _decodeJson(response.data);

    final video = payload['video'];
    final playlists = video is Map ? video['playlists'] : null;
    if (playlists is! Map || playlists.isEmpty) {
      throw FormatException('agedm detail $animeId has no playlists');
    }

    final jx = payload['player_jx'];
    final parserPrefix = jx is Map ? jx['zj'] : null;
    if (parserPrefix is! String || parserPrefix.isEmpty) {
      throw FormatException('agedm detail $animeId has no player_jx.zj');
    }

    final vipKeys = (payload['player_vip'] as String? ?? '')
        .split(',')
        .map((key) => key.trim())
        .where((key) => key.isNotEmpty)
        .toSet();
    final labels = payload['player_label_arr'];

    // Ordered longest-line-first so the winning display title comes from
    // the most complete line, while `lines` below stays in payload order.
    final lineKeys = playlists.keys
        .whereType<String>()
        .where((key) => !vipKeys.contains(key))
        .where((key) => playlists[key] is List)
        .toList();
    if (lineKeys.isEmpty) {
      throw FormatException('agedm detail $animeId exposes only VIP playlists');
    }
    final titleSourceKeys = [...lineKeys]
      ..sort(
        (a, b) => (playlists[b] as List).length.compareTo(
          (playlists[a] as List).length,
        ),
      );

    final episodes = <String, _MergedEpisode>{};
    for (final key in lineKeys) {
      final label = labels is Map && labels[key] is String
          ? labels[key] as String
          : key;
      for (final entry in playlists[key] as List) {
        if (entry is! List || entry.length < 2) continue;
        final title = entry[0];
        final token = entry[1];
        if (title is! String || token is! String) continue;
        final trimmed = title.trim();
        if (trimmed.isEmpty || token.isEmpty) continue;

        final number = int.tryParse(
          _episodeNumber.firstMatch(trimmed)?.group(1) ?? '',
        );
        // Numbered episodes merge on the number; anything else can only
        // merge on its exact title.
        final merged = episodes.putIfAbsent(
          number == null ? 'raw:$trimmed' : 'num:$number',
          () => _MergedEpisode(number: number, order: episodes.length),
        );
        merged.titles[key] = trimmed;
        // Tokens arrive already percent-encoded (they contain literal
        // `%2F`/`%2B`), and the site itself just concatenates. Handing the
        // token to Dio's `queryParameters` would re-encode `%` as `%25`.
        merged.lines.add(
          AgedmLine(key: key, label: label, playPageUrl: '$parserPrefix$token'),
        );
      }
    }

    final merged = episodes.values.toList()..sort(_byEpisodeOrder);
    return [
      for (final episode in merged)
        AgedmEpisode(
          title: episode.displayTitle(titleSourceKeys),
          lines: List.unmodifiable(episode.lines),
        ),
    ];
  }

  /// Resolves every line of [episode] into a playback candidate.
  ///
  /// Each line's parser page is fetched (concurrently, result order
  /// preserved) and its `var Vurl = '...'` extracted -- that is the direct
  /// `.m3u8`/`.mp4` URL, handed to libmpv unchanged.
  ///
  /// Lines are skipped individually on failure rather than aborting,
  /// because reachability varies by network and geography (measured
  /// 2026-09-19: of 海贼王's seven lines, one served HLS, two answered 403,
  /// one 404 and one failed its TLS handshake). All of them failing throws.
  Future<List<AgedmPlaybackSource>> resolvePlayback(
    AgedmEpisode episode,
  ) async {
    if (episode.lines.isEmpty) {
      throw FormatException('agedm episode ${episode.title} has no lines');
    }

    final resolved = await Future.wait(episode.lines.map(_resolveLine));
    final sources = resolved.whereType<AgedmPlaybackSource>().toList();
    if (sources.isEmpty) {
      throw FormatException(
        'agedm resolved no playable line for ${episode.title}',
      );
    }
    return sources;
  }

  Future<AgedmPlaybackSource?> _resolveLine(AgedmLine line) async {
    try {
      final response = await _dio.get<String>(
        line.playPageUrl,
        options: Options(responseType: ResponseType.plain),
      );
      final url = _vurl.firstMatch(response.data ?? '')?.group(1);
      if (url == null || url.isEmpty) return null;
      return AgedmPlaybackSource(url: url, label: line.label);
    } catch (_) {
      return null;
    }
  }

  /// Makes [title] acceptable to `/v2/search`, which rejects any query
  /// containing whitespace and any query over [_maxQueryLength] characters
  /// (both measured 2026-09-19; `Candy ` fails even though the matching
  /// title really is `Candy Caries 蛀在糖糖里`).
  ///
  /// Strategy: take the longest whitespace-separated token -- the most
  /// distinctive part of a title, and the one least likely to be a season
  /// marker -- then truncate it. The API matches against `name`,
  /// `name_original` and `name_other`, so a fragment is enough.
  static String _sanitizeQuery(String title) {
    final tokens = title.trim().split(RegExp(r'\s+'))
      ..removeWhere((token) => token.isEmpty);
    if (tokens.isEmpty) return '';
    var longest = tokens.first;
    for (final token in tokens) {
      if (token.runes.length > longest.runes.length) longest = token;
    }
    final runes = longest.runes.toList();
    if (runes.length <= _maxQueryLength) return longest;
    return String.fromCharCodes(runes.take(_maxQueryLength));
  }

  static Map<String, dynamic> _decodeJson(String? body) {
    if (body == null || body.isEmpty) {
      throw const FormatException('agedm returned an empty response');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw const FormatException('agedm returned a non-JSON response');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('agedm returned an unexpected JSON shape');
    }
    return decoded;
  }

  static int _byEpisodeOrder(_MergedEpisode a, _MergedEpisode b) {
    // Numbered episodes ascending, then unnumbered ones in encounter order.
    if (a.number != null && b.number != null) {
      return a.number!.compareTo(b.number!);
    }
    if (a.number != null) return -1;
    if (b.number != null) return 1;
    return a.order.compareTo(b.order);
  }
}

/// Accumulator for one episode as it is merged across lines.
class _MergedEpisode {
  _MergedEpisode({required this.number, required this.order});

  /// Parsed `第<n>集` number, or null for entries like `特别篇`.
  final int? number;

  /// First-encounter index, used to order unnumbered entries.
  final int order;

  /// Per-line spelling of this episode's title (padding differs by line).
  final Map<String, String> titles = {};

  final List<AgedmLine> lines = [];

  /// The title as spelled by the first of [preferredKeys] that has this
  /// episode, so one anime's list does not mix `第1集` with `第001集`.
  String displayTitle(List<String> preferredKeys) {
    for (final key in preferredKeys) {
      final title = titles[key];
      if (title != null) return title;
    }
    return titles.values.first;
  }
}

const _agedmConnectTimeout = Duration(seconds: 15);
const _agedmReceiveTimeout = Duration(seconds: 15);

@riverpod
Dio agedmDio(Ref ref) {
  final dio = Dio(
    BaseOptions(
      headers: {'User-Agent': 'Mozilla/5.0'},
      connectTimeout: _agedmConnectTimeout,
      receiveTimeout: _agedmReceiveTimeout,
    ),
  );
  return dio;
}

@riverpod
AgedmApi agedmApi(Ref ref) => AgedmApi(ref.watch(agedmDioProvider));
