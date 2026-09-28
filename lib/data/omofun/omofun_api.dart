import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'm3u8_line_prober.dart';
import 'omofun_models.dart';

part 'omofun_api.g.dart';

/// omofun.in announces omofun.tv as its newest domain; switch here if the
/// current one dies. No multi-domain fallback in v1.
const omofunBaseUrl = 'https://omofun.in';

const _desktopUserAgent =
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36';
const _siteTimeout = Duration(seconds: 15);

/// Scraper for omofun.in (MacCMS, mxpro theme). Site requests use [_dio]
/// (global proxy applies); line probes use [_probeDio] (forced direct, to
/// match how libmpv will fetch the stream).
class OmofunApi {
  OmofunApi(
    this._dio, {
    required Dio probeDio,
    this.probeTimeout = defaultProbeTimeout,
  }) : _probeDio = probeDio;

  final Dio _dio;
  final Dio _probeDio;
  final Duration probeTimeout;

  Future<List<OmofunCandidate>> search(String keyword) async {
    final res = await _dio.get<String>(
      '$omofunBaseUrl/vod/search.html',
      queryParameters: {'wd': keyword},
      options: Options(responseType: ResponseType.plain),
    );
    return parseOmofunSearch(res.data ?? '');
  }

  Future<List<OmofunEpisode>> listEpisodes(String vodId) async {
    final res = await _dio.get<String>(
      '$omofunBaseUrl/vod/detail/$vodId.html',
      options: Options(responseType: ResponseType.plain),
    );
    return parseOmofunEpisodes(res.data ?? '', vodId);
  }

  /// Returns the live lines, or every line if none probe as live (let the
  /// player's auto-fallback have a go). Throws [StateError] when the site
  /// returns no lines at all.
  Future<List<OmofunPlaybackSource>> resolvePlayback(
    OmofunEpisode episode,
  ) async {
    final String body;
    try {
      final res = await _dio.get<String>(
        '$omofunBaseUrl/_dyn_plays/${episode.vodId}/ep${episode.ep}',
        options: Options(responseType: ResponseType.plain),
      );
      body = res.data ?? '';
    } on DioException {
      throw StateError('omofun: no playable lines');
    }

    final lines = parseOmofunPlays(body);
    if (lines.isEmpty) throw StateError('omofun: no playable lines');

    try {
      final live = await probeM3u8Lines(
        lines,
        urlOf: (l) => l.url,
        dio: _probeDio,
        timeout: probeTimeout,
      );
      return live.isEmpty ? lines : live;
    } catch (_) {
      return lines;
    }
  }
}

/// An adapter whose clients never use a proxy, overriding whatever
/// `HttpOverrides.global` (the app proxy setting) configured.
IOHttpClientAdapter directHttpClientAdapter() => IOHttpClientAdapter(
  createHttpClient: () => HttpClient()..findProxy = (_) => 'DIRECT',
);

@riverpod
Dio omofunDio(Ref ref) => Dio(
  BaseOptions(
    headers: {'User-Agent': _desktopUserAgent},
    connectTimeout: _siteTimeout,
    receiveTimeout: _siteTimeout,
  ),
);

@riverpod
Dio omofunProbeDio(Ref ref) =>
    Dio(BaseOptions(headers: {'User-Agent': _desktopUserAgent}))
      ..httpClientAdapter = directHttpClientAdapter();

@riverpod
OmofunApi omofunApi(Ref ref) => OmofunApi(
  ref.watch(omofunDioProvider),
  probeDio: ref.watch(omofunProbeDioProvider),
);
