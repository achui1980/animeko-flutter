// lib/ui/schedule/schedule_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_spacing.dart';
import '../../domain/schedule/schedule_controller.dart';
import '../common/anime_cover_card.dart';
import '../common/app_action_bar.dart';
import '../common/error_retry_view.dart';
import '../common/tag_chip.dart';
import '../subject/subject_navigation.dart';

const _weekdayNames = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];

/// Formats a schedule day's `YYYY-MM-DD` date string as a readable Chinese
/// date, e.g. `2024-01-01` -> `1月1日 星期一`. Falls back to the raw string
/// if it can't be parsed.
String formatScheduleDate(String isoDate) {
  try {
    final date = DateTime.parse(isoDate);
    return '${date.month}月${date.day}日 ${_weekdayNames[date.weekday - 1]}';
  } on FormatException {
    return isoDate;
  }
}

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
        data: (days) {
          final padding = pagePadding(context);
          final today = todayDateString(DateTime.now());
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: days.length,
            itemBuilder: (context, index) {
              final day = days[index];
              final isToday = day.date == today;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(padding, 12, padding, 12),
                    child: Row(
                      children: [
                        Text(
                          formatScheduleDate(day.date),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        if (isToday) ...[const SizedBox(width: 8), const TagChip(label: '今天')],
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 210,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(horizontal: padding),
                      itemCount: day.subjects.length,
                      itemBuilder: (context, subjectIndex) {
                        final card = day.subjects[subjectIndex];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
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
            },
          );
        },
      ),
    );
  }
}
