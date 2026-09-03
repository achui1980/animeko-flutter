// lib/ui/search/search_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/search/search_controller.dart';
import '../common/anime_list_item.dart';
import '../common/app_action_bar.dart';
import '../common/empty_view.dart';
import '../common/error_retry_view.dart';
import '../subject/subject_navigation.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(searchControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          decoration: const InputDecoration(hintText: 'Search subjects...'),
          onChanged: (value) => ref
              .read(searchControllerProvider.notifier)
              .search(keywords: value),
        ),
        actions: buildStandardActions(context),
      ),
      body: results.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => ErrorRetryView(
          message: 'Search failed: $error',
          onRetry: () => ref.invalidate(searchControllerProvider),
        ),
        data: (cards) {
          if (cards.isEmpty) {
            return const EmptyView(
              icon: Icons.search_off,
              message: '没有找到相关番剧，换个关键词试试',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(8),
            itemCount: cards.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final card = cards[index];
              return AnimeListItem(
                imageUrl: card.imageUrl ?? '',
                title: card.nameCn ?? card.name,
                subtitle: card.tags?.join(', ') ?? '',
                onTap: () => openSubjectDetail(context, card),
              );
            },
          );
        },
      ),
    );
  }
}
