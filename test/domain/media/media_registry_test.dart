// test/domain/media/media_registry_test.dart
import 'package:animeko_flutter/data/anime1/anime1_api.dart';
import 'package:animeko_flutter/data/anime1/anime1_models.dart';
import 'package:animeko_flutter/data/xifan/xifan_api.dart';
import 'package:animeko_flutter/data/xifan/xifan_models.dart';
import 'package:animeko_flutter/domain/media/media_registry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class MockAnime1Api extends Mock implements Anime1Api {}

class MockXifanApi extends Mock implements XifanApi {}

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
      when(() => api.searchCategories('鬼灭之刃')).thenAnswer(
        (_) async => [const Anime1Category(id: 1, title: '鬼灭之刃')],
      );
      final result = await source.search('鬼灭之刃');
      expect(result, hasLength(1));
      expect(result.single.title, '鬼灭之刃');
    });

    test("listEpisodes delegates to fetchCategoryEpisodes using the candidate's id", () async {
      when(() => api.fetchCategoryEpisodes(87)).thenAnswer(
        (_) async => [const Anime1Episode(title: 'ep1', pageUrl: 'https://anime1.me/1')],
      );
      final result = await source.listEpisodes(const Anime1Category(id: 87, title: 'x'));
      expect(result, hasLength(1));
    });

    test("resolvePlayback delegates to resolvePlaybackUrl using the episode's pageUrl", () async {
      when(() => api.resolvePlaybackUrl('https://anime1.me/1')).thenAnswer(
        (_) async => const Anime1PlaybackSource(url: 'https://video.example.com/a.mp4'),
      );
      final result = await source.resolvePlayback(
        const Anime1Episode(title: 'ep1', pageUrl: 'https://anime1.me/1'),
      );
      expect(result.url, 'https://video.example.com/a.mp4');
    });
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
        (_) async => [const XifanBangumi(id: 1001, title: '鬼灭之刃')],
      );
      final result = await source.search('鬼灭之刃');
      expect(result, hasLength(1));
    });

    test("listEpisodes delegates to listEpisodes using the candidate's id", () async {
      when(() => api.listEpisodes(1001)).thenAnswer(
        (_) async => [
          const XifanEpisode(
            title: '第01集',
            watchPageUrl: 'https://dm1.xfdm.pro/watch/1001/1/1.html',
          ),
        ],
      );
      final result = await source.listEpisodes(const XifanBangumi(id: 1001, title: 'x'));
      expect(result, hasLength(1));
    });

    test("resolvePlayback delegates to resolvePlaybackUrl using the episode's watchPageUrl", () async {
      when(() => api.resolvePlaybackUrl('https://dm1.xfdm.pro/watch/1001/1/1.html')).thenAnswer(
        (_) async => const XifanPlaybackSource(url: 'https://apn.moedot.net/d/wo/1/a.mp4'),
      );
      final result = await source.resolvePlayback(
        const XifanEpisode(
          title: '第01集',
          watchPageUrl: 'https://dm1.xfdm.pro/watch/1001/1/1.html',
        ),
      );
      expect(result.url, 'https://apn.moedot.net/d/wo/1/a.mp4');
    });
  });

  test('mediaSourcesProvider returns both the anime1 and xifan sources', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final sources = container.read(mediaSourcesProvider);
    expect(sources.map((s) => s.id), ['anime1', 'xifan']);
  });
}
