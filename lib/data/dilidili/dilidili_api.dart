import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'dilidili_models.dart';
import '../settings/proxy_dio_config.dart';

part 'dilidili_api.g.dart';

/// Direct HTML-scraping client for 嘀哩嘀哩. There is no official API or
/// documentation -- every parsing rule here is a best-effort assumption
/// based on live-site investigation (2026-09-05) and needs
/// re-verification before this is trusted in production (same caveat as
/// `XifanApi`/`YinghuaApi`).
class DilidiliApi {
  DilidiliApi(this._dio);
  final Dio _dio;

  static const _baseUrl = 'https://dilidili.io';

  /// GET https://dilidili.io/search?q=`<title>`&kwtype=0
  ///
  /// Each result is one `<dl>` under `.anime_list`; its title lives at
  /// `dd h3 > a` and its detail-page link (`/anime/<slug>/`) is the same
  /// `<a>`'s `href` (confirmed live 2026-09-05).
  Future<List<DilidiliAnime>> search(String title) async {
    final response = await _dio.get<String>(
      '$_baseUrl/search',
      queryParameters: {'q': title, 'kwtype': '0'},
      options: Options(responseType: ResponseType.plain),
    );
    final document = html_parser.parse(response.data ?? '');

    final slugPattern = RegExp(r'^/anime/([^/]+)/?$');
    final seenSlugs = <String>{};
    final results = <DilidiliAnime>[];
    for (final dl in document.querySelectorAll('.anime_list dl')) {
      final link = dl.querySelector('dd h3 a');
      if (link == null) continue;
      final href = link.attributes['href'];
      final title = link.text.trim();
      if (href == null || title.isEmpty) continue;
      final match = slugPattern.firstMatch(href);
      if (match == null) continue;
      final slug = match.group(1)!;
      if (!seenSlugs.add(slug)) continue;
      results.add(DilidiliAnime(slug: slug, title: title));
    }
    return results;
  }

  /// GET https://dilidili.io/anime/`<slug>`/
  ///
  /// Episode links live at `.time_con ul.clear li > a`; the episode
  /// label is the nested `em > span` text (e.g. `第1176集`) rather than
  /// the whole link text, which also repeats the series name (confirmed
  /// live 2026-09-05).
  Future<List<DilidiliEpisode>> listEpisodes(String slug) async {
    final response = await _dio.get<String>(
      '$_baseUrl/anime/$slug/',
      options: Options(responseType: ResponseType.plain),
    );
    final document = html_parser.parse(response.data ?? '');

    final episodes = <DilidiliEpisode>[];
    for (final link in document.querySelectorAll('.time_con ul.clear li > a')) {
      final href = link.attributes['href'];
      if (href == null) continue;
      final title =
          link.querySelector('em > span')?.text.trim() ?? link.text.trim();
      if (title.isEmpty) continue;
      final url = href.startsWith('http') ? href : '$_baseUrl$href';
      episodes.add(DilidiliEpisode(title: title, watchPageUrl: url));
    }
    return episodes;
  }

  /// Resolves ALL playable "线路" (line) candidates for the given watch
  /// page, in the order they appear on the page. The watch page can list
  /// multiple `button.play-btn` elements (one per line), each with its
  /// own `play_id`; every line is independently resolved via
  /// `/_get_play`. Lines that fail to resolve (network error, malformed
  /// JSON, missing `play_data`) are skipped rather than aborting the
  /// whole call — an exception is only thrown if EVERY line fails.
  Future<List<DilidiliPlaybackSource>> resolvePlaybackUrl(
    String watchPageUrl,
  ) async {
    final watchResponse = await _dio.get<String>(
      watchPageUrl,
      options: Options(responseType: ResponseType.plain),
    );
    final document = html_parser.parse(watchResponse.data ?? '');

    final playIds = document
        .querySelectorAll('button.play-btn')
        .map((button) => button.attributes['play_id'])
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList();
    if (playIds.isEmpty) {
      throw const FormatException(
        '嘀哩嘀哩 watch page has no button.play-btn with a play_id',
      );
    }

    final sources = <DilidiliPlaybackSource>[];
    for (final playId in playIds) {
      try {
        final playResponse = await _dio.get<String>(
          '$_baseUrl/_get_play',
          queryParameters: {'id': playId},
          options: Options(
            responseType: ResponseType.plain,
            headers: {'Referer': watchPageUrl},
          ),
        );
        final playData =
            jsonDecode(playResponse.data ?? '{}') as Map<String, dynamic>;
        final result = playData['result'] as Map<String, dynamic>?;
        final url = result?['play_data'] as String?;
        if (url == null || url.isEmpty) continue;
        sources.add(
          DilidiliPlaybackSource(
            url: url,
            headers: const {'Referer': 'https://dilidili.io/'},
          ),
        );
      } catch (_) {
        continue;
      }
    }

    if (sources.isEmpty) {
      throw const FormatException('嘀哩嘀哩 /_get_play has no "play_data" field');
    }
    return sources;
  }
}

@riverpod
Dio dilidiliDio(Ref ref) {
  final dio = Dio(BaseOptions(headers: {'User-Agent': 'Mozilla/5.0'}));
  configureProxy(dio, ref);
  return dio;
}

@riverpod
DilidiliApi dilidiliApi(Ref ref) => DilidiliApi(ref.watch(dilidiliDioProvider));
