import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'yinghua_models.dart';
import '../settings/proxy_dio_config.dart';

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
  /// NOTE (v1 simplification, per explicit user decision): the site
  /// offers multiple named "lines" per title (e.g. 线路1/线路4/5线),
  /// each rendered as its own `div.stui-pannel.stui-pannel-bg` block
  /// with a full, separate episode list. This only reads the *first*
  /// such block. TODO: support switching between lines.
  Future<List<YinghuaEpisode>> listEpisodes(int id) async {
    final response = await _dio.get<String>(
      '$_baseUrl/index.php/vod/detail/id/$id.html',
      options: Options(responseType: ResponseType.plain),
    );
    final document = html_parser.parse(response.data ?? '');

    final firstLine = document.querySelector('div.stui-pannel.stui-pannel-bg');
    if (firstLine == null) return const [];

    final episodes = <YinghuaEpisode>[];
    for (final link in firstLine.querySelectorAll('.stui-content__playlist > li > a')) {
      final href = link.attributes['href'];
      final title = link.text.trim();
      if (href == null || title.isEmpty) continue;
      final url = href.startsWith('http') ? href : '$_baseUrl$href';
      episodes.add(YinghuaEpisode(title: title, playPageUrl: url));
    }
    return episodes;
  }

  /// GET the play page, extract the inline `var player_aaaa = {...};`
  /// object, and use its `url` field as-is (see `YinghuaPlaybackSource`'s
  /// doc comment -- no decryption is needed on this site).
  Future<YinghuaPlaybackSource> resolvePlaybackUrl(String playPageUrl) async {
    final response = await _dio.get<String>(
      playPageUrl,
      options: Options(responseType: ResponseType.plain),
    );
    final body = response.data ?? '';

    final json = _extractPlayerJson(body);
    if (json == null) {
      throw const FormatException(
        '樱花动漫 play page has no player_aaaa script variable',
      );
    }

    final playerData = jsonDecode(json) as Map<String, dynamic>;
    final url = playerData['url'] as String?;
    if (url == null || url.isEmpty) {
      throw const FormatException('樱花动漫 player_aaaa has no "url" field');
    }

    return YinghuaPlaybackSource(
      url: url,
      headers: const {'Referer': 'https://www.yinghua2.com/'},
    );
  }
}

@riverpod
Dio yinghuaDio(Ref ref) {
  final dio = Dio(BaseOptions(headers: {'User-Agent': 'Mozilla/5.0'}));
  configureProxy(dio, ref);
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
