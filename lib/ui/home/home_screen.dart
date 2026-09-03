// lib/ui/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_spacing.dart';
import '../../domain/home/home_controller.dart';
import '../../domain/subject_card.dart';
import '../../ui/subject/subject_navigation.dart';
import '../common/anime_cover_card.dart';
import '../common/app_action_bar.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeData = ref.watch(homeControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Animeko'), actions: buildStandardActions(context)),
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
    final padding = pagePadding(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(padding, 8, padding, 8),
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        SizedBox(
          height: 210,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: padding),
            itemCount: cards.length,
            itemBuilder: (context, index) {
              final card = cards[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: SizedBox(
                  width: 120,
                  child: AnimeCoverCard(
                    imageUrl: card.imageUrl ?? '',
                    title: card.nameCn ?? card.name,
                    onTap: () => openSubjectDetail(context, card),
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
