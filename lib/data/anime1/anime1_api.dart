// lib/data/anime1/anime1_api.dart
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'anime1_models.dart';

part 'anime1_api.g.dart';

const _baseUrl = 'https://anime1.me';
const _apiUrl = 'https://v.anime1.me/api';

/// Direct HTML-scraping client for anime1.me. There is no official API or
/// documentation -- every parsing rule here is a best-effort assumption
/// based on third-party reverse-engineering writeups, flagged individually
/// below, and needs real-site verification before this is trusted in
/// production (see the design doc's "测试策略" section).
class Anime1Api {
  Anime1Api(this._dio);
  final Dio _dio;

  /// GET https://anime1.me/?s=<title>
  ///
  /// NOTE (unverified): assumes anime1.me's WordPress theme marks each
  /// article's category link with `rel="category tag"`, which is a common
  /// WordPress convention but not confirmed for this specific site. If the
  /// real markup differs, this selector needs updating.
  Future<List<Anime1Category>> searchCategories(String title) async {
    final response = await _dio.get<String>(
      '$_baseUrl/',
      queryParameters: {'s': title},
      options: Options(responseType: ResponseType.plain),
    );
    final document = html_parser.parse(response.data ?? '');

    final seenIds = <int>{};
    final categories = <Anime1Category>[];
    for (final anchor in document.querySelectorAll('a[rel="category tag"]')) {
      final href = anchor.attributes['href'];
      final match = href == null ? null : RegExp(r'[?&]cat=(\d+)').firstMatch(href);
      if (match == null) continue;
      final id = int.parse(match.group(1)!);
      if (!seenIds.add(id)) continue;
      final title = anchor.text.trim();
      if (title.isEmpty) continue;
      categories.add(Anime1Category(id: id, title: title));
    }
    return categories;
  }
}

@riverpod
Dio anime1Dio(Ref ref) {
  // anime1.me's only anti-hotlinking check is the Referer header -- see
  // the design doc's "背景与范围" section. No auth, no other headers
  // needed.
  return Dio(BaseOptions(headers: {'Referer': 'https://anime1.me'}));
}

@riverpod
Anime1Api anime1Api(Ref ref) => Anime1Api(ref.watch(anime1DioProvider));
