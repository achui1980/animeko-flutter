import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;

import 'xifan_models.dart';

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
  /// NOTE (unverified, v1 simplification): only the *first*
  /// `.anthology-list-play` list on the page is read, even when the
  /// bangumi offers multiple lines. See this method's test-file doc
  /// comment for why.
  Future<List<XifanEpisode>> listEpisodes(int bangumiId) async {
    final response = await _dio.get<String>(
      '$_watchBaseUrl/bangumi/$bangumiId.html',
      options: Options(responseType: ResponseType.plain),
    );
    final document = html_parser.parse(response.data ?? '');

    final list = document.querySelector('.anthology-list-play');
    if (list == null) return const [];

    final episodes = <XifanEpisode>[];
    for (final link in list.querySelectorAll('a')) {
      final href = link.attributes['href'];
      final title = link.text.trim();
      if (href == null || title.isEmpty) continue;
      final url = href.startsWith('http') ? href : '$_watchBaseUrl$href';
      episodes.add(XifanEpisode(title: title, watchPageUrl: url));
    }
    return episodes;
  }
}
