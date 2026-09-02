// lib/ui/schedule/schedule_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/schedule/schedule_controller.dart';
import '../../ui/subject/subject_navigation.dart';

class ScheduleScreen extends ConsumerWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(scheduleControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark),
            onPressed: () => context.push('/collection'),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: days.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Failed to load schedule: $error')),
        data: (schedule) => ListView.builder(
          itemCount: schedule.length,
          itemBuilder: (context, index) {
            final day = schedule[index];
            return ExpansionTile(
              title: Text(day.date),
              children: day.subjects
                  .map(
                    (card) => ListTile(
                      leading: card.imageUrl != null
                          ? Image.network(card.imageUrl!, width: 40, fit: BoxFit.cover)
                          : const SizedBox(width: 40),
                      title: Text(card.nameCn ?? card.name),
                      onTap: () => openSubjectDetail(context, card),
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
