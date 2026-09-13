// lib/ui/subject/subject_meta_text.dart

import '../../data/subject/subject_episode_models.dart';

/// Pure text helpers for the subject detail page's meta line
/// (`2026年7月 · 连载至 09 · 预定全 11 话` — design doc
/// `2026-09-12-subject-detail-three-column-layout-design.md`, the UI
/// wireframe at line 29 and the conversion rules at lines 322-326).
///
/// Note the 年月 segment is unspaced (`2026年7月`, the string literal at
/// design doc line 322 and the wireframe at line 29). The spaced
/// `2026 年 7 月` on prose lines 320/322 is that document's Latin/CJK
/// prose spacing, not a rendering requirement.
///
/// Deliberately free of `package:flutter` imports so these can be unit
/// tested without widget scaffolding, and so the middle column's title
/// block and the 选集 section header can share one implementation of the
/// 「连载至 NN · 预定全 NN 话」 text instead of each rolling their own
/// (design doc line 326 requires the two to use the same function).

/// `2026-07-12` -> `2026年7月`, the first segment of the meta line
/// (design doc line 322).
///
/// Returns null when [airDate] cannot be parsed — including the empty
/// string — so the caller can omit the whole segment rather than render a
/// stray ` · ` separator (design doc line 322: 「解析失败则整段省略」).
/// Mirrors the existing private `_formatAirDateYearMonth` in
/// `subject_detail_screen.dart`, which this will replace when that
/// screen is rewritten (the private copy is still live until then).
String? formatAirDateYearMonth(String airDate) {
  final date = DateTime.tryParse(airDate);
  if (date == null) return null;
  return '${date.year}年${date.month}月';
}

/// Renders an episode `sort` for display: `3` stays `3` rather than `3.0`.
///
/// [SubjectEpisode.sort] is typed `num` (the wire stringifies it and
/// `subject_episode_models.dart` coerces it with `num.tryParse`), so a
/// non-integer value such as a `3.5` half-episode is representable; this
/// keeps the decimal part in that case.
String formatEpisodeNumber(num sort) {
  if (sort % 1 == 0) return sort.toInt().toString();
  return sort.toString();
}

/// How many of [episodes] have aired as of [now] (defaults to the real
/// current time) — the `连载至 NN` input, defined by the design doc (line
/// 323) as 「主线集数中 `airdate` 不晚于今天的集数」.
///
/// Callers are expected to pass the MAIN-only episode list, since this
/// function counts whatever it is given and has no view of
/// [SubjectEpisode.isMain].
///
/// Truncates [now] to a date so the comparison is date-only; `airdate`
/// carries no time-of-day either, so an episode dated today counts as
/// aired. That same-day inclusion comes from the `!isAfter` (i.e. `<=`)
/// comparison below, not from the truncation — with a date-only
/// `airdate` the truncation is a no-op, and it is kept only so the
/// function stays correct if `airdate` ever gains a time.
/// Episodes whose `airdate` does not parse (it defaults to `''`
/// when the key is absent — see `subject_episode_models.dart`) are
/// skipped rather than guessed at.
int airedEpisodeCount(List<SubjectEpisode> episodes, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final cutoff = DateTime(today.year, today.month, today.day);
  var count = 0;
  for (final episode in episodes) {
    final airdate = DateTime.tryParse(episode.airdate);
    if (airdate == null) continue;
    if (!airdate.isAfter(cutoff)) count += 1;
  }
  return count;
}

/// `连载至 09 · 预定全 11 话`, or a subset, or null when neither segment
/// applies.
///
/// `连载至 NN` is omitted when nothing has aired yet and when everything
/// has already aired — a finished show is not 连载至 (design doc line
/// 323: 「为 0 或全部已放送时省略这一段」).
///
/// `预定全 NN 话` is omitted when [episodeCount] is null (design doc line
/// 324). Pass `SubjectDetail.episodeCount`, which counts MAIN episodes of
/// the embedded `episodes` array and is null when that array is absent
/// (`subject_models.dart`); the response carries no standalone
/// total-episode-count key (see the design doc's top-level key list,
/// line 94).
///
/// [episodes] should be the same MAIN-only list [episodeCount] was
/// derived from — its length is the fallback total when [episodeCount] is
/// null.
String? formatEpisodeProgress({
  required List<SubjectEpisode> episodes,
  required int? episodeCount,
  DateTime? now,
}) {
  final aired = airedEpisodeCount(episodes, now: now);
  final allAired = aired >= (episodeCount ?? episodes.length);
  final parts = <String>[
    if (aired > 0 && !allAired) '连载至 ${aired.toString().padLeft(2, '0')}',
    if (episodeCount != null) '预定全 $episodeCount 话',
  ];
  if (parts.isEmpty) return null;
  return parts.join(' · ');
}

/// The full meta line under the title, segments joined with ` · ` and
/// missing segments leaving no separator behind (design doc line 326).
///
/// Returns `''` when nothing is known, so callers can guard with
/// `isNotEmpty` instead of a null check.
String buildSubjectMetaLine({
  required String airDate,
  required List<SubjectEpisode> episodes,
  required int? episodeCount,
  DateTime? now,
}) {
  final progress = formatEpisodeProgress(
    episodes: episodes,
    episodeCount: episodeCount,
    now: now,
  );
  final parts = <String>[?formatAirDateYearMonth(airDate), ?progress];
  return parts.join(' · ');
}
