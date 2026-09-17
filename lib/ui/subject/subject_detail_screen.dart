// lib/ui/subject/subject_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_spacing.dart';
import '../../data/subject/subject_models.dart';
import '../../domain/download/download_queue_controller.dart';
import '../../domain/play/subject_episodes_controller.dart';
import '../../domain/subject/subject_detail_controller.dart';
import '../../domain/subject/subject_main_episodes_controller.dart';
import '../common/error_retry_view.dart';
import 'continue_watching_button.dart';
import 'subject_collection_action_button.dart';
import 'subject_collection_stats.dart';
import 'subject_cover.dart';
import 'subject_detail_left_pane.dart';
import 'subject_detail_main_pane.dart';
import 'subject_detail_side_pane.dart';
import 'subject_info_table.dart';
import 'subject_title_block.dart';

/// Returns every episode for the first registered HTTP download source.
List<MergedEpisode> firstDownloadableSourceEpisodes(
  List<MergedEpisode> allMerged,
) {
  final sourceId = allMerged
      .map((item) => item.sourceId)
      .firstWhere((id) => id == 'anime1' || id == 'xifan');
  return allMerged.where((item) => item.sourceId == sourceId).toList();
}

/// The subject detail page.
///
/// This widget owns three things:
///
/// 1. the `Scaffold` and a deliberately title-less `AppBar` (the title now
///    lives in the middle column, so repeating it in the bar wastes a row
///    and duplicates text -- see the design doc's AppBar decision);
/// 2. the whole-page loading spinner / retry view for the ONE request the
///    whole page depends on (`subjectDetailControllerProvider`); every
///    other data source degrades inside its own section;
/// 3. the wide-vs-narrow layout branch at
///    [subjectDetailThreeColumnBreakpoint].
///
/// The wide branch delegates all section content to the pane widgets and
/// the leaf widgets they compose -- do not add section markup there. The
/// narrow branch (`_narrow`) is the one exception: it re-arranges the same
/// leaf widgets (`SubjectCover`, `SubjectTitleBlock`,
/// `ContinueWatchingButton`, `SubjectCollectionActionButton`,
/// `SubjectCollectionStats`, `SubjectInfoTable`) directly, since the
/// narrow layout's ordering differs from `SubjectDetailLeftPane`'s.
///
/// [imageUrl] arrives as a route query parameter because no subject
/// endpoint returns a cover image (verified against the backend).
class SubjectDetailScreen extends ConsumerWidget {
  const SubjectDetailScreen({
    super.key,
    required this.subjectId,
    required this.subjectName,
    this.imageUrl,
    this.now,
  });

  final int subjectId;
  final String subjectName;
  final String? imageUrl;

  /// Test-only override for "today", forwarded to the meta line and the
  /// 选集 progress label.
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(
      subjectDetailControllerProvider(subjectId: subjectId),
    );

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: '全部下载',
            onPressed: () async {
              try {
                final episodes = firstDownloadableSourceEpisodes(
                  await ref.read(
                    subjectEpisodesControllerProvider(
                      subjectId: subjectId,
                      subjectName: subjectName,
                    ).future,
                  ),
                );
                for (final episode in episodes) {
                  ref
                      .read(downloadQueueControllerProvider.notifier)
                      .enqueue(
                        subjectId: subjectId,
                        subjectName: subjectName,
                        episode: episode,
                      );
                }
              } on StateError {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('没有可下载的视频源')));
                }
              }
            },
          ),
        ],
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: ErrorRetryView(
            message: '加载详情失败：$error',
            onRetry: () => ref.invalidate(
              subjectDetailControllerProvider(subjectId: subjectId),
            ),
          ),
        ),
        data: (subject) => LayoutBuilder(
          builder: (context, constraints) {
            final isWide =
                constraints.maxWidth >= subjectDetailThreeColumnBreakpoint;
            return SingleChildScrollView(
              padding: EdgeInsets.all(pagePadding(context)),
              child: isWide ? _wide() : _narrow(ref, subject),
            );
          },
        ),
      ),
    );
  }

  Widget _wide() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 200,
          child: SubjectDetailLeftPane(
            subjectId: subjectId,
            subjectName: subjectName,
            imageUrl: imageUrl,
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: SubjectDetailMainPane(
            subjectId: subjectId,
            subjectName: subjectName,
            now: now,
          ),
        ),
        const SizedBox(width: 24),
        SizedBox(
          width: 300,
          child: SubjectDetailSidePane(subjectId: subjectId),
        ),
      ],
    );
  }

  /// Narrow layout: the left column's children are re-arranged rather than
  /// reused as a block -- the cover sits beside the title in a horizontal
  /// header (a 200dp poster would eat the whole screen), and the three side
  /// cards move to the bottom.
  Widget _narrow(WidgetRef ref, SubjectDetail subject) {
    final episodes =
        ref
            .watch(subjectMainEpisodesControllerProvider(subjectId: subjectId))
            .value ??
        const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SubjectCover(imageUrl: imageUrl, width: 120),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SubjectTitleBlock(
                    subject: subject,
                    episodes: episodes,
                    now: now,
                  ),
                  const SizedBox(height: 12),
                  ContinueWatchingButton(
                    subjectId: subjectId,
                    subjectName: subjectName,
                  ),
                  const SizedBox(height: 8),
                  SubjectCollectionActionButton(
                    subjectId: subjectId,
                    imageUrl: imageUrl,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SubjectCollectionStats(favorite: subject.favorite),
        const SizedBox(height: 16),
        SubjectInfoTable(subject: subject),
        const SizedBox(height: 16),
        SubjectDetailMainPane(
          subjectId: subjectId,
          subjectName: subjectName,
          showTitle: false,
          now: now,
        ),
        const SizedBox(height: 16),
        SubjectDetailSidePane(subjectId: subjectId),
      ],
    );
  }
}
