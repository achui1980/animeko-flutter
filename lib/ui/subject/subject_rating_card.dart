// lib/ui/subject/subject_rating_card.dart
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/auth/auth_gate.dart';
import '../../domain/subject/subject_collection_controller.dart';
import '../../domain/subject/subject_detail_controller.dart';
import '../common/rating_stars.dart';
import 'subject_rating_dialog.dart';
import 'subject_side_card.dart';

/// The 评分 card at the top of the right column: aggregate score, rank,
/// rating count, the 1-10 distribution histogram, and the `☆ 打分`
/// entry point into [showSubjectRatingDialog].
///
/// The histogram was previously `_RatingHistogramSection` in
/// `subject_detail_screen.dart`; the rating form was `_RatingSection` in
/// the left column. Both now live here / in the dialog.
///
/// The backend has no rating-count field, so the count is summed from
/// `scoreDetails` (verified to match Bangumi's own `rating.count`).
class SubjectRatingCard extends ConsumerWidget {
  const SubjectRatingCard({super.key, required this.subjectId});

  final int subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final subject = ref
        .watch(subjectDetailControllerProvider(subjectId: subjectId))
        .value;
    if (subject == null) return const SizedBox.shrink();

    final selfRating = ref
        .watch(subjectCollectionControllerProvider(subjectId: subjectId))
        .value
        ?.selfRating;
    final myScore = selfRating != null && selfRating.score > 0
        ? selfRating.score
        : null;

    final details = subject.scoreDetails;
    final hasHistogram = details != null && details.isNotEmpty;
    final total = hasHistogram
        ? details.values.fold(0, (sum, count) => sum + count)
        : 0;
    final maxCount = hasHistogram && total > 0 ? details.values.reduce(max) : 0;
    final score = subject.score != null
        ? double.tryParse(subject.score!)
        : null;

    return SubjectSideCard(
      title: '评分',
      trailing: TextButton(
        onPressed: () {
          if (!requireLogin(context, ref)) return;
          showSubjectRatingDialog(
            context,
            subjectId: subjectId,
            initialScore: myScore ?? 5,
            initialComment: selfRating?.comment,
            initialIsPrivate: selfRating?.isPrivate ?? false,
          );
        },
        child: Text(myScore == null ? '☆ 打分' : '☆ 已评 $myScore 分'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (score == null)
            Text('暂无评分', style: theme.textTheme.bodyMedium)
          else
            RatingStars(score: score),
          if (subject.rank != null || total > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                [
                  if (subject.rank != null) '#${subject.rank}',
                  if (total > 0) '$total 人评分',
                ].join(' · '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          if (maxCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var score = 1; score <= 10; score++)
                    _HistogramBar(
                      score: score,
                      count: details!['$score'] ?? 0,
                      maxCount: maxCount,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// One bar of the 1-10 rating distribution. Ported verbatim from
/// `subject_detail_screen.dart`'s `_HistogramBar`.
class _HistogramBar extends StatelessWidget {
  const _HistogramBar({
    required this.score,
    required this.count,
    required this.maxCount,
  });

  final int score;
  final int count;
  final int maxCount;

  static const double _maxBarHeight = 48;
  static const double _minBarHeight = 2;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final barHeight = count == 0
        ? _minBarHeight
        : max(_minBarHeight, _maxBarHeight * count / maxCount);
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 12,
          height: barHeight,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 4),
        Text('$score', style: theme.textTheme.labelSmall),
      ],
    );
  }
}
