// lib/ui/collection/my_collection_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/subject/collection_type.dart';
import '../../data/subject/subject_models.dart';
import '../../domain/subject/my_collections_controller.dart';
import '../../domain/subject_card.dart';
import '../common/anime_list_item.dart';
import '../common/empty_view.dart';
import '../common/error_retry_view.dart';
import '../subject/subject_navigation.dart';

class MyCollectionScreen extends ConsumerStatefulWidget {
  const MyCollectionScreen({super.key});

  @override
  ConsumerState<MyCollectionScreen> createState() => _MyCollectionScreenState();
}

const _collectionLabels = {
  CollectionType.wish: '想看',
  CollectionType.doing: '在看',
  CollectionType.done: '看过',
  CollectionType.onHold: '搁置',
  CollectionType.dropped: '弃番',
};

class _MyCollectionScreenState extends ConsumerState<MyCollectionScreen> {
  CollectionType _selected = CollectionType.doing;

  @override
  Widget build(BuildContext context) {
    final provider = myCollectionsControllerProvider(type: _selected);
    final items = ref.watch(provider);

    return Scaffold(
      appBar: AppBar(title: const Text('我的收藏')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: SegmentedButton<CollectionType>(
              segments: CollectionType.values
                  .map((type) => ButtonSegment(value: type, label: Text(_collectionLabels[type]!)))
                  .toList(),
              selected: {_selected},
              onSelectionChanged: (selection) => setState(() => _selected = selection.first),
            ),
          ),
          Expanded(
            child: items.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => ErrorRetryView(
                message: '加载失败：$error',
                onRetry: () => ref.invalidate(provider),
              ),
              data: (page) =>
                  _CollectionList(type: _selected, subjects: page.items, hasMore: page.hasMore),
            ),
          ),
        ],
      ),
    );
  }
}

/// The list itself + a "load more on scroll to bottom" footer row
/// (design doc: no pull-to-refresh, YAGNI). A failed load-more shows a
/// small retry text button without disturbing the already-loaded items.
/// Stops firing `loadMore()` (and stops rendering the footer) once
/// [hasMore] is false -- see `MyCollectionsPage.hasMore`.
class _CollectionList extends ConsumerStatefulWidget {
  const _CollectionList({required this.type, required this.subjects, required this.hasMore});

  final CollectionType type;
  final List<MyCollectionSubject> subjects;
  final bool hasMore;

  @override
  ConsumerState<_CollectionList> createState() => _CollectionListState();
}

class _CollectionListState extends ConsumerState<_CollectionList> {
  bool _loadingMore = false;
  bool _loadMoreFailed = false;

  Future<void> _loadMore() async {
    setState(() {
      _loadingMore = true;
      _loadMoreFailed = false;
    });
    try {
      await ref.read(myCollectionsControllerProvider(type: widget.type).notifier).loadMore();
    } catch (_) {
      if (mounted) setState(() => _loadMoreFailed = true);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.subjects.isEmpty) {
      return const EmptyView(message: '还没有收藏任何番剧');
    }
    final showFooter = widget.hasMore || _loadMoreFailed;
    return NotificationListener<ScrollEndNotification>(
      onNotification: (notification) {
        final metrics = notification.metrics;
        if (widget.hasMore && !_loadingMore && metrics.pixels >= metrics.maxScrollExtent - 40) {
          _loadMore();
        }
        return false;
      },
      child: ListView.builder(
        itemCount: widget.subjects.length + (showFooter ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == widget.subjects.length) {
            if (_loadMoreFailed) {
              return Center(
                child: TextButton(onPressed: _loadMore, child: const Text('加载失败，点击重试')),
              );
            }
            if (_loadingMore) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return const SizedBox.shrink();
          }
          final card = SubjectCard.fromMyCollectionSubject(widget.subjects[index]);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: AnimeListItem(
              imageUrl: card.imageUrl ?? '',
              title: card.nameCn ?? card.name,
              subtitle: _collectionLabels[widget.type] ?? '',
              onTap: () => openSubjectDetail(context, card),
            ),
          );
        },
      ),
    );
  }
}
