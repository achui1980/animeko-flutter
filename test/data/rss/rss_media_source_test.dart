import 'dart:io';

import 'package:animeko_flutter/data/rss/rss_media_source.dart';
import 'package:animeko_flutter/data/torrent/rqbit_engine.dart';
import 'package:animeko_flutter/data/torrent/torrent_playback_source.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

class MockRqbitEngine extends Mock implements RqbitEngine {}

Response<String> _xmlResponse(String body) => Response(
  data: body,
  requestOptions: RequestOptions(path: '/'),
  statusCode: 200,
);

void main() {
  late MockDio dio;
  late MockRqbitEngine engine;
  late RssMediaSource source;
  late String xmlBody;

  setUpAll(() {
    xmlBody = File(
      'test/fixtures/mikan_rss_search_sample.xml',
    ).readAsStringSync();
  });

  setUp(() {
    dio = MockDio();
    engine = MockRqbitEngine();
    source = RssMediaSource(mikanRssSourceConfig, dio, engine);
  });

  test('id and displayName come from config', () {
    expect(source.id, 'mikan');
    expect(source.displayName, 'mikan');
  });

  test('search fetches the templated URL and groups results by episode', () async {
    when(
      () => dio.get<String>(any()),
    ).thenAnswer((_) async => _xmlResponse(xmlBody));

    final candidates = await source.search('魔法少女奈叶');

    expect(candidates, hasLength(1));
    final candidate = candidates.single as RssSeriesCandidate;
    expect(candidate.sourceId, 'mikan');
    expect(candidate.groups.keys, containsAll([3, 7, 8, 9, 10]));

    final captured = verify(() => dio.get<String>(captureAny())).captured;
    expect(
      captured.single,
      contains('searchstr=%E9%AD%94%E6%B3%95%E5%B0%91%E5%A5%B3'),
    );
  });

  test('listEpisodes converts cached groups synchronously, sorted ascending', () async {
    when(
      () => dio.get<String>(any()),
    ).thenAnswer((_) async => _xmlResponse(xmlBody));
    final candidates = await source.search('魔法少女奈叶');
    clearInteractions(dio);

    final episodes = await source.listEpisodes(candidates.single);

    final numbers = episodes
        .cast<RssEpisode>()
        .map((e) => e.episodeNumber)
        .toList();
    expect(numbers, numbers.toList()..sort());
    expect(numbers, containsAll([3, 7, 8, 9, 10]));

    verifyNever(() => dio.get<String>(any()));
  });

  test('resolvePlayback maps every release to a TorrentPlaybackSource', () async {
    when(
      () => dio.get<String>(any()),
    ).thenAnswer((_) async => _xmlResponse(xmlBody));
    final candidates = await source.search('魔法少女奈叶');
    final episodes = await source.listEpisodes(candidates.single);
    final ep10 = episodes
        .cast<RssEpisode>()
        .firstWhere((e) => e.episodeNumber == 10);

    final playbackSources = await source.resolvePlayback(ep10);

    expect(playbackSources, isNotEmpty);
    expect(playbackSources, everyElement(isA<TorrentPlaybackSource>()));
  });
}
