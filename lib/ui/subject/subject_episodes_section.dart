import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/play/subject_episodes_controller.dart';
import '../../domain/subject/subject_detail_controller.dart';
import '../../domain/subject/subject_main_episodes_controller.dart';
import '../common/error_retry_view.dart';
import 'episode_number_grid.dart';
import 'episode_playback_sheet.dart';
import 'subject_meta_text.dart';

/// 中栏的「选集」区块：标题行（左「选集」，右「连载至 NN · 预定全 NN 话」）
/// + `EpisodeNumberGrid`。
///
/// 标题右侧的进度文案和标题区 meta 行用的是同一个纯函数
/// [formatEpisodeProgress]，不重复实现。
class SubjectEpisodesSection extends ConsumerWidget {
  const SubjectEpisodesSection({
    super.key,
    required this.subjectId,
    required this.subjectName,
    this.now,
  });

  final int subjectId;
  final String subjectName;

  /// 仅测试用：固定「今天」，让「连载至 NN」可断言。
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final episodesAsync = ref.watch(
      subjectMainEpisodesControllerProvider(subjectId: subjectId),
    );
    final mergedEpisodesAsync = ref.watch(
      subjectEpisodesControllerProvider(
        subjectId: subjectId,
        subjectName: subjectName,
      ),
    );
    final episodeCount = ref
        .watch(subjectDetailControllerProvider(subjectId: subjectId))
        .value
        ?.episodeCount;

    return episodesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      // 重试要作废「源」provider（详情接口），而不是这个派生 provider ——
      // 剧集数组是从详情响应里算出来的，作废派生的那个不会重新发请求。
      error: (error, _) => ErrorRetryView(
        message: '加载剧集列表失败：$error',
        onRetry: () => ref.invalidate(
          subjectDetailControllerProvider(subjectId: subjectId),
        ),
      ),
      data: (episodes) {
        if (episodes.isEmpty) return const SizedBox.shrink();
        final progress = formatEpisodeProgress(
          episodes: episodes,
          episodeCount: episodeCount,
          now: now,
        );
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('选集', style: theme.textTheme.titleSmall),
                  const Spacer(),
                  if (progress != null)
                    Text(
                      progress,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              EpisodeNumberGrid(
                episodes: episodes,
                mergedEpisodesAsync: mergedEpisodesAsync,
                onEpisodeTap: (ordinalIndex, episode) =>
                    showModalBottomSheet<void>(
                      context: context,
                      builder: (_) => EpisodePlaybackSheet(
                        subjectId: subjectId,
                        subjectName: subjectName,
                        ordinalIndex: ordinalIndex,
                        episode: episode,
                      ),
                    ),
              ),
            ],
          ),
        );
      },
    );
  }
}
