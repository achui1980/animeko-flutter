// lib/ui/schedule/schedule_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/schedule/schedule_controller.dart';
import '../common/anime_list_item.dart';
import '../common/app_action_bar.dart';
import '../common/error_retry_view.dart';
import '../subject/subject_navigation.dart';

class ScheduleScreen extends ConsumerWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(scheduleControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Schedule'), actions: buildStandardActions(context)),
      body: days.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorRetryView(
          message: 'Failed to load schedule: $error',
          onRetry: () => ref.invalidate(scheduleControllerProvider),
        ),
        data: (days) => ListView.builder(
          itemCount: days.length,
          itemBuilder: (context, index) {
            final day = days[index];
            return ExpansionTile(
              title: Text(day.date),
              children: day.subjects
                  .map(
                    (card) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: AnimeListItem(
                        imageUrl: card.imageUrl ?? '',
                        title: card.nameCn ?? card.name,
                        subtitle: day.date,
                        onTap: () => openSubjectDetail(context, card),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ),
    );
  }
}
