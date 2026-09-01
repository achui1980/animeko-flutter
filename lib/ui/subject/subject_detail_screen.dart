// lib/ui/subject/subject_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
                    trailing: Chip(label: Text(_sourceLabel(episode.sourceId))),
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
/// (Decision 6). Falls back to the raw `sourceId` for any future source
/// that forgets to add a case here -- never crashes, just looks slightly
/// less polished.
String _sourceLabel(String sourceId) {
  switch (sourceId) {
    case 'anime1':
      return 'anime1.me';
    case 'xifan':
      return '稀饭动漫';
    default:
      return sourceId;
  }
}
