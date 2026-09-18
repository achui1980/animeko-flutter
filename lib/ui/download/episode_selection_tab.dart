import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/download/downloaded_episode_repository.dart';
import '../../domain/download/download_queue_controller.dart';
import '../../domain/download/download_source_resolver.dart';
import '../../domain/play/subject_episodes_controller.dart';

/// One tab of [DownloadPanel]: every episode of one subject, with a
/// checkbox per downloadable episode and a primary "下载选中 N 集" action.
///
/// Reuses [resolveDownloadOptions] (the same function batch/player
/// auto-select-source logic uses) so the downloadable/source-label
/// decision is made in exactly one place.
class EpisodeSelectionTab extends ConsumerStatefulWidget {
  const EpisodeSelectionTab({
    super.key,
    required this.subjectId,
    required this.subjectName,
  });

  final int subjectId;
  final String subjectName;

  @override
  ConsumerState<EpisodeSelectionTab> createState() =>
      _EpisodeSelectionTabState();
}

class _EpisodeSelectionTabState extends ConsumerState<EpisodeSelectionTab> {
  final _selected = <String>{};

  @override
  Widget build(BuildContext context) {
    final episodesAsync = ref.watch(
      subjectEpisodesControllerProvider(
        subjectId: widget.subjectId,
        subjectName: widget.subjectName,
      ),
    );
    final queue = ref.watch(downloadQueueControllerProvider).value ?? const {};

    return episodesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('加载剧集列表失败：$error')),
      data: (merged) {
        final options = resolveDownloadOptions(merged);
        return Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: options.length,
                itemBuilder: (context, index) =>
                    _row(options[index], queue),
              ),
            ),
            _bottomBar(options, queue),
          ],
        );
      },
    );
  }

  Widget _row(EpisodeDownloadOption option, Map<String, DownloadQueueItem> queue) {
    final downloadedAsync = option.preferred == null
        ? null
        : ref.watch(
            downloadedEpisodeForEpisodeProvider(widget.subjectId, option.title),
          );
    final isDownloaded = downloadedAsync?.value ?? false;
    final queueItem = option.preferred == null
        ? null
        : queue['${widget.subjectId}::${option.preferred!.sourceId}::${option.title}'];
    final isDownloading = queueItem != null &&
        (queueItem.status == DownloadQueueStatus.queued ||
            queueItem.status == DownloadQueueStatus.downloading);
    final selectable = option.isDownloadable && !isDownloaded && !isDownloading;

    String? trailingText;
    if (isDownloaded) {
      trailingText = '已下载';
    } else if (isDownloading) {
      final percent = queueItem.progress == null
          ? ''
          : ' ${(queueItem.progress! * 100).round()}%';
      trailingText = '下载中$percent';
    } else if (!option.isDownloadable) {
      trailingText = '无可下载来源';
    }

    final sourceLabel = option.candidates.map((e) => e.sourceId).join(' / ');

    return CheckboxListTile(
      value: _selected.contains(option.title),
      onChanged: selectable
          ? (checked) => setState(() {
              if (checked ?? false) {
                _selected.add(option.title);
              } else {
                _selected.remove(option.title);
              }
            })
          : null,
      title: Text(option.title),
      subtitle: Row(
        children: [
          if (option.isDownloadable) Text(sourceLabel),
          if (trailingText != null) ...[
            if (option.isDownloadable) const Text(' · '),
            Text(
              trailingText,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _bottomBar(
    List<EpisodeDownloadOption> options,
    Map<String, DownloadQueueItem> queue,
  ) {
    bool selectableNow(EpisodeDownloadOption option) {
      if (!option.isDownloadable) return false;
      final queueItem =
          queue['${widget.subjectId}::${option.preferred!.sourceId}::${option.title}'];
      final isDownloading = queueItem != null &&
          (queueItem.status == DownloadQueueStatus.queued ||
              queueItem.status == DownloadQueueStatus.downloading);
      return !isDownloading;
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          TextButton(
            onPressed: () => setState(() {
              _selected
                ..clear()
                ..addAll(options.where(selectableNow).map((o) => o.title));
            }),
            child: const Text('全选'),
          ),
          TextButton(
            onPressed: () => setState(_selected.clear),
            child: const Text('清空'),
          ),
          const Spacer(),
          Text('已选 ${_selected.length} 集'),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: _selected.isEmpty
                ? null
                : () {
                    for (final option in options) {
                      if (_selected.contains(option.title) &&
                          option.preferred != null) {
                        ref
                            .read(downloadQueueControllerProvider.notifier)
                            .enqueue(
                              subjectId: widget.subjectId,
                              subjectName: widget.subjectName,
                              episode: option.preferred!,
                            );
                      }
                    }
                    setState(_selected.clear);
                  },
            child: Text('下载选中 ${_selected.length} 集'),
          ),
        ],
      ),
    );
  }
}
