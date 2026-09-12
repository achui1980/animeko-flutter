import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;

import '../../domain/media/title_matcher.dart';

/// One 条目 (subject) card parsed off a Mikan `/Home/Search` result page.
/// [title] is Mikan's OWN subject title, which (unlike the torrent titles in
/// an RSS feed) carries the full name including any `～…～` suffix.
class MikanSubjectCard {
  const MikanSubjectCard({required this.bangumiId, required this.title});

  final int bangumiId;
  final String title;
}

const _defaultSubjectSearchUrl =
    'https://mikanani.me/Home/Search?searchstr={keyword}';
const _defaultBangumiPageUrl = 'https://mikanani.me/Home/Bangumi/{bangumiId}';

/// How many of the highest-ranked cards get a back-link verification
/// request. Mikan's 条目 search returns whole series families (all seasons,
/// movies, ...), so the correct one is essentially always in the top few;
/// this bounds the per-keyword first-visit request cost at 1 search + 3
/// verifications. Overall the worst case is 3 searches + 3 verifications
/// (= 6 requests): the verification budget is only spent on the first
/// keyword candidate that returns any cards, and every earlier candidate
/// costs one search each.
const _maxVerifiedCards = 3;

final _bangumiHrefPattern = RegExp(r'^/Home/Bangumi/(\d+)');

/// A `bgm.tv` subject back-link href, e.g. `https://bgm.tv/subject/545008`.
final _bgmSubjectHrefPattern = RegExp(r'bgm\.tv/subject/(\d+)');

/// Parses the 条目 cards out of a Mikan `/Home/Search` page body.
///
/// Card shape (verified live 2026-09-11, see design doc): an
/// `a[href^="/Home/Bangumi/<id>"]` wrapping a `div.an-text` whose `title`
/// attribute holds Mikan's own subject title. Cards without a usable id or
/// title are skipped, and repeated ids are de-duplicated, so a markup
/// change degrades to "no cards" (→ keyword-search fallback) instead of
/// throwing.
List<MikanSubjectCard> parseMikanSearchResults(String body) {
  final document = html_parser.parse(body);
  final cards = <MikanSubjectCard>[];
  final seenIds = <int>{};

  for (final link in document.querySelectorAll('a[href^="/Home/Bangumi/"]')) {
    final href = link.attributes['href'];
    if (href == null) continue;
    final match = _bangumiHrefPattern.firstMatch(href);
    if (match == null) continue;
    final bangumiId = int.tryParse(match.group(1)!);
    if (bangumiId == null) continue;
    final title = link
        .querySelector('div.an-text')
        ?.attributes['title']
        ?.trim();
    if (title == null || title.isEmpty) continue;
    if (!seenIds.add(bangumiId)) continue;
    cards.add(MikanSubjectCard(bangumiId: bangumiId, title: title));
  }

  return cards;
}

/// Where a title's "core" name ends: Mikan's search ANDs space-separated
/// substrings against *torrent* titles, so a decorated suffix such as
/// `～雏宫蝶鼠换身传～` filters out every release that omits it.
final _keywordCutPattern = RegExp(r'[～~（(]');

/// The search keywords to try, in order: the truncated Chinese name, the
/// truncated Japanese name (Mikan indexes those too), then the raw Chinese
/// name as a last resort. Blank and duplicate candidates are dropped, so a
/// name with nothing to truncate yields a single candidate and a single
/// request.
List<String> mikanSearchCandidates({required String nameCn, String? nameJp}) {
  final candidates = <String>[];

  void add(String? raw) {
    if (raw == null) return;
    final value = raw.trim();
    if (value.isEmpty || candidates.contains(value)) return;
    candidates.add(value);
  }

  add(_truncateAtDecoration(nameCn));
  if (nameJp != null) add(_truncateAtDecoration(nameJp));
  add(nameCn);

  return candidates;
}

String _truncateAtDecoration(String name) {
  final match = _keywordCutPattern.firstMatch(name);
  if (match == null) return name.trim();
  return name.substring(0, match.start).trim();
}

/// Whether a [MikanSubjectLocator.resolveBangumiId] answer is safe to cache.
///
/// The distinction exists because `RssMediaSource` persists a `null` mapping
/// as "confirmed absent from Mikan" and honours it for
/// `MikanSubjectMappingRepository.negativeTtl` (7 days). Collapsing a
/// transient network failure into that negative answer would pin the subject
/// to the lossy keyword search for a week, with no recovery path (nothing
/// ever deletes a mapping row).
enum MikanLocateOutcome {
  /// A card's Mikan page carries the requested `bgm.tv/subject/<id>`
  /// back-link. Cacheable permanently.
  found,

  /// Every step was answered and none matched: the subject really is not on
  /// Mikan (yet). Cacheable under the negative TTL.
  absent,

  /// At least one step could not be answered (request failed / body
  /// unusable), so "not found" carries no information. Must NOT be cached.
  undetermined,
}

/// The result of one subject resolution attempt.
///
/// [bangumiId] is non-null only for [MikanLocateOutcome.found]; both other
/// outcomes mean "use the keyword search for this call".
class MikanLocateResult {
  const MikanLocateResult(this.outcome, [this.bangumiId])
    : assert(
        (outcome == MikanLocateOutcome.found) == (bangumiId != null),
        'a bangumiId is exactly the `found` outcome',
      );

  final MikanLocateOutcome outcome;
  final int? bangumiId;
}

/// `DioException` types that mean "the transport never reached the server".
///
/// They cannot be keyword-specific, so once one happens every remaining
/// keyword candidate is guaranteed to fail the same way -- each after a full
/// 10s timeout (see `mikanRssDio`). Every other type (notably
/// [DioExceptionType.badResponse]) leaves open the possibility that a
/// different keyword answers.
const _hostLevelFailures = {
  DioExceptionType.connectionTimeout,
  DioExceptionType.connectionError,
  DioExceptionType.receiveTimeout,
  DioExceptionType.sendTimeout,
};

/// The outcome of one `/Home/Search` request.
///
/// [cards] is non-null exactly when the page was both fetched and parsed, so
/// an empty list means "answered, and there genuinely are no cards" -- the
/// only version of "no cards" that may be negative-cached. When it is null,
/// [hostUnreachable] says which kind of failure happened: see
/// [_hostLevelFailures].
class _SearchAttempt {
  const _SearchAttempt.answered(List<MikanSubjectCard> this.cards)
    : hostUnreachable = false;

  const _SearchAttempt.keywordFailed() : cards = null, hostUnreachable = false;

  const _SearchAttempt.hostUnreachable() : cards = null, hostUnreachable = true;

  final List<MikanSubjectCard>? cards;
  final bool hostUnreachable;
}

/// Resolves a Bangumi `subjectId` to Mikan's own `bangumiId`, so the caller
/// can fetch that subject's complete per-bangumi RSS feed instead of a
/// keyword search (which silently drops whole subtitle groups -- see design
/// doc).
///
/// Never throws and never returns a guess: the winning card must carry a
/// `bgm.tv/subject/<subjectId>` back-link on its own Mikan page. Title
/// similarity is only used to decide the *order* in which candidates get
/// verified, because the result is cached long-term and a wrong mapping
/// (e.g. a different season of the same series) would be expensive.
class MikanSubjectLocator {
  MikanSubjectLocator(
    this._dio, {
    this.searchUrlTemplate = _defaultSubjectSearchUrl,
    this.bangumiPageUrlTemplate = _defaultBangumiPageUrl,
  });

  final Dio _dio;

  /// Template with a `{keyword}` placeholder.
  final String searchUrlTemplate;

  /// Template with a `{bangumiId}` placeholder.
  final String bangumiPageUrlTemplate;

  Future<MikanLocateResult> resolveBangumiId({
    required int subjectId,
    required String nameCn,
    String? nameJp,
  }) async {
    // Sticky for the whole resolution: once any single step went
    // unanswered, "nothing matched" is no longer evidence of absence, so
    // the caller must not negative-cache it.
    var sawUndetermined = false;

    for (final keyword in mikanSearchCandidates(
      nameCn: nameCn,
      nameJp: nameJp,
    )) {
      final attempt = await _searchCards(keyword);
      final cards = attempt.cards;
      if (cards == null) {
        // The flag is what stops the missing answer from being silently
        // collapsed into "absent"; what to do *next* depends on why the
        // search failed.
        sawUndetermined = true;
        if (attempt.hostUnreachable) {
          // Every candidate hits the same host, so the remaining ones would
          // each burn a full 10s timeout to learn nothing. Trading them away
          // costs only the (unlikely) case where the host recovers within
          // this very resolution; the outcome is `undetermined` either way,
          // so the next visit retries from scratch.
          break;
        }
        // A non-2xx or an unparseable body can genuinely be
        // keyword-specific, so a later candidate may still reach a
        // conclusive `found` -- worth one more request.
        continue;
      }
      if (cards.isEmpty) continue;

      final ranked = [...cards]
        ..sort(
          (a, b) => titleSimilarity(
            b.title,
            nameCn,
          ).compareTo(titleSimilarity(a.title, nameCn)),
        );

      for (final card in ranked.take(_maxVerifiedCards)) {
        final verified = await _hasBackLink(
          bangumiId: card.bangumiId,
          subjectId: subjectId,
        );
        if (verified == true) {
          return MikanLocateResult(MikanLocateOutcome.found, card.bangumiId);
        }
        if (verified == null) sawUndetermined = true;
      }

      // This keyword *did* return cards, they just were not this subject.
      // Retrying a broader keyword would only widen an already-wrong
      // result set, so stop here (design doc: 第一个返回卡片的即停).
      return _noMatch(sawUndetermined);
    }
    return _noMatch(sawUndetermined);
  }

  MikanLocateResult _noMatch(bool sawUndetermined) => MikanLocateResult(
    sawUndetermined
        ? MikanLocateOutcome.undetermined
        : MikanLocateOutcome.absent,
  );

  /// The page's 条目 cards, or -- when the page could not be fetched or
  /// parsed at all -- which kind of failure got in the way. See
  /// [_SearchAttempt].
  Future<_SearchAttempt> _searchCards(String keyword) async {
    try {
      final url = searchUrlTemplate.replaceAll(
        '{keyword}',
        Uri.encodeQueryComponent(keyword),
      );
      final response = await _dio.get<String>(
        url,
        options: Options(responseType: ResponseType.plain),
      );
      return _SearchAttempt.answered(
        parseMikanSearchResults(response.data ?? ''),
      );
    } on DioException catch (e) {
      // Either way the caller falls back to keyword search for *this* call
      // without recording a negative mapping (design doc "错误处理"); the
      // type only decides whether the next candidate is worth trying.
      return _hostLevelFailures.contains(e.type)
          ? const _SearchAttempt.hostUnreachable()
          : const _SearchAttempt.keywordFailed();
    } catch (_) {
      // Unparseable HTML, and -- mandatory, since `on DioException` does not
      // cover them -- any `Error` or other non-`Exception` throwable:
      // `resolveBangumiId` runs inside a `Future.wait` and must never throw.
      return const _SearchAttempt.keywordFailed();
    }
  }

  /// Whether [bangumiId]'s Mikan page back-links [subjectId], or `null` when
  /// that page could not be fetched or parsed. `false` therefore means "this
  /// page conclusively names some other subject".
  Future<bool?> _hasBackLink({
    required int bangumiId,
    required int subjectId,
  }) async {
    try {
      final url = bangumiPageUrlTemplate.replaceAll(
        '{bangumiId}',
        '$bangumiId',
      );
      final response = await _dio.get<String>(
        url,
        options: Options(responseType: ResponseType.plain),
      );
      // Only a real anchor counts: a bare `bgm.tv/subject/<id>` string
      // anywhere else on the page (HTML comment, script payload, prose)
      // must not pass, because a wrong mapping is cached long-term.
      final document = html_parser.parse(response.data ?? '');
      for (final link in document.querySelectorAll(
        'a[href*="bgm.tv/subject/"]',
      )) {
        final id = _bgmSubjectHrefPattern
            .firstMatch(link.attributes['href'] ?? '')
            ?.group(1);
        // Comparing parsed ints stops `.../subject/5450089` from
        // satisfying a request for 545008, and is overflow-safe.
        if (id != null && int.tryParse(id) == subjectId) return true;
      }
      return false;
    } catch (_) {
      return null;
    }
  }
}
