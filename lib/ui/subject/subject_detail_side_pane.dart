// lib/ui/subject/subject_detail_side_pane.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/subject/subject_detail_controller.dart';
import 'subject_rating_card.dart';
import 'subject_reviews_card.dart';
import 'subject_staff_card.dart';

/// Right column: the three cards, top to bottom.
///
/// Pure composition. Each card hides itself when its own data is missing
/// (see the design doc's error-tier table), so this widget has no
/// conditional logic beyond waiting for the subject payload the staff
/// card needs.
class SubjectDetailSidePane extends ConsumerWidget {
  const SubjectDetailSidePane({super.key, required this.subjectId});

  final int subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subject = ref
        .watch(subjectDetailControllerProvider(subjectId: subjectId))
        .value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SubjectRatingCard(subjectId: subjectId),
        SubjectReviewsCard(subjectId: subjectId),
        if (subject != null) SubjectStaffCard(subject: subject),
      ],
    );
  }
}
