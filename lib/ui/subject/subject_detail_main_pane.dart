// lib/ui/subject/subject_detail_main_pane.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/subject/subject_detail_controller.dart';
import '../../domain/subject/subject_main_episodes_controller.dart';
import 'expandable_summary.dart';
import 'subject_character_row.dart';
import 'subject_episodes_section.dart';
import 'subject_title_block.dart';

/// Middle column: title block, summary, 选集 grid, 角色 row.
///
/// Pure composition. Used unchanged by both the wide and the narrow
/// layout -- only its width differs.
class SubjectDetailMainPane extends ConsumerWidget {
  const SubjectDetailMainPane({
    super.key,
    required this.subjectId,
    required this.subjectName,
    this.showTitle = true,
    this.now,
  });

  final int subjectId;
  final String subjectName;

  /// The narrow layout renders [SubjectTitleBlock] inside its horizontal
  /// top header instead (next to the cover), so it passes `false` here to
  /// avoid showing the title twice.
  final bool showTitle;

  /// Test-only override for "today" -- forwarded to the meta line and the
  /// 选集 progress label so tests don't depend on the wall clock.
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subject = ref
        .watch(subjectDetailControllerProvider(subjectId: subjectId))
        .value;
    final episodes =
        ref
            .watch(subjectMainEpisodesControllerProvider(subjectId: subjectId))
            .value ??
        const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle && subject != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: SubjectTitleBlock(
              subject: subject,
              episodes: episodes,
              now: now,
            ),
          ),
        if (subject != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: ExpandableSummary(text: subject.summary),
          ),
        SubjectEpisodesSection(
          subjectId: subjectId,
          subjectName: subjectName,
          now: now,
        ),
        SubjectCharacterRow(subjectId: subjectId),
      ],
    );
  }
}
