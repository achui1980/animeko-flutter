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

/// A single `/Home/Search` anchor+card in the shape the real page uses.
/// [title] goes into the `div.an-text` `title` attribute verbatim (no
/// trimming) so tests can pin the parser's own trim/blank handling.
String searchCardAnchor(int bangumiId, String title) =>
    '<li><a href="/Home/Bangumi/$bangumiId" target="_blank">'
    '<div class="an-info"><div class="an-info-group">'
    '<div class="an-text" title="$title">$title</div>'
    '</div></div></a></li>';

/// Wraps [anchors] in the minimum `/Home/Search` page structure.
String searchPageWith(Iterable<String> anchors) =>
    '<!DOCTYPE html><html><body><div class="central-container">'
    '<ul class="list-inline an-ul">${anchors.join()}</ul>'
    '</div></body></html>';

/// A `/Home/Bangumi/<id>` page whose only real back-link anchor points at
/// [linkedSubjectId].
String bangumiPageLinking(int linkedSubjectId) =>
    '<!DOCTYPE html><html><body><p class="bangumi-info">'
    '<a class="w-other-c" href="https://bgm.tv/subject/$linkedSubjectId" '
    'target="_blank">https://bgm.tv/subject/$linkedSubjectId</a>'
    '</p></body></html>';

/// A *keyword-level* failure: a non-2xx answer proves the host is up, so it
/// says nothing about whether the *next* keyword would also fail.
DioException keywordLevelFailure(String url) => DioException.badResponse(
  statusCode: 503,
  requestOptions: RequestOptions(path: url),
  response: Response(
    statusCode: 503,
    requestOptions: RequestOptions(path: url),
  ),
);

/// A *host-level* failure: the transport never reached the server, so every
/// remaining keyword candidate would fail the same way (and each one costs a
/// full connect timeout).
DioException hostLevelFailure(String url) => DioException.connectionError(
  requestOptions: RequestOptions(path: url),
  reason: 'host unreachable',
);

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

    test('skips a card whose title is blank and trims a padded one', () {
      expect(
        parseMikanSearchResults(searchPageWith([searchCardAnchor(7, '   ')])),
        isEmpty,
      );

      final cards = parseMikanSearchResults(
        searchPageWith([searchCardAnchor(7, ' Padded ')]),
      );
      expect(cards, hasLength(1));
      expect(cards.single.title, 'Padded');
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

  group('MikanLocateResult', () {
    test('rejects a bangumiId that does not agree with the outcome', () {
      // A caller that trusted `bangumiId` on a non-`found` outcome would
      // cache a guess; one that ignored it on `found` would throw the
      // verified answer away. Neither shape is constructible.
      expect(
        () => MikanLocateResult(MikanLocateOutcome.found),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => MikanLocateResult(MikanLocateOutcome.absent, _bangumiId),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => MikanLocateResult(MikanLocateOutcome.undetermined, _bangumiId),
        throwsA(isA<AssertionError>()),
      );
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

      expect(result.outcome, MikanLocateOutcome.found);
      expect(result.bangumiId, _bangumiId);
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

      expect(result.outcome, MikanLocateOutcome.found);
      expect(result.bangumiId, _bangumiId);
      expect(requestedUrls(), [
        searchUrl('恶女不才，请多关照'),
        searchUrl('ふつつかな悪女ではございますが'),
        bangumiPageUrl(_bangumiId),
      ]);
    });

    test(
      'reports absent when no card back-links the requested subject',
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

        // Every request answered, every card verified and rejected: this is
        // a conclusive "not on Mikan", so it is safe to negative-cache.
        expect(result.outcome, MikanLocateOutcome.absent);
        expect(result.bangumiId, isNull);
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

      expect(result.outcome, MikanLocateOutcome.absent);
      expect(result.bangumiId, isNull);
    });

    test('reports absent when every keyword candidate finds a page with no '
        'cards', () async {
      stubPages(const {});

      final result = await locator.resolveBangumiId(
        subjectId: _subjectId,
        nameCn: _nameCn,
        nameJp: _nameJp,
      );

      expect(result.outcome, MikanLocateOutcome.absent);
      expect(result.bangumiId, isNull);
      expect(requestedUrls(), hasLength(3));
    });

    test('reports undetermined instead of absent when every search request '
        'fails', () async {
      when(
        () => dio.get<String>(any(), options: any(named: 'options')),
      ).thenThrow(
        DioException.connectionTimeout(
          timeout: const Duration(seconds: 10),
          requestOptions: RequestOptions(path: '/'),
        ),
      );

      // Awaiting (rather than catching) also pins the no-throw contract:
      // the locator runs inside SubjectEpisodesController's `Future.wait`.
      final result = await locator.resolveBangumiId(
        subjectId: _subjectId,
        nameCn: _nameCn,
      );

      // A transient network failure must NOT be cached as "absent": that
      // would pin the subject to the lossy keyword search for the whole
      // 7-day negative TTL, with no recovery path.
      expect(result.outcome, MikanLocateOutcome.undetermined);
      expect(result.bangumiId, isNull);
    });

    test('reports undetermined instead of absent when a verification '
        'request fails', () async {
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

      final result = await locator.resolveBangumiId(
        subjectId: _subjectId,
        nameCn: _nameCn,
      );

      expect(result.outcome, MikanLocateOutcome.undetermined);
      expect(result.bangumiId, isNull);
    });

    test('still tries the later keyword candidates after a keyword-level '
        'search failure', () async {
      // A non-2xx answer proves the host is up, so it says nothing about the
      // *next* keyword: the loop keeps going and can still reach a
      // conclusive `found`.
      when(
        () => dio.get<String>(any(), options: any(named: 'options')),
      ).thenAnswer((invocation) async {
        final url = invocation.positionalArguments.first as String;
        if (url == searchUrl('恶女不才，请多关照')) {
          throw keywordLevelFailure(url);
        }
        if (url == searchUrl(_nameCn)) return htmlResponse(searchPage);
        return htmlResponse(bangumiPage4012);
      });

      final result = await locator.resolveBangumiId(
        subjectId: _subjectId,
        nameCn: _nameCn,
      );

      expect(result.outcome, MikanLocateOutcome.found);
      expect(result.bangumiId, _bangumiId);
      expect(requestedUrls(), [
        searchUrl('恶女不才，请多关照'),
        searchUrl(_nameCn),
        bangumiPageUrl(_bangumiId),
      ]);
    });

    test('stays undetermined when an earlier search failed, even though the '
        'last candidate conclusively found no cards', () async {
      // The inconclusive step is sticky across the whole candidate loop:
      // "one keyword returned nothing" is not evidence of absence while
      // another keyword was never actually answered.
      when(
        () => dio.get<String>(any(), options: any(named: 'options')),
      ).thenAnswer((invocation) async {
        final url = invocation.positionalArguments.first as String;
        if (url == searchUrl('恶女不才，请多关照')) {
          throw keywordLevelFailure(url);
        }
        return htmlResponse(emptySearchPage);
      });

      final result = await locator.resolveBangumiId(
        subjectId: _subjectId,
        nameCn: _nameCn,
      );

      expect(result.outcome, MikanLocateOutcome.undetermined);
      expect(requestedUrls(), [searchUrl('恶女不才，请多关照'), searchUrl(_nameCn)]);
    });

    test('stays undetermined when the last candidate failed, even though an '
        'earlier one conclusively found no cards', () async {
      // The mirror image of the test above: the sticky flag must not depend
      // on whether the unanswered keyword came first or last.
      when(
        () => dio.get<String>(any(), options: any(named: 'options')),
      ).thenAnswer((invocation) async {
        final url = invocation.positionalArguments.first as String;
        if (url == searchUrl(_nameCn)) throw keywordLevelFailure(url);
        return htmlResponse(emptySearchPage);
      });

      final result = await locator.resolveBangumiId(
        subjectId: _subjectId,
        nameCn: _nameCn,
      );

      expect(result.outcome, MikanLocateOutcome.undetermined);
      expect(requestedUrls(), [searchUrl('恶女不才，请多关照'), searchUrl(_nameCn)]);
    });

    test('abandons the remaining keyword candidates once the host itself is '
        'unreachable', () async {
      // Every candidate targets the same host, so retrying one costs a full
      // connect timeout (10s) to learn nothing. One probe is enough.
      when(
        () => dio.get<String>(any(), options: any(named: 'options')),
      ).thenAnswer((invocation) async {
        throw hostLevelFailure(invocation.positionalArguments.first as String);
      });

      final result = await locator.resolveBangumiId(
        subjectId: _subjectId,
        nameCn: _nameCn,
        nameJp: _nameJp,
      );

      // Giving up early must not turn the answer negative-cacheable: the
      // host never said anything about this subject.
      expect(result.outcome, MikanLocateOutcome.undetermined);
      expect(result.bangumiId, isNull);
      expect(requestedUrls(), [searchUrl('恶女不才，请多关照')]);
    });

    test('still probes every keyword candidate when each search fails at the '
        'keyword level', () async {
      // Counterpart to the test above: a non-2xx can be keyword-specific, so
      // the budget of 3 candidates is still worth spending.
      when(
        () => dio.get<String>(any(), options: any(named: 'options')),
      ).thenAnswer((invocation) async {
        throw keywordLevelFailure(
          invocation.positionalArguments.first as String,
        );
      });

      final result = await locator.resolveBangumiId(
        subjectId: _subjectId,
        nameCn: _nameCn,
        nameJp: _nameJp,
      );

      expect(result.outcome, MikanLocateOutcome.undetermined);
      expect(requestedUrls(), [
        searchUrl('恶女不才，请多关照'),
        searchUrl('ふつつかな悪女ではございますが'),
        searchUrl(_nameCn),
      ]);
    });

    test('reports undetermined without throwing when a search fails with a '
        'non-Dio throwable', () async {
      // `resolveBangumiId` runs inside SubjectEpisodesController's
      // `Future.wait`, so it must swallow throwables that are neither a
      // DioException nor even an Exception.
      for (final thrown in <Object>[
        StateError('client closed'),
        'plain string failure',
      ]) {
        dio = MockDio();
        locator = MikanSubjectLocator(dio);
        when(
          () => dio.get<String>(any(), options: any(named: 'options')),
        ).thenAnswer((_) async => throw thrown);

        final result = await locator.resolveBangumiId(
          subjectId: _subjectId,
          nameCn: _nameCn,
        );

        expect(
          result.outcome,
          MikanLocateOutcome.undetermined,
          reason: '$thrown',
        );
        expect(result.bangumiId, isNull, reason: '$thrown');
      }
    });

    test('de-duplicates repeated cards so they do not eat the verification '
        'budget', () async {
      // Real Mikan cards carry more than one `/Home/Bangumi/<id>` anchor
      // per 条目 (image + text), so without de-duplication three copies of
      // the top-ranked card would consume the whole cap-of-3 budget and
      // the correct card would never be verified.
      const nameCn = '测试番剧';
      final page = searchPageWith([
        searchCardAnchor(1, nameCn),
        searchCardAnchor(1, nameCn),
        searchCardAnchor(1, nameCn),
        searchCardAnchor(9, '$nameCn 第二季'),
      ]);

      expect(parseMikanSearchResults(page), hasLength(2));

      stubPages({
        searchUrl(nameCn): page,
        // The higher-ranked duplicate is a different subject...
        bangumiPageUrl(1): bangumiPageLinking(500002),
        // ...and the lower-ranked card is the real one.
        bangumiPageUrl(9): bangumiPageLinking(_subjectId),
      });

      final result = await locator.resolveBangumiId(
        subjectId: _subjectId,
        nameCn: nameCn,
      );

      expect(result.outcome, MikanLocateOutcome.found);
      expect(result.bangumiId, 9);
      expect(requestedUrls(), [
        searchUrl(nameCn),
        bangumiPageUrl(1),
        bangumiPageUrl(9),
      ]);
    });

    test('verifies at most the top 3 cards, then gives up', () async {
      const nameCn = '目标番剧';
      // Similarity against `nameCn` strictly decreases down this list, so
      // the only back-linking card (15) is ranked last and falls outside
      // the cap.
      final page = searchPageWith([
        searchCardAnchor(11, nameCn),
        searchCardAnchor(12, '${nameCn}2'),
        searchCardAnchor(13, '${nameCn}XY'),
        searchCardAnchor(14, '${nameCn}XYZW'),
        searchCardAnchor(15, '${nameCn}XYZWVU'),
      ]);

      stubPages({
        searchUrl(nameCn): page,
        bangumiPageUrl(11): bangumiPageLinking(500011),
        bangumiPageUrl(12): bangumiPageLinking(500012),
        bangumiPageUrl(13): bangumiPageLinking(500013),
        bangumiPageUrl(14): bangumiPageLinking(500014),
        bangumiPageUrl(15): bangumiPageLinking(_subjectId),
      });

      final result = await locator.resolveBangumiId(
        subjectId: _subjectId,
        nameCn: nameCn,
      );

      expect(result.outcome, MikanLocateOutcome.absent);
      // 1 search + exactly 3 verifications: cards 14 and 15 are never
      // fetched even though 15 would have matched.
      expect(requestedUrls(), [
        searchUrl(nameCn),
        bangumiPageUrl(11),
        bangumiPageUrl(12),
        bangumiPageUrl(13),
      ]);
    });

    test('stops at the first keyword that returns cards instead of widening '
        'to the next candidate', () async {
      const nameCn = '某番剧～副标题～';
      expect(mikanSearchCandidates(nameCn: nameCn), ['某番剧', nameCn]);

      stubPages({
        // The truncated keyword finds a wrong subject...
        searchUrl('某番剧'): searchPageWith([searchCardAnchor(21, '某番剧')]),
        bangumiPageUrl(21): bangumiPageLinking(500021),
        // ...and the raw name would have found the right one, but that
        // search must never be issued (design doc: 第一个返回卡片的即停).
        searchUrl(nameCn): searchPageWith([searchCardAnchor(22, nameCn)]),
        bangumiPageUrl(22): bangumiPageLinking(_subjectId),
      });

      final result = await locator.resolveBangumiId(
        subjectId: _subjectId,
        nameCn: nameCn,
      );

      expect(result.outcome, MikanLocateOutcome.absent);
      expect(requestedUrls(), [searchUrl('某番剧'), bangumiPageUrl(21)]);
    });

    test('does not accept a subject id that only appears outside an '
        'anchor href', () async {
      stubPages({
        searchUrl('恶女不才，请多关照'): searchPage,
        // The page's only real back-link points somewhere else; the
        // requested id is present, but merely inside an HTML comment.
        bangumiPageUrl(_bangumiId):
            '<!DOCTYPE html><html><body>'
            '<!-- previously https://bgm.tv/subject/$_subjectId -->'
            '<p class="bangumi-info"><a class="w-other-c" '
            'href="https://bgm.tv/subject/999999">x</a></p>'
            '</body></html>',
        bangumiPageUrl(_decoyBangumiId): bangumiPage3999,
      });

      final result = await locator.resolveBangumiId(
        subjectId: _subjectId,
        nameCn: _nameCn,
      );

      expect(result.outcome, MikanLocateOutcome.absent);
      expect(result.bangumiId, isNull);
    });
  });
}
