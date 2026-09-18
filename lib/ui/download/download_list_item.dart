import 'package:flutter/material.dart';

import '../../data/download/downloaded_episode_repository.dart';
import '../../data/download/downloaded_episodes_provider.dart';
import '../../domain/download/download_queue_controller.dart';

class DownloadListItem extends StatelessWidget {
  const DownloadListItem({
    required this.row,
    required this.queueItem,
    required this.onCancel,
    required this.onRetry,
    required this.onDelete,
    super.key,
  });

  final DownloadedEpisodeSummary row;
  final DownloadQueueItem? queueItem;
  final VoidCallback onCancel;
  final VoidCallback onRetry;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final status = queueItem?.status;
    final isDownloading =
        status == DownloadQueueStatus.queued ||
        status == DownloadQueueStatus.downloading ||
        row.status == DownloadStatus.downloading.name;
    final isStalled = queueItem?.isStalled ?? false;
    final isInterrupted =
        status == null && row.status == DownloadStatus.interrupted.name;
    final isFailed =
        status == DownloadQueueStatus.failed ||
        row.status == DownloadStatus.failed.name;

    return ListTile(
      title: Text(row.subjectName),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${row.sourceId} · ${row.episodeLabel}'),
          if (isStalled)
            const Text('已停滞，正在重试')
          else if (isDownloading)
            LinearProgressIndicator(value: queueItem?.progress),
          if (isInterrupted) const Text('已中断'),
          if (isFailed)
            Text(queueItem?.errorMessage ?? row.errorMessage ?? '下载失败'),
        ],
      ),
      isThreeLine: isDownloading || isFailed || isInterrupted,
      trailing: isDownloading
          ? TextButton(onPressed: onCancel, child: const Text('取消'))
          : (isFailed || isInterrupted)
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(onPressed: onRetry, child: const Text('重试')),
                TextButton(onPressed: onDelete, child: const Text('删除')),
              ],
            )
          : TextButton(onPressed: onDelete, child: const Text('删除')),
    );
  }
}
