/// A parsed episode number or inclusive range, e.g. "10" or "07-10".
class EpisodeRange {
  const EpisodeRange.single(int value) : start = value, end = value;

  const EpisodeRange.range(this.start, this.end);

  final int start;
  final int end;

  bool contains(int value) => value >= start && value <= end;

  Iterable<int> expand() =>
      List<int>.generate(end - start + 1, (i) => start + i);

  @override
  String toString() => start == end ? '$start' : '$start-$end';
}

/// The result of parsing a single BT release title (e.g. an RSS `<item><title>`).
class ParsedTitle {
  const ParsedTitle({
    this.episodeRange,
    this.resolution,
    required this.alliance,
    this.subtitleLanguages = const [],
  });

  final EpisodeRange? episodeRange;
  final String? resolution;
  final String alliance;
  final List<String> subtitleLanguages;
}

const _resolutionNumbers = {360, 480, 720, 848, 1080, 1440, 1920, 2160};

final _bracketPattern = RegExp(r'\[(.+?)\]|【(.+?)】');
final _rangeWordPattern = RegExp(r'^(\d{1,4})\s*[-~～]{1,2}\s*(\d{1,4})$');
final _singleEpisodeWordPattern = RegExp(r'^\d{1,4}$');
final _resolutionXPattern = RegExp(r'(\d{3,4})[xX](\d{3,4})');
final _resolutionPPattern = RegExp(r'(\d{3,4})[Pp]\b');

const _languageKeywords = <String, List<String>>{
  '繁体': ['繁体', '繁中', 'BIG5', 'CHT', 'TC', '繁'],
  '简体': ['简体', '简中', 'GB', 'CHS', '简', '中文', '中字'],
  '粤语': ['粤语', '粤', '粵', 'Cantonese', 'CHC'],
  '日语': ['日语', '日文', 'JPN'],
  '英语': ['英语', '英文', 'ENG'],
};

/// Parses a raw BT release title into episode/resolution/alliance/language
/// metadata. Mirrors (a small, project-scoped subset of) upstream Animeko's
/// `LabelFirstRawTitleParser`. Returns `episodeRange: null` when no episode
/// number could be confidently extracted (the caller should discard such
/// items, matching upstream behavior).
ParsedTitle parseTitle(String rawTitle) {
  final words = _splitWords(rawTitle);

  EpisodeRange? episodeRange;
  String? resolution;
  final subtitleLanguages = <String>[];

  for (final word in words) {
    resolution ??= _tryParseResolution(word);
    episodeRange ??= _tryParseEpisode(word);
    for (final entry in _languageKeywords.entries) {
      if (subtitleLanguages.contains(entry.key)) continue;
      if (entry.value.any((kw) => _matchesLanguageKeyword(word, kw))) {
        subtitleLanguages.add(entry.key);
      }
    }
  }

  return ParsedTitle(
    episodeRange: episodeRange,
    resolution: resolution,
    alliance: _extractAlliance(rawTitle),
    subtitleLanguages: subtitleLanguages,
  );
}

List<String> _splitWords(String title) {
  final words = <String>[];
  var lastEnd = 0;
  for (final match in _bracketPattern.allMatches(title)) {
    if (match.start > lastEnd) {
      words.addAll(_splitPlain(title.substring(lastEnd, match.start)));
    }
    final content = match.group(1) ?? match.group(2) ?? '';
    words.add(content);
    lastEnd = match.end;
  }
  if (lastEnd < title.length) {
    words.addAll(_splitPlain(title.substring(lastEnd)));
  }
  return words;
}

List<String> _splitPlain(String text) => text
    .split(RegExp(r'[/\\|\s]+'))
    .map((w) => w.trim())
    .where((w) => w.isNotEmpty)
    .toList();

String? _tryParseResolution(String word) {
  final xMatch = _resolutionXPattern.firstMatch(word);
  if (xMatch != null) {
    final height = int.tryParse(xMatch.group(2)!);
    if (height != null && _resolutionNumbers.contains(height)) {
      return '${height}P';
    }
  }
  final pMatch = _resolutionPPattern.firstMatch(word);
  if (pMatch != null) {
    final value = int.tryParse(pMatch.group(1)!);
    if (value != null && _resolutionNumbers.contains(value)) {
      return '${value}P';
    }
  }
  return null;
}

EpisodeRange? _tryParseEpisode(String rawWord) {
  final word = rawWord.startsWith('-') ? rawWord.substring(1).trim() : rawWord;
  if (word.isEmpty) return null;

  final rangeMatch = _rangeWordPattern.firstMatch(word);
  if (rangeMatch != null) {
    final start = int.tryParse(rangeMatch.group(1)!);
    final end = int.tryParse(rangeMatch.group(2)!);
    if (start != null &&
        end != null &&
        !_resolutionNumbers.contains(start) &&
        !_resolutionNumbers.contains(end)) {
      return EpisodeRange.range(start, end);
    }
    return null;
  }

  if (_singleEpisodeWordPattern.hasMatch(word)) {
    final value = int.tryParse(word);
    if (value != null && !_resolutionNumbers.contains(value)) {
      return EpisodeRange.single(value);
    }
  }
  return null;
}

/// Matches a subtitle-language keyword against a word.
///
/// Short, purely-alphanumeric keywords (e.g. "GB", "TC") are matched as
/// whole words only, to avoid false positives against unrelated tokens
/// that merely contain those letters (e.g. a file-size tag like "1.52GB",
/// which would otherwise wrongly be tagged as Simplified Chinese).
/// CJK keywords are matched as substrings, since CJK text has no
/// comparable "word boundary" concept and multi-character CJK keywords
/// are not prone to the same kind of accidental substring collision.
bool _matchesLanguageKeyword(String word, String keyword) {
  if (RegExp(r'^[A-Za-z0-9]+$').hasMatch(keyword)) {
    return RegExp(
      r'\b' + RegExp.escape(keyword) + r'\b',
      caseSensitive: false,
    ).hasMatch(word);
  }
  return word.contains(keyword);
}

String _extractAlliance(String rawTitle) {
  final trimmed = rawTitle.trim();
  final idx = _firstIndexOfAny(trimmed, [']', '】']);
  if (idx < 0) return '';
  var alliance = trimmed.substring(0, idx);
  alliance = alliance.replaceFirst('[', '').replaceFirst('【', '');
  return alliance.trim();
}

int _firstIndexOfAny(String text, List<String> needles) {
  for (var i = 0; i < text.length; i++) {
    for (final needle in needles) {
      if (text.startsWith(needle, i)) return i;
    }
  }
  return -1;
}
