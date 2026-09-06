import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'xifan_models.dart';
import '../settings/proxy_dio_config.dart';

part 'xifan_api.g.dart';

/// Direct HTML-scraping client for 稀饭动漫. There is no official API or
/// documentation -- every parsing rule here is a best-effort assumption
/// based on live-site investigation (2026-09-01) and needs re-verification
/// before this is trusted in production (see design doc's "测试策略"
/// section).
class XifanApi {
  XifanApi(this._dio);
  final Dio _dio;

  static const _searchBaseUrl = 'https://dm1.xfdm.pro';

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
  Future<List<XifanBangumi>> search(String title) async {
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
      results.add(XifanBangumi(id: id, title: titles[i]));
    }
    return results;
  }

  static const _watchBaseUrl = 'https://dm1.xfdm.pro';

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
  Future<List<XifanEpisode>> listEpisodes(int bangumiId) async {
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
          (title) =>
              XifanEpisode(title: title, watchPageUrls: urlsByTitle[title]!),
        )
        .toList();
  }

  /// Resolves ALL playable line candidates for a logical episode, in the
  /// order given by [watchPageUrls] (see [XifanEpisode]). Each URL is
  /// requested, decrypted per its own `encrypt` field, and parsed
  /// independently; a URL that fails is skipped rather than aborting the
  /// whole call -- an exception is only thrown if EVERY URL fails.
  Future<List<XifanPlaybackSource>> resolvePlaybackUrl(
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

@riverpod
Dio xifanDio(Ref ref) {
  final dio = Dio(BaseOptions(headers: {'User-Agent': 'Mozilla/5.0'}));
  configureProxy(dio, ref);
  return dio;
}

@riverpod
XifanApi xifanApi(Ref ref) => XifanApi(ref.watch(xifanDioProvider));

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
