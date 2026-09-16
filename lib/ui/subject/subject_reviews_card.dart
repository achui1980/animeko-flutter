// lib/ui/subject/subject_reviews_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/subject/bbcode.dart';
import '../../data/subject/review_models.dart';
import '../../domain/subject/subject_reviews_controller.dart';
import 'review_avatar.dart';
import 'subject_reviews_card_frame.dart';
import 'subject_reviews_sheet.dart';

/// 热门评价 card for the right column: the first few other-user comments,
/// with 「查看全部 ›」 opening [SubjectReviewsSheet] over the same provider.
///
/// Failure and empty are both silent (the whole card disappears) -- reviews
/// are a nice-to-have, and the reference app's sidebar simply has one fewer
/// card when they're unavailable. Loading keeps the card frame so the
/// right column doesn't jump once the request lands.
class SubjectReviewsCard extends ConsumerWidget {
  const SubjectReviewsCard({super.key, required this.subjectId});

  final int subjectId;

  /// How many reviews the card shows before 「查看全部」. Estimate from the
  /// design doc (the reference screenshot shows 2-3); adjust freely.
  static const int maxVisible = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(
      subjectReviewsControllerProvider(subjectId: subjectId),
    );
    final page = async.value;

    if (page == null) {
      if (!async.isLoading) return const SizedBox.shrink();
      return const SubjectReviewsCardFrame(
        child: SizedBox(
          height: 64,
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    if (page.items.isEmpty) return const SizedBox.shrink();

    return SubjectReviewsCardFrame(
      onSeeAll: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => SubjectReviewsSheet(subjectId: subjectId),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final review in page.items.take(maxVisible))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ReviewItem(review: review),
            ),
        ],
      ),
    );
  }
}

class _ReviewItem extends StatelessWidget {
  const _ReviewItem({required this.review});

  final SubjectReview review;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // `stripBbcode` already trims, so no `.trim()` here. It returns ''
    // for an image-only / mask-only review, which the `isNotEmpty` guard
    // below turns into "render no body line at all".
    final content = stripBbcode(review.contentBbcode ?? '');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ReviewAvatar(author: review.author),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                review.author.nickname,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
        if (content.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              content,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}
