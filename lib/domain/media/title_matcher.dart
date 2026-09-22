// lib/domain/media/title_matcher.dart
import 'media_source.dart';

/// Minimum similarity score (see [_bestSimilarity]) for a candidate to be
/// considered a match. This is an initial guess, not tuned against real
/// site data -- adjust during manual verification if it produces too
/// many false positives/negatives (see design doc "测试策略").
const matchThreshold = 0.6;

/// Picks the best-matching candidate for [subjectName] out of
/// [candidates], or `null` if none scores at or above [matchThreshold].
/// Pure function, directly testable with no mocking. Generic over any
/// concrete [MediaCandidate] subtype so both anime1.me and 稀饭动漫 (and
/// any future source) share this exact same logic.
///
/// Before scoring, candidates whose *series identity* conflicts with
/// [subjectName]'s are discarded outright (see [_SeriesIdentity]).
/// Similarity alone cannot tell "第四季 夺还篇" from "第四季 丧失篇" --
/// those differ by two characters out of nineteen, so every scoring
/// function rates them as a near-perfect match, and a site that carries
/// only the other cour would otherwise serve the wrong episodes.
T? matchBest<T extends MediaCandidate>(List<T> candidates, String subjectName) {
  final normalizedTarget = _normalize(subjectName);
  final targetIdentity = _SeriesIdentity.parse(normalizedTarget);
  T? best;
  var bestScore = 0.0;
  for (final candidate in candidates) {
    final normalizedCandidate = _normalize(candidate.title);
    if (targetIdentity.conflictsWith(
      _SeriesIdentity.parse(normalizedCandidate),
    )) {
      continue;
    }
    final score = _bestSimilarity(normalizedCandidate, normalizedTarget);
    if (score > bestScore) {
      bestScore = score;
      best = candidate;
    }
  }
  return bestScore >= matchThreshold ? best : null;
}

/// Which entry of a series a title refers to: its season number and any
/// story-arc ("cour") markers. Used purely as a veto in [matchBest] --
/// two titles with conflicting identities are never the same entry, no
/// matter how similar their strings are.
class _SeriesIdentity {
  const _SeriesIdentity({required this.season, required this.arcs});

  /// Season number, defaulting to 1 when the title carries no season
  /// marker at all: a bare base title *is* the first season, which is
  /// what makes "葬送的芙莉蓮" vs "葬送的芙莉蓮 第二季" a conflict.
  final int season;

  /// Story-arc names stripped of their trailing 篇, e.g. `{'夺還'}` for
  /// "第四季 夺還篇". Empty when the title names no arc.
  final Set<String> arcs;

  static _SeriesIdentity parse(String normalized) => _SeriesIdentity(
    season: _parseSeason(normalized),
    arcs: _arcPattern.allMatches(normalized).map((m) => m.group(1)!).toSet(),
  );

  /// Conflicts when the seasons differ, or when both sides name arcs and
  /// share none of them. A one-sided arc marker is deliberately *not* a
  /// conflict: sources routinely omit an arc name the Bangumi title
  /// carries (and vice versa), and dropping those candidates would lose
  /// real matches -- the cost is that "葬送的芙莉蓮 特別篇" still
  /// competes for "葬送的芙莉蓮".
  bool conflictsWith(_SeriesIdentity other) {
    if (season != other.season) return true;
    if (arcs.isEmpty || other.arcs.isEmpty) return false;
    return arcs.intersection(other.arcs).isEmpty;
  }
}

/// Season markers this recognizes: "第4季"/"第四期"/"第2部",
/// "season2" and "2ndseason" (whitespace is already stripped by
/// [_normalize]).
///
/// Bare trailing numerals ("... 2") and Roman numerals ("... Ⅱ") are
/// deliberately *not* recognized: a trailing digit is often part of the
/// name itself ("Fate/Zero 2" style), and treating it as a season would
/// produce false vetoes -- the failure mode this whole veto exists to
/// prevent, just in the other direction.
final RegExp _seasonPattern = RegExp(
  r'第([0-9一二三四五六七八九十]{1,3})[季期部]'
  r'|season([0-9]{1,2})'
  r'|([0-9]{1,2})(?:st|nd|rd|th)season',
);

const _chineseNumerals = <String, int>{
  '一': 1,
  '二': 2,
  '三': 3,
  '四': 4,
  '五': 5,
  '六': 6,
  '七': 7,
  '八': 8,
  '九': 9,
  '十': 10,
};

int _parseSeason(String normalized) {
  final match = _seasonPattern.firstMatch(normalized);
  if (match == null) return 1;
  final raw = match.group(1) ?? match.group(2) ?? match.group(3)!;
  final arabic = int.tryParse(raw);
  if (arabic != null) return arabic;
  if (raw.length == 1) return _chineseNumerals[raw] ?? 1;
  // "十一".."十九"
  if (raw.startsWith('十')) {
    return 10 + (_chineseNumerals[raw.substring(1, 2)] ?? 0);
  }
  return _chineseNumerals[raw.substring(0, 1)] ?? 1;
}

/// A story-arc name: up to four CJK characters followed by 篇, stopping
/// at 季/期/部 so that "第四季夺還篇" yields "夺還" rather than "四季夺還".
final RegExp _arcPattern = RegExp(r'((?:(?![季期部])[\u4e00-\u9fa5]){1,4})篇');

/// A small, deliberately non-exhaustive map of common Simplified Chinese
/// characters to their Traditional Chinese counterpart. Bangumi titles
/// are often Simplified while some sources' titles (e.g. anime1.me) are
/// Traditional (see e.g. "恶女不才..." vs. "我是不才惡女"); without this,
/// such pairs never share any characters and always score 0.
///
/// This is *not* a full canonical Simplified/Traditional conversion
/// table (those run into the thousands of entries and hand-transcribing
/// one from memory risks silent inaccuracies) -- it only covers a
/// modest set of very common characters likely to appear in anime
/// titles. Characters not in this map (in either direction) pass
/// through unchanged, so this can only ever help a match, never hurt
/// one that already worked.
const _simplifiedToTraditional = <String, String>{
  '国': '國',
  '这': '這',
  '时': '時',
  '后': '後',
  '会': '會',
  '经': '經',
  '还': '還',
  '没': '沒',
  '么': '麼',
  '着': '著',
  '许': '許',
  '义': '義',
  '动': '動',
  '汉': '漢',
  '机': '機',
  '开': '開',
  '关': '關',
  '门': '門',
  '习': '習',
  '书': '書',
  '学': '學',
  '觉': '覺',
  '爱': '愛',
  '亲': '親',
  '见': '見',
  '闻': '聞',
  '语': '語',
  '话': '話',
  '气': '氣',
  '风': '風',
  '飞': '飛',
  '坏': '壞',
  '怀': '懷',
  '恶': '惡',
  '说': '說',
  '读': '讀',
  '写': '寫',
  '让': '讓',
  '应': '應',
  '该': '該',
  '战': '戰',
  '师': '師',
  '问': '問',
  '乐': '樂',
  '过': '過',
  '连': '連',
  '选': '選',
  '择': '擇',
  '现': '現',
  '实': '實',
  '处': '處',
  '备': '備',
  '决': '決',
  '剧': '劇',
  '观': '觀',
  '欢': '歡',
  '声': '聲',
  '对': '對',
  '导': '導',
  '带': '帶',
  '张': '張',
  '强': '強',
  '无': '無',
  '来': '來',
  '样': '樣',
  '点': '點',
  '满': '滿',
  '灭': '滅',
  '灵': '靈',
  '产': '產',
  '电': '電',
  '种': '種',
  '类': '類',
  '纪': '紀',
  '纯': '純',
  '组': '組',
  '织': '織',
  '终': '終',
  '统': '統',
  '维': '維',
  '综': '綜',
  '绿': '綠',
  '网': '網',
  '职': '職',
  '联': '聯',
  '胜': '勝',
  '舰': '艦',
  '苏': '蘇',
  '获': '獲',
  '营': '營',
  '蓝': '藍',
  '虽': '雖',
  '虚': '虛',
  '补': '補',
  '装': '裝',
  '计': '計',
  '认': '認',
  '议': '議',
  '记': '記',
  '讲': '講',
  '论': '論',
  '设': '設',
  '证': '證',
  '评': '評',
  '识': '識',
  '诉': '訴',
  '词': '詞',
  '诚': '誠',
  '误': '誤',
  '请': '請',
  '课': '課',
  '谁': '誰',
  '调': '調',
  '谈': '談',
  '谋': '謀',
  '谎': '謊',
  '谢': '謝',
  '谣': '謠',
  '购': '購',
  '贵': '貴',
  '贸': '貿',
  '费': '費',
  '资': '資',
  '质': '質',
  '财': '財',
  '败': '敗',
  '车': '車',
  '轻': '輕',
  '转': '轉',
  '输': '輸',
  '达': '達',
  '运': '運',
  '远': '遠',
  '进': '進',
  '适': '適',
  '边': '邊',
  '钢': '鋼',
  '铁': '鐵',
  '银': '銀',
  '键': '鍵',
  '锁': '鎖',
  '长': '長',
  '间': '間',
  '闷': '悶',
  '阳': '陽',
  '阴': '陰',
  '际': '際',
  '险': '險',
  '陆': '陸',
  '飘': '飄',
};

/// Lowercases, strips whitespace, converts full-width Latin
/// letters/digits/punctuation (U+FF01-FF5E) to their half-width
/// equivalents (so e.g. "ＡＴＴＡＣＫ" and "Attack" compare equal), and
/// maps known Simplified Chinese characters to Traditional Chinese via
/// [_simplifiedToTraditional].
String _normalize(String input) {
  final withoutWhitespace = input
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), '')
      .replaceAllMapped(
        RegExp(r'[\uFF01-\uFF5E]'),
        (m) => String.fromCharCode(m.group(0)!.codeUnitAt(0) - 0xFEE0),
      );
  final buffer = StringBuffer();
  for (final char in withoutWhitespace.split('')) {
    buffer.write(_simplifiedToTraditional[char] ?? char);
  }
  return buffer.toString();
}

/// Punctuation/decoration commonly used to separate a title's "core" name
/// from extra subtitle/season text (e.g. "OOO：Alt Title", "OOO 〇Sub〇").
/// Splitting on these lets a short core title match against a much
/// longer one even when word order differs and plain containment fails
/// (see [_bestSimilarity]).
final RegExp _segmentDelimiters = RegExp(
  '[，,、:：\\-\u2014~\uFF5E\u301C()\uFF08\uFF09\u3010\u3011\u300C\u300D'
  '\u3008\u3009\u3014\u3015\u3007\u25CB\u30FB]+',
);

/// Derived segments shorter than this are dropped. A two-character
/// fragment like the "Re" of "Re：从零开始的异世界生活" carries no
/// identifying information, yet [titleSimilarity] scores it 1.0 against
/// any other title with the same prefix -- which used to make every
/// "Re：..." series a perfect match for every other one.
const _minSegmentLength = 3;

/// The full [normalized] string plus each piece produced by splitting on
/// [_segmentDelimiters] that is at least [_minSegmentLength] runes long.
/// The whole string is always included regardless of length, so callers
/// never lose the plain whole-title comparison.
Set<String> _segments(String normalized) {
  final parts = normalized
      .split(_segmentDelimiters)
      .map((s) => s.trim())
      .where((s) => s.runes.length >= _minSegmentLength);
  return {normalized, ...parts};
}

/// The highest [titleSimilarity] score across every combination of [a]'s
/// and [b]'s [_segments]. This lets a title's short "core" name match a
/// candidate even when one side carries extra subtitle text that would
/// otherwise dilute a whole-string character-overlap score below
/// [matchThreshold] (see design doc's follow-up note on word-order and
/// subtitle mismatches).
double _bestSimilarity(String a, String b) {
  var best = 0.0;
  for (final segmentA in _segments(a)) {
    for (final segmentB in _segments(b)) {
      final score = titleSimilarity(segmentA, segmentB);
      if (score > best) best = score;
    }
  }
  return best;
}

/// Deliberately simple, non-academic similarity score in `[0, 1]`:
/// containment (one string fully contains the other) scores by
/// length-ratio, otherwise falls back to a character-set overlap ratio.
/// Empty input always scores 0, even when both sides are empty -- the
/// empty guard runs ahead of the identity check, so the "identical
/// strings score 1" invariant does not extend to `('', '')`.
/// See design doc "标题匹配策略" for why Levenshtein/Jaro-Winkler are
/// deliberately not used here.
///
/// Public rather than library-private, so callers that rank plain
/// `(id, title)` pairs instead of [MediaCandidate]s can reuse the
/// exact same scoring -- see `MikanSubjectLocator`, which ranks Mikan
/// 条目 search cards. Callers that only need to pick the best
/// [MediaCandidate] should keep using [matchBest]: unlike this function,
/// it also normalizes (case/width/Simplified-vs-Traditional) and
/// segment-splits both sides first.
double titleSimilarity(String a, String b) {
  if (a.isEmpty || b.isEmpty) return 0;
  if (a == b) return 1;
  if (a.contains(b) || b.contains(a)) {
    final shorter = a.length <= b.length ? a : b;
    final longer = a.length <= b.length ? b : a;
    return shorter.length / longer.length;
  }
  final setA = a.runes.toSet();
  final setB = b.runes.toSet();
  final union = setA.union(setB).length;
  if (union == 0) return 0;
  return setA.intersection(setB).length / union;
}
