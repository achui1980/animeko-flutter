import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'yinghua_models.dart';

part 'yinghua_api.g.dart';

/// Direct HTML-scraping client for 樱花动漫. There is no official API or
/// documentation -- every parsing rule here is a best-effort assumption
/// based on live-site investigation (2026-09-05) and needs
/// re-verification before this is trusted in production (same caveat as
/// `XifanApi`).
class YinghuaApi {
  YinghuaApi(this._dio);
  final Dio _dio;

  static const _baseUrl = 'https://www.yinghua2.com';

  /// GET https://www.yinghua2.com/index.php/vod/search.html?wd=`<title>`
  ///
  /// Each result is one `<li>` under `ul.stui-vodlist__media`; its title
  /// and detail-page link both live at `.detail h3.title > a` (confirmed
  /// live 2026-09-05).
  Future<List<YinghuaBangumi>> search(String title) async {
    final response = await _dio.get<String>(
      '$_baseUrl/index.php/vod/search.html',
      queryParameters: {'wd': title},
      options: Options(responseType: ResponseType.plain),
    );
    final document = html_parser.parse(response.data ?? '');

    final idPattern = RegExp(r'/index\.php/vod/detail/id/(\d+)\.html');
    final seenIds = <int>{};
    final results = <YinghuaBangumi>[];
    for (final li in document.querySelectorAll('ul.stui-vodlist__media > li')) {
      final link = li.querySelector('.detail h3.title a');
      if (link == null) continue;
      final href = link.attributes['href'];
      final title = link.text.trim();
      if (href == null || title.isEmpty) continue;
      final match = idPattern.firstMatch(href);
      if (match == null) continue;
      final id = int.parse(match.group(1)!);
      if (!seenIds.add(id)) continue;
      results.add(YinghuaBangumi(id: id, title: title));
    }
    return results;
  }

  /// GET https://www.yinghua2.com/index.php/vod/detail/id/`<id>`.html
  ///
  /// Lists episodes merged across ALL "线路" (line) blocks on the detail
  /// page. Each line block is a `div.stui-pannel.stui-pannel-bg` with its
  /// own full `<ul class="stui-content__playlist">`; the same logical
  /// episode appears in multiple blocks under a different URL (the line
  /// is encoded in the URL's `sid` path segment). Episodes are merged
  /// across blocks by EXACT title match, in the order blocks appear on
  /// the page -- so [YinghuaEpisode.playPageUrls] is ordered with the
  /// first-encountered line first (the default/primary line).
  Future<List<YinghuaEpisode>> listEpisodes(int id) async {
    final response = await _dio.get<String>(
      '$_baseUrl/index.php/vod/detail/id/$id.html',
      options: Options(responseType: ResponseType.plain),
    );
    final document = html_parser.parse(response.data ?? '');

    final lineBlocks = document.querySelectorAll(
      'div.stui-pannel.stui-pannel-bg',
    );

    // Title -> ordered list of URLs (first-seen line first).
    final urlsByTitle = <String, List<String>>{};
    final titleOrder = <String>[];
    for (final block in lineBlocks) {
      for (final link in block.querySelectorAll(
        '.stui-content__playlist > li > a',
      )) {
        final href = link.attributes['href'];
        final title = link.text.trim();
        if (href == null || title.isEmpty) continue;
        final url = href.startsWith('http') ? href : '$_baseUrl$href';
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
              YinghuaEpisode(title: title, playPageUrls: urlsByTitle[title]!),
        )
        .toList();
  }

  /// GET the play page, extract the inline `var player_aaaa = {...};`
  /// object, and use its `url` field as-is (see `YinghuaPlaybackSource`'s
  /// doc comment -- no decryption is needed on this site).
  ///
  /// Resolves ALL playable line candidates for a logical episode, in the
  /// order given by [playPageUrls] (see [YinghuaEpisode]). Each URL is
  /// requested and parsed independently; a URL that fails (network
  /// error, missing `player_aaaa`, missing `url` field) is skipped
  /// rather than aborting the whole call -- an exception is only thrown
  /// if EVERY URL fails.
  Future<List<YinghuaPlaybackSource>> resolvePlaybackUrl(
    List<String> playPageUrls,
  ) async {
    final sources = <YinghuaPlaybackSource>[];
    for (final playPageUrl in playPageUrls) {
      try {
        final response = await _dio.get<String>(
          playPageUrl,
          options: Options(responseType: ResponseType.plain),
        );
        final body = response.data ?? '';

        final json = _extractPlayerJson(body);
        if (json == null) continue;

        final playerData = jsonDecode(json) as Map<String, dynamic>;
        final url = playerData['url'] as String?;
        if (url == null || url.isEmpty) continue;

        sources.add(
          YinghuaPlaybackSource(
            url: url,
            headers: const {'Referer': 'https://www.yinghua2.com/'},
          ),
        );
      } catch (_) {
        continue;
      }
    }

    if (sources.isEmpty) {
      throw const FormatException(
        '樱花动漫: none of the candidate lines resolved to a playable url',
      );
    }
    return sources;
  }
}

const _yinghuaConnectTimeout = Duration(seconds: 15);
const _yinghuaReceiveTimeout = Duration(seconds: 15);

@riverpod
Dio yinghuaDio(Ref ref) {
  final dio = Dio(
    BaseOptions(
      headers: {'User-Agent': 'Mozilla/5.0'},
      connectTimeout: _yinghuaConnectTimeout,
      receiveTimeout: _yinghuaReceiveTimeout,
    ),
  );
  return dio;
}

@riverpod
YinghuaApi yinghuaApi(Ref ref) => YinghuaApi(ref.watch(yinghuaDioProvider));

/// Scans forward from `var player_aaaa` for its `{...}` object literal,
/// tracking brace depth so a nested object (e.g. `vod_data`) doesn't
/// cause extraction to stop early. Returns `null` if the marker isn't
/// found or its braces never balance. (Same logic as `xifan_api.dart`'s
/// private helper of the same name -- duplicated rather than shared,
/// matching this codebase's per-source self-contained-file convention.)
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
