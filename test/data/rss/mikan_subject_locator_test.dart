import 'dart:io';

import 'package:animeko_flutter/data/rss/mikan_subject_locator.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

/// The real Bangumi subject / Mikan bangumi ids for
/// 「恶女不才，请多关照 ～雏宫蝶鼠换身传～」 (see the design doc).
const _subjectId = 545008;
const _bangumiId = 4012;
const _decoyBangumiId = 3999;

const _nameCn = '恶女不才，请多关照 ～雏宫蝶鼠换身传～';
const _nameJp = 'ふつつかな悪女ではございますが ～雛宮蝶鼠伝奇～';

String searchUrl(String keyword) =>
    'https://mikanani.me/Home/Search?searchstr=${Uri.encodeQueryComponent(keyword)}';

String bangumiPageUrl(int bangumiId) =>
    'https://mikanani.me/Home/Bangumi/$bangumiId';

void main() {
  late MockDio dio;
  late MikanSubjectLocator locator;
  late String searchPage;
  late String emptySearchPage;
  late String bangumiPage4012;
  late String bangumiPage3999;

  setUpAll(() {
    searchPage = File(
      'test/fixtures/mikan/home_search_4012.html',
    ).readAsStringSync();
    emptySearchPage = File(
      'test/fixtures/mikan/home_search_empty.html',
    ).readAsStringSync();
    bangumiPage4012 = File(
      'test/fixtures/mikan/home_bangumi_4012.html',
    ).readAsStringSync();
    bangumiPage3999 = File(
      'test/fixtures/mikan/home_bangumi_3999.html',
    ).readAsStringSync();
  });

  setUp(() {
    dio = MockDio();
    locator = MikanSubjectLocator(dio);
  });

  Response<String> htmlResponse(String body) => Response(
    data: body,
    requestOptions: RequestOptions(path: '/'),
    statusCode: 200,
  );

  /// Serves [bodies] by exact URL; any other URL gets the "no results"
  /// search page, so a test only has to declare the URLs it cares about.
  void stubPages(Map<String, String> bodies) {
    when(
      () => dio.get<String>(any(), options: any(named: 'options')),
    ).thenAnswer((invocation) async {
      final url = invocation.positionalArguments.first as String;
      return htmlResponse(bodies[url] ?? emptySearchPage);
    });
  }

  List<String> requestedUrls() => verify(
    () => dio.get<String>(captureAny(), options: any(named: 'options')),
  ).captured.cast<String>();

  group('parseMikanSearchResults', () {
    test('parses every 条目 card in document order', () {
      final cards = parseMikanSearchResults(searchPage);

      expect(cards, hasLength(2));
      expect(cards[0].bangumiId, _decoyBangumiId);
      expect(cards[0].title, '不完美恶女 剧场版');
      expect(cards[1].bangumiId, _bangumiId);
      expect(cards[1].title, _nameCn);
    });

    test('returns an empty list for a page with no cards', () {
      expect(parseMikanSearchResults(emptySearchPage), isEmpty);
    });

    test('returns an empty list for garbage input', () {
      expect(parseMikanSearchResults('not html at all'), isEmpty);
    });
  });

  group('mikanSearchCandidates', () {
    test('truncates the Chinese name at the first ～ and keeps the raw name '
        'as the last resort', () {
      expect(mikanSearchCandidates(nameCn: _nameCn), ['恶女不才，请多关照', _nameCn]);
    });

    test('inserts the truncated Japanese name as the second candidate', () {
      expect(mikanSearchCandidates(nameCn: _nameCn, nameJp: _nameJp), [
        '恶女不才，请多关照',
        'ふつつかな悪女ではございますが',
        _nameCn,
      ]);
    });

    test('truncates at half-width and full-width parentheses too', () {
      expect(mikanSearchCandidates(nameCn: '某番剧（第二季）').first, '某番剧');
      expect(mikanSearchCandidates(nameCn: '某番剧 (2026)').first, '某番剧');
      expect(mikanSearchCandidates(nameCn: '某番剧 ~副标题~').first, '某番剧');
    });

    test('de-duplicates when no truncation happened', () {
      expect(mikanSearchCandidates(nameCn: '孤独摇滚'), ['孤独摇滚']);
    });

    test('skips a blank or duplicate Japanese name', () {
      expect(mikanSearchCandidates(nameCn: '孤独摇滚', nameJp: '   '), ['孤独摇滚']);
      expect(mikanSearchCandidates(nameCn: '孤独摇滚', nameJp: '孤独摇滚'), ['孤独摇滚']);
    });
  });

  group('resolveBangumiId', () {
    test('returns the bangumiId whose page back-links this subject, '
        'verifying the highest-similarity card first', () async {
      stubPages({
        searchUrl('恶女不才，请多关照'): searchPage,
        bangumiPageUrl(_bangumiId): bangumiPage4012,
        bangumiPageUrl(_decoyBangumiId): bangumiPage3999,
      });

      final result = await locator.resolveBangumiId(
        subjectId: _subjectId,
        nameCn: _nameCn,
      );

      expect(result, _bangumiId);
      // Exactly two requests: the first keyword candidate, then the
      // best-ranked card's page. The decoy (listed first in the HTML) must
      // never be fetched.
      expect(requestedUrls(), [
        searchUrl('恶女不才，请多关照'),
        bangumiPageUrl(_bangumiId),
      ]);
    });

    test('falls back to the Japanese name when the Chinese candidate finds '
        'no cards', () async {
      stubPages({
        searchUrl('ふつつかな悪女ではございますが'): searchPage,
        bangumiPageUrl(_bangumiId): bangumiPage4012,
      });

      final result = await locator.resolveBangumiId(
        subjectId: _subjectId,
        nameCn: _nameCn,
        nameJp: _nameJp,
      );

      expect(result, _bangumiId);
      expect(requestedUrls(), [
        searchUrl('恶女不才，请多关照'),
        searchUrl('ふつつかな悪女ではございますが'),
        bangumiPageUrl(_bangumiId),
      ]);
    });

    test(
      'returns null when no card back-links the requested subject',
      () async {
        stubPages({
          searchUrl('恶女不才，请多关照'): searchPage,
          bangumiPageUrl(_bangumiId): bangumiPage4012,
          bangumiPageUrl(_decoyBangumiId): bangumiPage3999,
        });

        final result = await locator.resolveBangumiId(
          subjectId: 999999,
          nameCn: _nameCn,
        );

        expect(result, isNull);
        // Both cards were verified before giving up (the cap is 3).
        expect(
          requestedUrls(),
          containsAll([
            bangumiPageUrl(_bangumiId),
            bangumiPageUrl(_decoyBangumiId),
          ]),
        );
      },
    );

    test('does not accept a back-link whose id merely starts with the '
        'subject id', () async {
      stubPages({
        searchUrl('恶女不才，请多关照'): searchPage,
        bangumiPageUrl(_bangumiId):
            '<html><body><a class="w-other-c" '
            'href="https://bgm.tv/subject/5450089">x</a></body></html>',
        bangumiPageUrl(_decoyBangumiId): bangumiPage3999,
      });

      final result = await locator.resolveBangumiId(
        subjectId: _subjectId,
        nameCn: _nameCn,
      );

      expect(result, isNull);
    });

    test('returns null when every keyword candidate finds no cards', () async {
      stubPages(const {});

      final result = await locator.resolveBangumiId(
        subjectId: _subjectId,
        nameCn: _nameCn,
        nameJp: _nameJp,
      );

      expect(result, isNull);
      expect(requestedUrls(), hasLength(3));
    });

    test(
      'returns null instead of throwing when a search request fails',
      () async {
        when(
          () => dio.get<String>(any(), options: any(named: 'options')),
        ).thenThrow(
          DioException.connectionTimeout(
            timeout: const Duration(seconds: 10),
            requestOptions: RequestOptions(path: '/'),
          ),
        );

        await expectLater(
          locator.resolveBangumiId(subjectId: _subjectId, nameCn: _nameCn),
          completion(isNull),
        );
      },
    );

    test('returns null instead of throwing when a verification request '
        'fails', () async {
      when(
        () => dio.get<String>(any(), options: any(named: 'options')),
      ).thenAnswer((invocation) async {
        final url = invocation.positionalArguments.first as String;
        if (url.startsWith('https://mikanani.me/Home/Bangumi/')) {
          throw DioException.badResponse(
            statusCode: 404,
            requestOptions: RequestOptions(path: url),
            response: Response(
              statusCode: 404,
              requestOptions: RequestOptions(path: url),
            ),
          );
        }
        return htmlResponse(searchPage);
      });

      await expectLater(
        locator.resolveBangumiId(subjectId: _subjectId, nameCn: _nameCn),
        completion(isNull),
      );
    });
  });
}
