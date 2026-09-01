// lib/ui/search/search_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/search/search_controller.dart';
import '../../ui/subject/subject_navigation.dart';

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
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: results.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Search failed: $error')),
        data: (cards) => ListView.builder(
          itemCount: cards.length,
          itemBuilder: (context, index) {
            final card = cards[index];
            return ListTile(
              leading: card.imageUrl != null
                  ? Image.network(card.imageUrl!, width: 48, fit: BoxFit.cover)
                  : const SizedBox(width: 48),
              title: Text(card.nameCn ?? card.name),
              subtitle: card.tags != null && card.tags!.isNotEmpty
                  ? Text(card.tags!.join(', '))
                  : null,
              onTap: () => openSubjectDetail(context, card),
            );
          },
        ),
      ),
    );
  }
}
