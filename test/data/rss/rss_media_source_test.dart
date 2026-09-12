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

const _bangumiFeedUrl = 'https://mikanani.me/RSS/Bangumi?bangumiId=4012';
const _keywordUrlPrefix = 'https://mikanani.me/RSS/Search?searchstr=';

/// A well-formed feed with zero `<item>`s -- what Mikan serves for a
/// bangumiId that no longer exists (or after an endpoint change): HTTP 200,
/// parseable XML, no releases.
const _emptyFeedXml =
    '<?xml version="1.0" encoding="UTF-8"?>'
    '<rss version="2.0"><channel><title>Mikan Project</title></channel></rss>';

DioException _dioFailure(String url) => DioException(
  requestOptions: RequestOptions(path: url),
  message: 'boom',
);

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
      ).thenAnswer(
        (_) async =>
            const MikanLocateResult(MikanLocateOutcome.found, _bangumiId),
      );

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

    test('falls back to keyword search when the locator conclusively finds '
        'nothing, and caches that negative result', () async {
      when(() => mappings.lookup(_subjectId)).thenAnswer((_) async => null);
      when(
        () => locator.resolveBangumiId(
          subjectId: _subjectId,
          nameCn: _nameCn,
          nameJp: null,
        ),
      ).thenAnswer(
        (_) async => const MikanLocateResult(MikanLocateOutcome.absent),
      );

      await mappedSource.search(_nameCn, subjectId: _subjectId);

      expect(
        requestedUrls().single,
        startsWith('https://mikanani.me/RSS/Search?searchstr='),
      );
      verify(() => mappings.save(_subjectId, null)).called(1);
    });

    test('falls back to keyword search WITHOUT caching when the locator '
        'could not determine an answer', () async {
      when(() => mappings.lookup(_subjectId)).thenAnswer((_) async => null);
      when(
        () => locator.resolveBangumiId(
          subjectId: _subjectId,
          nameCn: _nameCn,
          nameJp: null,
        ),
      ).thenAnswer(
        (_) async => const MikanLocateResult(MikanLocateOutcome.undetermined),
      );

      await mappedSource.search(_nameCn, subjectId: _subjectId);

      // This call still degrades to the keyword search...
      expect(
        requestedUrls().single,
        startsWith('https://mikanani.me/RSS/Search?searchstr='),
      );
      // ...but persisting it would mean "confirmed absent from Mikan" for
      // the whole 7-day negative TTL, so one transient failure would pin
      // the subject to the lossy keyword search for a week with no recovery
      // path (nothing ever deletes a mapping row). The next visit must be
      // free to ask the locator again.
      verifyNever(() => mappings.save(any(), any()));
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
      // Re-saving a cached negative would refresh its `resolvedAt`, so the
      // 7-day negative TTL could never elapse and the subject would never
      // be retried once it does appear on Mikan.
      verifyNever(() => mappings.save(any(), any()));
    });

    test('falls back to keyword search when no subjectId is given', () async {
      await mappedSource.search(_nameCn);

      expect(
        requestedUrls().single,
        startsWith('https://mikanani.me/RSS/Search?searchstr='),
      );
      verifyNever(() => mappings.lookup(any()));
    });

    // `_resolveBangumiId` promises to return null on ANY problem, so every
    // collaborator call it makes must degrade to the keyword search -- a
    // mapping is an optimization, never a precondition. Covering only
    // `lookup` here would leave the other two throw-paths free to escape.
    final throwingCollaborators = <String, void Function()>{
      'mappings.lookup': () {
        when(
          () => mappings.lookup(_subjectId),
        ).thenThrow(Exception('db closed'));
      },
      'mappings.readJapaneseName': () {
        when(() => mappings.lookup(_subjectId)).thenAnswer((_) async => null);
        when(
          () => mappings.readJapaneseName(_subjectId),
        ).thenThrow(Exception('db closed'));
      },
      'locator.resolveBangumiId': () {
        when(() => mappings.lookup(_subjectId)).thenAnswer((_) async => null);
        when(
          () => locator.resolveBangumiId(
            subjectId: _subjectId,
            nameCn: _nameCn,
            nameJp: null,
          ),
        ).thenThrow(Exception('unexpected locator crash'));
      },
    };

    for (final entry in throwingCollaborators.entries) {
      test('falls back to keyword search when ${entry.key} throws', () async {
        entry.value();

        await mappedSource.search(_nameCn, subjectId: _subjectId);

        expect(requestedUrls().single, startsWith(_keywordUrlPrefix));
      });
    }

    test('keeps using the per-bangumi feed when caching the resolved '
        'mapping fails', () async {
      when(() => mappings.lookup(_subjectId)).thenAnswer((_) async => null);
      when(
        () => locator.resolveBangumiId(
          subjectId: _subjectId,
          nameCn: _nameCn,
          nameJp: null,
        ),
      ).thenAnswer(
        (_) async =>
            const MikanLocateResult(MikanLocateOutcome.found, _bangumiId),
      );
      when(() => mappings.save(any(), any())).thenThrow(Exception('db closed'));

      await mappedSource.search(_nameCn, subjectId: _subjectId);

      // The id was already paid for with 1-6 HTTP requests; a failed cache
      // write must only cost a re-resolve next visit, not the whole feed.
      expect(requestedUrls(), [_bangumiFeedUrl]);
    });

    test('a source without a locator keeps using keyword search', () async {
      await source.search(_nameCn, subjectId: _subjectId);

      expect(
        requestedUrls().single,
        startsWith('https://mikanani.me/RSS/Search?searchstr='),
      );
    });

    group('per-bangumi feed fallbacks', () {
      /// Answers the mock Dio per URL: these tests need the per-bangumi feed
      /// and the keyword search to behave differently within one `search`.
      void routeDio(Future<Response<String>> Function(String url) handler) {
        when(() => dio.get<String>(any())).thenAnswer(
          (invocation) =>
              handler(invocation.positionalArguments.first as String),
        );
      }

      setUp(() {
        when(
          () => mappings.lookup(_subjectId),
        ).thenAnswer((_) async => const CachedMikanMapping(_bangumiId));
      });

      test('retries the keyword search when the per-bangumi feed request '
          'throws', () async {
        routeDio((url) async {
          if (url.startsWith(_bangumiFeedUrl)) throw _dioFailure(url);
          return _xmlResponse(xmlBody);
        });

        final candidates = await mappedSource.search(
          _nameCn,
          subjectId: _subjectId,
        );

        expect(requestedUrls(), [
          _bangumiFeedUrl,
          startsWith(_keywordUrlPrefix),
        ]);
        expect((candidates.single as RssSeriesCandidate).groups, isNotEmpty);
      });

      test('retries the keyword search when the per-bangumi feed is empty '
          'but returns HTTP 200', () async {
        routeDio(
          (url) async => _xmlResponse(
            url.startsWith(_bangumiFeedUrl) ? _emptyFeedXml : xmlBody,
          ),
        );

        final candidates = await mappedSource.search(
          _nameCn,
          subjectId: _subjectId,
        );

        expect(requestedUrls(), [
          _bangumiFeedUrl,
          startsWith(_keywordUrlPrefix),
        ]);
        expect((candidates.single as RssSeriesCandidate).groups, isNotEmpty);
      });

      test('a failing keyword search still propagates after an empty '
          'per-bangumi feed', () async {
        routeDio((url) async {
          if (url.startsWith(_bangumiFeedUrl)) {
            return _xmlResponse(_emptyFeedXml);
          }
          throw _dioFailure(url);
        });

        await expectLater(
          () => mappedSource.search(_nameCn, subjectId: _subjectId),
          throwsA(isA<DioException>()),
        );
      });
    });

    test('a failing keyword search propagates unchanged', () async {
      when(() => dio.get<String>(any())).thenThrow(_dioFailure('/'));

      await expectLater(
        () => source.search(_nameCn),
        throwsA(isA<DioException>()),
      );
    });
  });
}
