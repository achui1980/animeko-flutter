// test/domain/media/media_registry_test.dart
import 'dart:io';

import 'package:animeko_flutter/data/anime1/anime1_api.dart';
import 'package:animeko_flutter/data/anime1/anime1_models.dart';
import 'package:animeko_flutter/data/dilidili/dilidili_api.dart';
import 'package:animeko_flutter/data/dilidili/dilidili_models.dart';
import 'package:animeko_flutter/data/local_database.dart';
import 'package:animeko_flutter/data/rss/mikan_subject_mapping_repository.dart';
import 'package:animeko_flutter/data/rss/rss_media_source.dart';
import 'package:animeko_flutter/data/xifan/xifan_api.dart';
import 'package:animeko_flutter/data/xifan/xifan_models.dart';
import 'package:animeko_flutter/data/yinghua/yinghua_api.dart';
import 'package:animeko_flutter/data/yinghua/yinghua_models.dart';
import 'package:animeko_flutter/domain/media/media_registry.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class MockAnime1Api extends Mock implements Anime1Api {}

class MockXifanApi extends Mock implements XifanApi {}

class MockYinghuaApi extends Mock implements YinghuaApi {}

class MockDilidiliApi extends Mock implements DilidiliApi {}

class MockDio extends Mock implements Dio {}

class MockMikanSubjectMappingRepository extends Mock
    implements MikanSubjectMappingRepository {}

void main() {
  group('Anime1MediaSource', () {
    late MockAnime1Api api;
    late Anime1MediaSource source;

    setUp(() {
      api = MockAnime1Api();
      source = Anime1MediaSource(api);
    });

    test('id and displayName', () {
      expect(source.id, 'anime1');
      expect(source.displayName, 'anime1.me');
    });

    test('search delegates to Anime1Api.searchCategories', () async {
      when(
        () => api.searchCategories('鬼灭之刃'),
      ).thenAnswer((_) async => [const Anime1Category(id: 1, title: '鬼灭之刃')]);
      final result = await source.search('鬼灭之刃');
      expect(result, hasLength(1));
      expect(result.single.title, '鬼灭之刃');
    });

    test(
      "listEpisodes delegates to fetchCategoryEpisodes using the candidate's id",
      () async {
        when(() => api.fetchCategoryEpisodes(87)).thenAnswer(
          (_) async => [
            const Anime1Episode(title: 'ep1', pageUrl: 'https://anime1.me/1'),
          ],
        );
        final result = await source.listEpisodes(
          const Anime1Category(id: 87, title: 'x'),
        );
        expect(result, hasLength(1));
      },
    );

    test(
      "resolvePlayback delegates to resolvePlaybackUrl using the episode's pageUrl",
      () async {
        when(() => api.resolvePlaybackUrl('https://anime1.me/1')).thenAnswer(
          (_) async => const Anime1PlaybackSource(
            url: 'https://video.example.com/a.mp4',
          ),
        );
        final result = await source.resolvePlayback(
          const Anime1Episode(title: 'ep1', pageUrl: 'https://anime1.me/1'),
        );
        expect(result, hasLength(1));
        expect(result.single.url, 'https://video.example.com/a.mp4');
      },
    );
  });

  group('XifanMediaSource', () {
    late MockXifanApi api;
    late XifanMediaSource source;

    setUp(() {
      api = MockXifanApi();
      source = XifanMediaSource(api);
    });

    test('id and displayName', () {
      expect(source.id, 'xifan');
      expect(source.displayName, '稀饭动漫');
    });

    test('search delegates to XifanApi.search', () async {
      when(() => api.search('鬼灭之刃')).thenAnswer(
        (_) async => [
          const XifanBangumi(
            id: 1001,
            title: '鬼灭之刃',
            backend: XifanBackend.htmlMirror,
          ),
        ],
      );
      final result = await source.search('鬼灭之刃');
      expect(result, hasLength(1));
    });

    test(
      'listEpisodes delegates to listEpisodes using the full candidate',
      () async {
        const bangumi = XifanBangumi(
          id: 1001,
          title: 'x',
          backend: XifanBackend.htmlMirror,
        );
        when(() => api.listEpisodes(bangumi)).thenAnswer(
          (_) async => [
            const XifanEpisode(
              title: '第01集',
              backend: XifanBackend.htmlMirror,
              watchPageUrls: ['https://dm1.xfdm.pro/watch/1001/1/1.html'],
            ),
          ],
        );
        final result = await source.listEpisodes(bangumi);
        expect(result, hasLength(1));
      },
    );

    test(
      "resolvePlayback delegates to resolvePlaybackUrl using the full episode",
      () async {
        const episode = XifanEpisode(
          title: '第01集',
          backend: XifanBackend.htmlMirror,
          watchPageUrls: ['https://dm1.xfdm.pro/watch/1001/1/1.html'],
        );
        when(() => api.resolvePlaybackUrl(episode)).thenAnswer(
          (_) async => const [
            XifanPlaybackSource(url: 'https://apn.moedot.net/d/wo/1/a.mp4'),
          ],
        );
        final result = await source.resolvePlayback(episode);
        expect(result, hasLength(1));
        expect(result.single.url, 'https://apn.moedot.net/d/wo/1/a.mp4');
      },
    );
  });

  group('YinghuaMediaSource', () {
    late MockYinghuaApi api;
    late YinghuaMediaSource source;

    setUp(() {
      api = MockYinghuaApi();
      source = YinghuaMediaSource(api);
    });

    test('id and displayName', () {
      expect(source.id, 'yinghua');
      expect(source.displayName, '樱花动漫');
    });

    test('search delegates to YinghuaApi.search', () async {
      when(() => api.search('鬼灭之刃')).thenAnswer(
        (_) async => [const YinghuaBangumi(id: 58802, title: '鬼灭之刃')],
      );
      final result = await source.search('鬼灭之刃');
      expect(result, hasLength(1));
    });

    test(
      "listEpisodes delegates to listEpisodes using the candidate's id",
      () async {
        when(() => api.listEpisodes(58802)).thenAnswer(
          (_) async => [
            const YinghuaEpisode(
              title: '第01集',
              playPageUrls: [
                'https://www.yinghua2.com/index.php/vod/play/id/58802/sid/1/nid/1.html',
              ],
            ),
          ],
        );
        final result = await source.listEpisodes(
          const YinghuaBangumi(id: 58802, title: 'x'),
        );
        expect(result, hasLength(1));
      },
    );

    test(
      "resolvePlayback delegates to resolvePlaybackUrl using the episode's playPageUrls",
      () async {
        when(
          () => api.resolvePlaybackUrl([
            'https://www.yinghua2.com/index.php/vod/play/id/58802/sid/1/nid/1.html',
          ]),
        ).thenAnswer(
          (_) async => const [
            YinghuaPlaybackSource(url: 'https://play.example.com/a.m3u8'),
          ],
        );
        final result = await source.resolvePlayback(
          const YinghuaEpisode(
            title: '第01集',
            playPageUrls: [
              'https://www.yinghua2.com/index.php/vod/play/id/58802/sid/1/nid/1.html',
            ],
          ),
        );
        expect(result, hasLength(1));
        expect(result.single.url, 'https://play.example.com/a.m3u8');
      },
    );
  });

  group('DilidiliMediaSource', () {
    late MockDilidiliApi api;
    late DilidiliMediaSource source;

    setUp(() {
      api = MockDilidiliApi();
      source = DilidiliMediaSource(api);
    });

    test('id and displayName', () {
      expect(source.id, 'dilidili');
      expect(source.displayName, '嘀哩嘀哩');
    });

    test('search delegates to DilidiliApi.search', () async {
      when(() => api.search('海贼王')).thenAnswer(
        (_) async => [const DilidiliAnime(slug: 'one-piece', title: '海贼王')],
      );
      final result = await source.search('海贼王');
      expect(result, hasLength(1));
    });

    test(
      "listEpisodes delegates to listEpisodes using the candidate's slug",
      () async {
        when(() => api.listEpisodes('one-piece')).thenAnswer(
          (_) async => [
            const DilidiliEpisode(
              title: '第1176集',
              watchPageUrl: 'https://dilidili.io/watch/one-piece-ep1176/',
            ),
          ],
        );
        final result = await source.listEpisodes(
          const DilidiliAnime(slug: 'one-piece', title: 'x'),
        );
        expect(result, hasLength(1));
      },
    );

    test(
      "resolvePlayback delegates to resolvePlaybackUrl using the episode's watchPageUrl",
      () async {
        when(
          () => api.resolvePlaybackUrl(
            'https://dilidili.io/watch/one-piece-ep1176/',
          ),
        ).thenAnswer(
          (_) async => const [
            DilidiliPlaybackSource(url: 'https://v.lzcdn31.com/index.m3u8'),
          ],
        );
        final result = await source.resolvePlayback(
          const DilidiliEpisode(
            title: '第1176集',
            watchPageUrl: 'https://dilidili.io/watch/one-piece-ep1176/',
          ),
        );
        expect(result, hasLength(1));
        expect(result.single.url, 'https://v.lzcdn31.com/index.m3u8');
      },
    );
  });

  test('mediaSourcesProvider returns the registered sources '
      '(yinghua and dilidili are intentionally disabled -- see '
      'mediaSources doc comment)', () {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    final sources = container.read(mediaSourcesProvider);
    expect(sources.map((s) => s.id), ['anime1', 'xifan', 'mikan']);
  });

  // Guards the *production wiring*, not RssMediaSource itself: dropping
  // either `locator:` or `mappingRepository:` from [mediaSources] leaves
  // `flutter analyze` clean and every other test green, while silently
  // reverting all Mikan searches to the lossy keyword search -- i.e. the
  // exact bug the per-bangumi feed exists to fix.
  test('the registered mikan source is wired with both subject-mapping '
      'collaborators, so it fetches the per-bangumi feed', () async {
    const subjectId = 545008;
    const bangumiId = 4012;
    final feedBody = File(
      'test/fixtures/mikan/rss_bangumi_4012.xml',
    ).readAsStringSync();

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final dio = MockDio();
    when(() => dio.get<String>(any())).thenAnswer(
      (_) async => Response<String>(
        data: feedBody,
        requestOptions: RequestOptions(path: '/'),
        statusCode: 200,
      ),
    );

    final mappings = MockMikanSubjectMappingRepository();
    when(
      () => mappings.lookup(subjectId),
    ).thenAnswer((_) async => const CachedMikanMapping(bangumiId));

    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        mikanRssDioProvider.overrideWithValue(dio),
        mikanSubjectMappingRepositoryProvider.overrideWithValue(mappings),
      ],
    );
    addTearDown(container.dispose);

    final mikan = container
        .read(mediaSourcesProvider)
        .firstWhere((s) => s.id == 'mikan');
    await mikan.search('恶女不才，请多关照', subjectId: subjectId);

    final urls = verify(
      () => dio.get<String>(captureAny()),
    ).captured.cast<String>();
    expect(urls, ['https://mikanani.me/RSS/Bangumi?bangumiId=$bangumiId']);
  });
}
