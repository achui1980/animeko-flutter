// lib/ui/subject/subject_detail_left_pane.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/subject/subject_detail_controller.dart';
import 'continue_watching_button.dart';
import 'subject_collection_action_button.dart';
import 'subject_collection_stats.dart';
import 'subject_cover.dart';
import 'subject_info_table.dart';

/// Wide-screen left column: cover, the two primary actions, aggregate
/// collection counts, and the 作品信息 table.
///
/// Pure composition -- no business logic, no width of its own (the parent
/// constrains it to 200dp). The narrow-screen layout does NOT use this
/// widget; it re-arranges the same children into a horizontal header plus
/// a stacked info table (see `SubjectDetailScreen`).
class SubjectDetailLeftPane extends ConsumerWidget {
  const SubjectDetailLeftPane({
    super.key,
    required this.subjectId,
    required this.subjectName,
    required this.imageUrl,
  });

  final int subjectId;
  final String subjectName;
  final String? imageUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subject = ref
        .watch(subjectDetailControllerProvider(subjectId: subjectId))
        .value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SubjectCover(imageUrl: imageUrl, width: 200),
        const SizedBox(height: 16),
        ContinueWatchingButton(subjectId: subjectId, subjectName: subjectName),
        const SizedBox(height: 8),
        SubjectCollectionActionButton(subjectId: subjectId, imageUrl: imageUrl),
        const SizedBox(height: 16),
        SubjectCollectionStats(favorite: subject?.favorite),
        const SizedBox(height: 16),
        if (subject != null) SubjectInfoTable(subject: subject),
      ],
    );
  }
}
