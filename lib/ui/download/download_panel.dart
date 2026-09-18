import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/download/downloaded_episode_repository.dart';
import '../../data/download/downloaded_episodes_provider.dart';
import '../../domain/download/download_queue_controller.dart';
import 'download_list_item.dart';
import 'episode_selection_tab.dart';

/// Merges persisted rows with live queue progress, filtered to
/// [subjectId] when given. Shared by [DownloadPanel]'s tab-count label
/// and its list tab so both read the same filtered set.
final _filteredDownloadsProvider = Provider.family<
  List<DownloadedEpisodeSummary>,
  int?
>((ref, subjectId) {
  final rows = ref.watch(downloadedEpisodesProvider).value ?? const [];
  if (subjectId == null) return rows;
  return rows.where((row) => row.subjectId == subjectId).toList();
});

/// The single download UI shown from the home screen, the subject
/// detail page's "选集" header, and the player's bottom bar -- only
/// the [subjectId] filter differs between call sites.
///
/// When [subjectId] is null, the "选集下载" tab is hidden (there is no
/// single subject's episode list to show) and the list tab covers every
/// subject. [subjectName] is required whenever [subjectId] is given,
/// since the episode-selection tab needs it to resolve the merged
/// episode list.
class DownloadPanel extends ConsumerWidget {
  const DownloadPanel({super.key, this.subjectId, this.subjectName})
    : assert(
        subjectId == null || subjectName != null,
        'subjectName is required whenever subjectId is given',
      );

  final int? subjectId;
  final String? subjectName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showEpisodeTab = subjectId != null;
    final count = ref.watch(_filteredDownloadsProvider(subjectId)).length;

    return DefaultTabController(
      length: showEpisodeTab ? 2 : 1,
      child: Column(
        children: [
          TabBar(
            tabs: [
              if (showEpisodeTab) const Tab(text: '选集下载'),
              Tab(text: '下载中 · 已下载($count)'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                if (showEpisodeTab)
                  EpisodeSelectionTab(
                    subjectId: subjectId!,
                    subjectName: subjectName!,
                  ),
                _ListTab(subjectId: subjectId),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ListTab extends ConsumerWidget {
  const _ListTab({required this.subjectId});

  final int? subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(_filteredDownloadsProvider(subjectId));
    final queueState = ref.watch(downloadQueueControllerProvider);
    final queue = switch (queueState) {
      AsyncData(:final value) => value,
      _ => const <String, DownloadQueueItem>{},
    };

    if (rows.isEmpty) return const Center(child: Text('暂无下载'));
    return ListView.builder(
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        return DownloadListItem(
          row: row,
          queueItem: queue[row.episodeKey],
          onCancel: () => ref
              .read(downloadQueueControllerProvider.notifier)
              .cancel(row.episodeKey),
          onRetry: () async {
            try {
              await ref
                  .read(downloadQueueControllerProvider.notifier)
                  .retry(row.episodeKey);
            } catch (error) {
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('$error')));
              }
            }
          },
          onDelete: () => ref
              .read(downloadedEpisodeRepositoryProvider)
              .deleteWithFiles(row.episodeKey),
        );
      },
    );
  }
}
