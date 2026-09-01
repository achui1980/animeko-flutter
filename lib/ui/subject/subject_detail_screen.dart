// lib/ui/subject/subject_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/media/media_registry.dart';
import '../../domain/media/media_source.dart';
import '../../domain/play/subject_episodes_controller.dart';
import '../common/error_retry_view.dart';

class SubjectDetailScreen extends ConsumerWidget {
  const SubjectDetailScreen({
    super.key,
    required this.subjectId,
    required this.subjectName,
    this.imageUrl,
  });

  final int subjectId;
  final String subjectName;
  final String? imageUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = subjectEpisodesControllerProvider(
      subjectId: subjectId,
      subjectName: subjectName,
    );
    final episodes = ref.watch(provider);
    final sources = ref.watch(mediaSourcesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(subjectName)),
      body: Column(
        children: [
          if (imageUrl != null)
            SizedBox(
              height: 160,
              width: double.infinity,
              child: Image.network(imageUrl!, fit: BoxFit.cover),
            ),
          Expanded(
            child: episodes.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) {
                if (error is MediaNotFoundException) {
                  return const Center(child: Text('未找到该番剧的播放资源'));
                }
                return ErrorRetryView(
                  message: '加载失败：$error',
                  onRetry: () => ref.invalidate(provider),
                );
              },
              data: (episodeList) => ListView.builder(
                itemCount: episodeList.length,
                itemBuilder: (context, index) {
                  final episode = episodeList[index];
                  return ListTile(
                    title: Text(episode.title),
                    trailing: Chip(label: Text(_sourceLabel(sources, episode.sourceId))),
                    onTap: () => context.push(
                      '/subject/$subjectId/play',
                      extra: episode,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Human-readable label for the merged-episode-list source badge
/// (Decision 6). Looks up the owning [MediaSource]'s [MediaSource.displayName]
/// so this stays in sync with the single source of truth instead of
/// re-deriving it from a hardcoded switch on `sourceId`. Falls back to the
/// raw `sourceId` for any `sourceId` with no matching registered source --
/// never crashes, just looks slightly less polished.
String _sourceLabel(List<MediaSource> sources, String sourceId) {
  for (final source in sources) {
    if (source.id == sourceId) return source.displayName;
  }
  return sourceId;
}
