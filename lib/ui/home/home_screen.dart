// lib/ui/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_spacing.dart';
import '../../domain/home/home_recommendations_controller.dart';
import '../../domain/home/trending_controller.dart';
import '../../domain/subject_card.dart';
import '../common/anime_cover_card.dart';
import '../common/app_action_bar.dart';
import '../common/error_retry_view.dart';
import '../subject/subject_navigation.dart';
import 'trending_carousel.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _loadingMore = false;
  bool _loadMoreFailed = false;

  Future<void> _loadMore() async {
    setState(() {
      _loadingMore = true;
      _loadMoreFailed = false;
    });
    try {
      await ref.read(homeRecommendationsControllerProvider.notifier).loadMore();
    } catch (_) {
      if (mounted) setState(() => _loadMoreFailed = true);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trending = ref.watch(trendingProvider);
    final recommendations = ref.watch(homeRecommendationsControllerProvider);
    final padding = pagePadding(context);
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      body: NotificationListener<ScrollEndNotification>(
        onNotification: (notification) {
          // `notification.depth == 0` restricts this to scroll-end events
          // from this listener's own nearest Scrollable (the
          // CustomScrollView below). Notifications that bubbled up from a
          // nested Scrollable further down the tree -- e.g. TrendingCarousel's
          // own horizontal CarouselView, whether dragged by the user or
          // auto-advanced by its internal timer -- arrive with depth >= 1
          // and must be ignored: their metrics describe the carousel's own
          // scroll position, not the user's position in this vertical grid.
          if (notification.depth != 0) return false;
          final page = recommendations.value;
          final metrics = notification.metrics;
          if (page != null &&
              page.hasMore &&
              !_loadingMore &&
              metrics.pixels >= metrics.maxScrollExtent - 40) {
            _loadMore();
          }
          return false;
        },
        child: CustomScrollView(
          slivers: [
            _CollapsingHomeAppBar(actions: buildStandardActions(context)),
            SliverToBoxAdapter(
              child: _TrendingSection(
                trending: trending,
                onRetry: () => ref.invalidate(trendingProvider),
              ),
            ),
            const SliverToBoxAdapter(child: _SectionTitle('为你推荐')),
            ...recommendations.when(
              loading: () => const [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
              ],
              error: (error, stack) => [
                SliverToBoxAdapter(
                  child: ErrorRetryView(
                    message: 'Failed to load recommendations: $error',
                    onRetry: () => ref.invalidate(homeRecommendationsControllerProvider),
                  ),
                ),
              ],
              data: (recPage) => [
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: padding),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _gridColumns(width),
                      childAspectRatio: 0.55,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final card = recPage.items[index];
                        return AnimeCoverCard(
                          imageUrl: card.imageUrl ?? '',
                          title: card.nameCn ?? card.name,
                          onTap: () => openSubjectDetail(context, card),
                        );
                      },
                      childCount: recPage.items.length,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _RecommendationsFooter(
                    hasMore: recPage.hasMore,
                    loading: _loadingMore,
                    failed: _loadMoreFailed,
                    onRetry: _loadMore,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// At least 3 columns even on narrow phones; scales up on wider screens
/// (design doc: 固定3列，宽屏自适应). Target column width ~130dp.
int _gridColumns(double width) => (width / 130).floor().clamp(3, 8);

/// A [SliverAppBar] whose title shrinks/lightens as the page scrolls,
/// collapsing from a large "hero" title down to a normal toolbar title.
/// Borrowed from Kazumi's `popular_page.dart` (pure Flutter animation, no
/// new dependencies).
class _CollapsingHomeAppBar extends StatelessWidget {
  const _CollapsingHomeAppBar({required this.actions});

  final List<Widget> actions;

  static const _expandedHeight = 120.0;
  static const _expandedFontSize = 28.0;
  static const _collapsedFontSize = 20.0;
  static const _subtitleFontSize = 13.0;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: _expandedHeight,
      stretch: true,
      pinned: true,
      actions: actions,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final t = ((constraints.maxHeight - kToolbarHeight) /
                  (_expandedHeight - kToolbarHeight))
              .clamp(0.0, 1.0);
          final fontSize = _collapsedFontSize + (_expandedFontSize - _collapsedFontSize) * t;
          final fontWeight = FontWeight.lerp(FontWeight.w500, FontWeight.w700, t);
          return FlexibleSpaceBar(
            titlePadding: const EdgeInsetsDirectional.only(start: 16, bottom: 16),
            // "AniMeow" is the app's English brand name; "喵番" is its Chinese
            // counterpart, shown as a small subtitle beneath it. The subtitle
            // fades out as the bar collapses (t -> 0) so the collapsed
            // toolbar keeps showing a single line, matching the pre-existing
            // collapsed layout.
            title: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AniMeow', style: TextStyle(fontSize: fontSize, fontWeight: fontWeight)),
                if (t > 0.01)
                  Opacity(
                    opacity: t,
                    child: Text(
                      '喵番',
                      style: TextStyle(
                        fontSize: _subtitleFontSize,
                        fontWeight: FontWeight.w400,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final padding = pagePadding(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(padding, 16, padding, 8),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _TrendingSection extends StatelessWidget {
  const _TrendingSection({required this.trending, required this.onRetry});

  final AsyncValue<List<SubjectCard>> trending;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return trending.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) =>
          ErrorRetryView(message: 'Failed to load trending: $error', onRetry: onRetry),
      data: (cards) {
        if (cards.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle('最近热门'),
            SizedBox(
              height: 220,
              child: TrendingCarousel(
                cards: cards,
                onTap: (card) => openSubjectDetail(context, card),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RecommendationsFooter extends StatelessWidget {
  const _RecommendationsFooter({
    required this.hasMore,
    required this.loading,
    required this.failed,
    required this.onRetry,
  });

  final bool hasMore;
  final bool loading;
  final bool failed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (failed) {
      return Center(child: TextButton(onPressed: onRetry, child: const Text('加载失败，点击重试')));
    }
    if (loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return const SizedBox.shrink();
  }
}
