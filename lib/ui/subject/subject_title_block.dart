// lib/ui/subject/subject_title_block.dart

import 'package:flutter/material.dart';

import '../../data/subject/subject_episode_models.dart';
import '../../data/subject/subject_models.dart';
import 'subject_meta_text.dart';

/// The middle column's header: 中文名（大字号）+ 原名（小字号灰）+ meta 行
/// (design doc `2026-09-12-subject-detail-three-column-layout-design.md`
/// line 250, and the wireframe at lines 27-30), e.g.
/// `2026年7月 · 连载至 09 · 预定全 11 话` for the meta line.
///
/// Takes already-resolved data instead of watching providers, so it stays a
/// plain [StatelessWidget] that widget tests can pump without a
/// `ProviderScope`. Its composing parent `subject_detail_main_pane.dart`
/// stacks 标题块 / 简介 / 选集 / 角色 (design doc line 248), so it needs the
/// [SubjectDetail] and the episode list for its other children regardless.
///
/// [now] pins "today" for the 连载至 segment; when omitted,
/// [buildSubjectMetaLine] falls back to the real current time.
class SubjectTitleBlock extends StatelessWidget {
  const SubjectTitleBlock({
    super.key,
    required this.subject,
    required this.episodes,
    this.now,
  });

  final SubjectDetail subject;

  /// The MAIN-only episode list, as [buildSubjectMetaLine] expects — it
  /// counts whatever it is given without filtering by
  /// [SubjectEpisode.isMain].
  final List<SubjectEpisode> episodes;

  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = subject.nameCn.isNotEmpty ? subject.nameCn : subject.name;
    final showOriginal = subject.name.isNotEmpty && subject.name != title;
    final metaLine = buildSubjectMetaLine(
      airDate: subject.airDate,
      episodes: episodes,
      episodeCount: subject.episodeCount,
      now: now,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(
          title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        if (showOriginal)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: SelectableText(
              subject.name,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.hintColor,
              ),
            ),
          ),
        if (metaLine.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              metaLine,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
          ),
      ],
    );
  }
}
