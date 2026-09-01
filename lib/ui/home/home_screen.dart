// lib/ui/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/home/home_controller.dart';
import '../../domain/subject_card.dart';
import '../../ui/subject/subject_navigation.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeData = ref.watch(homeControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Animeko')),
      body: homeData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Failed to load home: $error')),
        data: (data) => ListView(
          children: [
            _SubjectCardSection(title: 'Trending', cards: data.trending),
            _SubjectCardSection(title: 'Recommended', cards: data.recommendations),
          ],
        ),
      ),
    );
  }
}

class _SubjectCardSection extends StatelessWidget {
  const _SubjectCardSection({required this.title, required this.cards});

  final String title;
  final List<SubjectCard> cards;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: cards.length,
            itemBuilder: (context, index) {
              final card = cards[index];
              return GestureDetector(
                onTap: () => openSubjectDetail(context, card),
                child: SizedBox(
                  width: 120,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      children: [
                        Expanded(
                          child: card.imageUrl != null
                              ? Image.network(card.imageUrl!, fit: BoxFit.cover)
                              : Container(color: Colors.grey.shade300),
                        ),
                        Text(
                          card.nameCn ?? card.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
