import 'dart:io';

import 'package:animeko_flutter/data/rss/mikan_subject_locator.dart';
import 'package:animeko_flutter/data/rss/mikan_subject_mapping_repository.dart';
import 'package:animeko_flutter/data/rss/rss_media_source.dart';
import 'package:animeko_flutter/data/torrent/rqbit_engine.dart';
import 'package:animeko_flutter/data/torrent/torrent_playback_source.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

class MockRqbitEngine extends Mock implements RqbitEngine {}

class MockMikanSubjectLocator extends Mock implements MikanSubjectLocator {}

class MockMikanSubjectMappingRepository extends Mock
    implements MikanSubjectMappingRepository {}

Response<String> _xmlResponse(String body) => Response(
  data: body,
  requestOptions: RequestOptions(path: '/'),
  statusCode: 200,
);

/// The real Bangumi subject / Mikan bangumi ids for
/// 「恶女不才，请多关照 ～雏宫蝶鼠换身传～」 (see the design doc).
const _subjectId = 545008;
const _bangumiId = 4012;
const _nameCn = '恶女不才，请多关照 ～雏宫蝶鼠换身传～';

void main() {
  late MockDio dio;
  late MockRqbitEngine engine;
  late RssMediaSource source;
  late String xmlBody;
  late String bangumiFeedBody;

  setUpAll(() {
    xmlBody = File(
      'test/fixtures/mikan_rss_search_sample.xml',
    ).readAsStringSync();
    bangumiFeedBody = File(
      'test/fixtures/mikan/rss_bangumi_4012.xml',
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

  test(
    'search fetches the templated URL and groups results by episode',
    () async {
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
    },
  );

  test(
    'listEpisodes converts cached groups synchronously, sorted ascending',
    () async {
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
    },
  );

  test(
    'resolvePlayback maps every release to a TorrentPlaybackSource',
    () async {
      when(
        () => dio.get<String>(any()),
      ).thenAnswer((_) async => _xmlResponse(xmlBody));
      final candidates = await source.search('魔法少女奈叶');
      final episodes = await source.listEpisodes(candidates.single);
      final ep10 = episodes.cast<RssEpisode>().firstWhere(
        (e) => e.episodeNumber == 10,
      );

      final playbackSources = await source.resolvePlayback(ep10);

      expect(playbackSources, isNotEmpty);
      expect(playbackSources, everyElement(isA<TorrentPlaybackSource>()));
    },
  );

  group('search with a subject mapping', () {
    late MockMikanSubjectLocator locator;
    late MockMikanSubjectMappingRepository mappings;
    late RssMediaSource mappedSource;

    setUp(() {
      locator = MockMikanSubjectLocator();
      mappings = MockMikanSubjectMappingRepository();
      mappedSource = RssMediaSource(
        mikanRssSourceConfig,
        dio,
        engine,
        locator: locator,
        mappingRepository: mappings,
      );
      when(
        () => dio.get<String>(any()),
      ).thenAnswer((_) async => _xmlResponse(bangumiFeedBody));
      when(() => mappings.save(any(), any())).thenAnswer((_) async {});
      when(
        () => mappings.readJapaneseName(any()),
      ).thenAnswer((_) async => null);
    });

    List<String> requestedUrls() =>
        verify(() => dio.get<String>(captureAny())).captured.cast<String>();

    test(
      'config exposes the Mikan subject-search and bangumi-feed templates',
      () {
        expect(
          mikanRssSourceConfig.subjectSearchUrl,
          'https://mikanani.me/Home/Search?searchstr={keyword}',
        );
        expect(
          mikanRssSourceConfig.bangumiFeedUrl,
          'https://mikanani.me/RSS/Bangumi?bangumiId={bangumiId}',
        );
      },
    );

    test('uses the cached mapping and fetches the per-bangumi feed', () async {
      when(
        () => mappings.lookup(_subjectId),
      ).thenAnswer((_) async => const CachedMikanMapping(_bangumiId));

      await mappedSource.search(_nameCn, subjectId: _subjectId);

      expect(requestedUrls(), [
        'https://mikanani.me/RSS/Bangumi?bangumiId=4012',
      ]);
      verifyNever(
        () => locator.resolveBangumiId(
          subjectId: any(named: 'subjectId'),
          nameCn: any(named: 'nameCn'),
          nameJp: any(named: 'nameJp'),
        ),
      );
      verifyNever(() => mappings.save(any(), any()));
    });

    test('resolves and caches the mapping on a cache miss', () async {
      when(() => mappings.lookup(_subjectId)).thenAnswer((_) async => null);
      when(
        () => mappings.readJapaneseName(_subjectId),
      ).thenAnswer((_) async => 'ふつつかな悪女ではございますが');
      when(
        () => locator.resolveBangumiId(
          subjectId: _subjectId,
          nameCn: _nameCn,
          nameJp: 'ふつつかな悪女ではございますが',
        ),
      ).thenAnswer((_) async => _bangumiId);

      await mappedSource.search(_nameCn, subjectId: _subjectId);

      expect(requestedUrls(), [
        'https://mikanani.me/RSS/Bangumi?bangumiId=4012',
      ]);
      verify(() => mappings.save(_subjectId, _bangumiId)).called(1);
    });

    test(
      'the per-bangumi feed yields every subtitle group for episode 1',
      () async {
        when(
          () => mappings.lookup(_subjectId),
        ).thenAnswer((_) async => const CachedMikanMapping(_bangumiId));

        final candidates = await mappedSource.search(
          _nameCn,
          subjectId: _subjectId,
        );

        final groups = (candidates.single as RssSeriesCandidate).groups;
        expect(groups.keys, containsAll([1, 2]));
        expect(
          groups[1]!.map((r) => r.parsed.alliance),
          containsAll(['TSDM字幕组', 'LoliHouse', 'Nix-Raws']),
        );
        expect(groups[2]!.single.parsed.alliance, 'ANi');
      },
    );

    test('falls back to keyword search when the locator finds nothing, '
        'and caches that negative result', () async {
      when(() => mappings.lookup(_subjectId)).thenAnswer((_) async => null);
      when(
        () => locator.resolveBangumiId(
          subjectId: _subjectId,
          nameCn: _nameCn,
          nameJp: null,
        ),
      ).thenAnswer((_) async => null);

      await mappedSource.search(_nameCn, subjectId: _subjectId);

      expect(
        requestedUrls().single,
        startsWith('https://mikanani.me/RSS/Search?searchstr='),
      );
      verify(() => mappings.save(_subjectId, null)).called(1);
    });

    test('falls back to keyword search for a cached negative result, '
        'without asking the locator again', () async {
      when(
        () => mappings.lookup(_subjectId),
      ).thenAnswer((_) async => const CachedMikanMapping(null));

      await mappedSource.search(_nameCn, subjectId: _subjectId);

      expect(
        requestedUrls().single,
        startsWith('https://mikanani.me/RSS/Search?searchstr='),
      );
      verifyNever(
        () => locator.resolveBangumiId(
          subjectId: any(named: 'subjectId'),
          nameCn: any(named: 'nameCn'),
          nameJp: any(named: 'nameJp'),
        ),
      );
    });

    test('falls back to keyword search when no subjectId is given', () async {
      await mappedSource.search(_nameCn);

      expect(
        requestedUrls().single,
        startsWith('https://mikanani.me/RSS/Search?searchstr='),
      );
      verifyNever(() => mappings.lookup(any()));
    });

    test(
      'falls back to keyword search when the mapping cache throws',
      () async {
        when(
          () => mappings.lookup(_subjectId),
        ).thenThrow(Exception('db closed'));

        await mappedSource.search(_nameCn, subjectId: _subjectId);

        expect(
          requestedUrls().single,
          startsWith('https://mikanani.me/RSS/Search?searchstr='),
        );
      },
    );

    test('a source without a locator keeps using keyword search', () async {
      await source.search(_nameCn, subjectId: _subjectId);

      expect(
        requestedUrls().single,
        startsWith('https://mikanani.me/RSS/Search?searchstr='),
      );
    });
  });
}
