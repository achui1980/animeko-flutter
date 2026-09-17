import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/download/downloaded_episode_repository.dart';
import '../../data/download/downloaded_episodes_provider.dart';
import '../../domain/download/download_queue_controller.dart';
import '../../domain/play/subject_episodes_controller.dart';
import 'download_list_item.dart';

class DownloadManagerScreen extends ConsumerWidget {
  const DownloadManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloads = ref.watch(downloadedEpisodesProvider);
    final queueState = ref.watch(downloadQueueControllerProvider);
    final queue = switch (queueState) {
      AsyncData(:final value) => value,
      _ => const <String, DownloadQueueItem>{},
    };

    return Scaffold(
      appBar: AppBar(title: const Text('下载管理')),
      body: downloads.when(
        data: (rows) {
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
                onRetry: () => _retry(context, ref, row),
                onDelete: () => _delete(ref, row),
              );
            },
          );
        },
        error: (_, _) => const Center(child: Text('无法加载下载记录')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Future<void> _retry(
    BuildContext context,
    WidgetRef ref,
    DownloadedEpisodeSummary row,
  ) async {
    try {
      final episodes = await ref.read(
        subjectEpisodesControllerProvider(
          subjectId: row.subjectId,
          subjectName: row.subjectName,
        ).future,
      );
      final match = episodes.where(
        (episode) =>
            episode.sourceId == row.sourceId &&
            episode.title == row.episodeLabel,
      );
      if (match.isEmpty) throw StateError('Episode unavailable');
      ref
          .read(downloadQueueControllerProvider.notifier)
          .enqueue(
            subjectId: row.subjectId,
            subjectName: row.subjectName,
            episode: match.first,
          );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('无法重新解析此集')));
      }
    }
  }

  Future<void> _delete(WidgetRef ref, DownloadedEpisodeSummary row) async {
    await DownloadListItem.deleteLocalPath(row.localPath);
    await ref.read(downloadedEpisodeRepositoryProvider).delete(row.episodeKey);
  }
}
