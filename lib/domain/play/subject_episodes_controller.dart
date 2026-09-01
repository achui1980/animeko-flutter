// lib/domain/play/subject_episodes_controller.dart
import '../../data/anime1/anime1_models.dart';

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
    final score = _similarity(_normalize(candidate.title), normalizedTarget);
    if (score > bestScore) {
      bestScore = score;
      best = candidate;
    }
  }
  return bestScore >= matchThreshold ? best : null;
}

/// Lowercases, strips whitespace, and converts full-width Latin
/// letters/digits/punctuation (U+FF01-FF5E) to their half-width
/// equivalents, so e.g. "ＡＴＴＡＣＫ" and "Attack" compare equal.
String _normalize(String input) {
  return input
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), '')
      .replaceAllMapped(
        RegExp(r'[\uFF01-\uFF5E]'),
        (m) => String.fromCharCode(m.group(0)!.codeUnitAt(0) - 0xFEE0),
      );
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
