// lib/ui/subject/subject_reviews_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/subject/bbcode.dart';
import '../../domain/subject/subject_reviews_controller.dart';
import 'review_avatar.dart';

/// 「查看全部」 target for the 热门评价 card: a scrollable sheet over the
/// same `subjectReviewsControllerProvider` the card already populated, with
/// a 「加载更多」 button driven by `PaginatedReviews.hasMore`.
///
/// The backend's `total` is a `limit + 1` sentinel, NOT a real count, so
/// this sheet never renders a 「共 N 条」 header -- see `PaginatedReviews`.
///
/// This is a [ConsumerStatefulWidget], not a [ConsumerWidget], because
/// `SubjectReviewsController.loadMore` (`subject_reviews_controller.dart`)
/// appends into the *existing* `AsyncData` and only ever calls
/// `state = AsyncData(...)` on success -- it never routes through
/// `AsyncValue.guard`, so `ref.watch(provider).isLoading` stays `false`
/// for the button's entire in-flight duration and `async.isLoading
/// ? null : ...` never actually disables the button (a double-tap during
/// the request re-enters `loadMore`, which just re-appends the same next
/// page onto whatever `current` it captures). It also never catches: an
/// error thrown by the `getReviews` call inside `loadMore` propagates
/// straight out of the button's `onPressed`, uncaught. So the button
/// needs its own local `_loadingMore` flag around the `await`, plus a
/// `try/catch` with a failure `SnackBar` (loadMore() deliberately doesn't
/// swallow failures itself). Note a latent, currently-unreachable
/// interaction: a failed `loadMore` leaves `state` exactly as it was
/// (the first page's `AsyncData`), so nothing here can overwrite an error
/// state -- that only becomes possible if a future task adds a
/// pull-to-refresh path that can put this provider into `AsyncError`
/// while `loadMore` is in flight.
class SubjectReviewsSheet extends ConsumerStatefulWidget {
  const SubjectReviewsSheet({super.key, required this.subjectId});

  final int subjectId;

  @override
  ConsumerState<SubjectReviewsSheet> createState() =>
      _SubjectReviewsSheetState();
}

class _SubjectReviewsSheetState extends ConsumerState<SubjectReviewsSheet> {
  bool _loadingMore = false;

  Future<void> _loadMore() async {
    final provider = subjectReviewsControllerProvider(
      subjectId: widget.subjectId,
    );
    setState(() => _loadingMore = true);
    try {
      await ref.read(provider.notifier).loadMore();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('加载更多评价失败：$e')));
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = subjectReviewsControllerProvider(
      subjectId: widget.subjectId,
    );
    final async = ref.watch(provider);
    final page = async.value;
    final reviews = page?.items ?? const [];

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [Text('全部评价', style: theme.textTheme.titleMedium)],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: reviews.length + 1,
                itemBuilder: (context, index) {
                  if (index == reviews.length) {
                    if (page == null || !page.hasMore) {
                      return const SizedBox(height: 16);
                    }
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: TextButton(
                          onPressed: _loadingMore ? null : _loadMore,
                          child: const Text('加载更多'),
                        ),
                      ),
                    );
                  }
                  final review = reviews[index];
                  // `stripBbcode` already trims, and returns '' for an
                  // image-only / mask-only review. Pass `null` rather than
                  // `Text('')` in that case -- an empty `Text` is still a
                  // full line height and pushes `ListTile` into its
                  // two-line layout, leaving a visibly blank second row.
                  final content = stripBbcode(review.contentBbcode ?? '');
                  return ListTile(
                    leading: ReviewAvatar(author: review.author, radius: 18),
                    title: Text(review.author.nickname),
                    subtitle: content.isEmpty ? null : Text(content),
                    trailing: review.rating == null
                        ? null
                        : Text(
                            '${review.rating}',
                            style: theme.textTheme.titleSmall,
                          ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
