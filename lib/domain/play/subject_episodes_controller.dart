// lib/domain/play/subject_episodes_controller.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/anime1/anime1_api.dart';
import '../../data/anime1/anime1_models.dart';

part 'subject_episodes_controller.g.dart';

/// Thrown when no anime1.me category matches the requested subject title
/// with sufficient confidence (see [matchBestCategory]). Not a
/// network/parsing failure -- retrying without changing the title
/// produces the same result, so the UI shows an empty "not found" state
/// instead of a retry button (see `SubjectDetailScreen`).
class Anime1NotFoundException implements Exception {
  const Anime1NotFoundException();

  @override
  String toString() =>
      'Anime1NotFoundException: no matching anime1.me category found';
}

/// Minimum similarity score (see [_similarity]) for a category to be
/// considered a match. This is an initial guess, not tuned against real
/// anime1.me data -- adjust during manual verification if it produces too
/// many false positives/negatives (see design doc "测试策略").
const matchThreshold = 0.6;

/// Picks the best-matching [Anime1Category] for [subjectName] out of
/// [candidates], or `null` if none scores at or above [matchThreshold].
/// Pure function, directly testable with no mocking. Deliberately uses
/// title-string similarity only, with no year/season filtering (see
/// design doc "标题匹配策略").
Anime1Category? matchBestCategory(
  List<Anime1Category> candidates,
  String subjectName,
) {
  final normalizedTarget = _normalize(subjectName);
  Anime1Category? best;
  var bestScore = 0.0;
  for (final candidate in candidates) {
    final score = _bestSimilarity(
      _normalize(candidate.title),
      normalizedTarget,
    );
    if (score > bestScore) {
      bestScore = score;
      best = candidate;
    }
  }
  return bestScore >= matchThreshold ? best : null;
}

/// A small, deliberately non-exhaustive map of common Simplified Chinese
/// characters to their Traditional Chinese counterpart. Bangumi titles
/// are often Simplified while anime1.me's titles are Traditional (see
/// e.g. "恶女不才..." vs. "我是不才惡女"); without this, such pairs never
/// share any characters and always score 0.
///
/// This is *not* a full canonical Simplified/Traditional conversion
/// table (those run into the thousands of entries and hand-transcribing
/// one from memory risks silent inaccuracies) -- it only covers a
/// modest set of very common characters likely to appear in anime
/// titles. Characters not in this map (in either direction) pass
/// through unchanged, so this can only ever help a match, never hurt
/// one that already worked.
const _simplifiedToTraditional = <String, String>{
  '国': '國', '这': '這', '时': '時', '后': '後', '会': '會', '经': '經',
  '还': '還', '没': '沒', '么': '麼', '着': '著', '许': '許', '义': '義',
  '动': '動', '汉': '漢', '机': '機', '开': '開', '关': '關', '门': '門',
  '习': '習', '书': '書', '学': '學', '觉': '覺', '爱': '愛', '亲': '親',
  '见': '見', '闻': '聞', '语': '語', '话': '話', '气': '氣', '风': '風',
  '飞': '飛', '坏': '壞', '怀': '懷', '恶': '惡', '说': '說', '读': '讀',
  '写': '寫', '让': '讓', '应': '應', '该': '該', '战': '戰', '师': '師',
  '问': '問', '乐': '樂', '过': '過', '连': '連', '选': '選', '择': '擇',
  '现': '現', '实': '實', '处': '處', '备': '備', '决': '決', '剧': '劇',
  '观': '觀', '欢': '歡', '声': '聲', '对': '對', '导': '導', '带': '帶',
  '张': '張', '强': '強', '无': '無', '来': '來', '样': '樣', '点': '點',
  '满': '滿', '灭': '滅', '灵': '靈', '产': '產', '电': '電', '种': '種',
  '类': '類', '纪': '紀', '纯': '純', '组': '組', '织': '織', '终': '終',
  '统': '統', '维': '維', '综': '綜', '绿': '綠', '网': '網', '职': '職',
  '联': '聯', '胜': '勝', '舰': '艦', '苏': '蘇', '获': '獲', '营': '營',
  '蓝': '藍', '虽': '雖', '虚': '虛', '补': '補', '装': '裝', '计': '計',
  '认': '認', '议': '議', '记': '記', '讲': '講', '论': '論', '设': '設',
  '证': '證', '评': '評', '识': '識', '诉': '訴', '词': '詞', '诚': '誠',
  '误': '誤', '请': '請', '课': '課', '谁': '誰', '调': '調', '谈': '談',
  '谋': '謀', '谎': '謊', '谢': '謝', '谣': '謠', '购': '購', '贵': '貴',
  '贸': '貿', '费': '費', '资': '資', '质': '質', '财': '財', '败': '敗',
  '车': '車', '轻': '輕', '转': '轉', '输': '輸', '达': '達', '运': '運',
  '远': '遠', '进': '進', '适': '適', '边': '邊', '钢': '鋼', '铁': '鐵',
  '银': '銀', '键': '鍵', '锁': '鎖', '长': '長', '间': '間', '闷': '悶',
  '阳': '陽', '阴': '陰', '际': '際', '险': '險', '陆': '陸', '飘': '飄',
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

/// The full [normalized] string plus each non-empty piece produced by
/// splitting on [_segmentDelimiters] -- always includes the whole string
/// so callers never lose the plain whole-title comparison.
Set<String> _segments(String normalized) {
  final parts = normalized
      .split(_segmentDelimiters)
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty);
  return {normalized, ...parts};
}

/// The highest [_similarity] score across every combination of [a]'s and
/// [b]'s [_segments]. This lets a title's short "core" name match a
/// candidate even when one side carries extra subtitle text that would
/// otherwise dilute a whole-string character-overlap score below
/// [matchThreshold] (see design doc's follow-up note on word-order and
/// subtitle mismatches).
double _bestSimilarity(String a, String b) {
  var best = 0.0;
  for (final segmentA in _segments(a)) {
    for (final segmentB in _segments(b)) {
      final score = _similarity(segmentA, segmentB);
      if (score > best) best = score;
    }
  }
  return best;
}

/// Deliberately simple, non-academic similarity score in `[0, 1]`:
/// containment (one string fully contains the other) scores by
/// length-ratio, otherwise falls back to a character-set overlap ratio.
/// See design doc "标题匹配策略" for why Levenshtein/Jaro-Winkler are
/// deliberately not used here.
double _similarity(String a, String b) {
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

@riverpod
class SubjectEpisodesController extends _$SubjectEpisodesController {
  @override
  Future<List<Anime1Episode>> build({
    required int subjectId,
    required String subjectName,
  }) async {
    final api = ref.watch(anime1ApiProvider);
    final categories = await api.searchCategories(subjectName);
    final best = matchBestCategory(categories, subjectName);
    if (best == null) {
      throw const Anime1NotFoundException();
    }
    return api.fetchCategoryEpisodes(best.id);
  }
}
