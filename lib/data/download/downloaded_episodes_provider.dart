import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'downloaded_episode_repository.dart';

part 'downloaded_episodes_provider.g.dart';

class DownloadedEpisodeSummary {
  const DownloadedEpisodeSummary({
    required this.sourceId,
    required this.subjectId,
    required this.episodeKey,
    required this.subjectName,
    required this.episodeLabel,
    required this.localPath,
    required this.status,
    required this.errorMessage,
  });

  final String sourceId;
  final int subjectId;
  final String episodeKey;
  final String subjectName;
  final String episodeLabel;
  final String localPath;
  final String status;
  final String? errorMessage;
}

@riverpod
Stream<List<DownloadedEpisodeSummary>> downloadedEpisodes(Ref ref) => ref
    .watch(downloadedEpisodeRepositoryProvider)
    .watchAll()
    .map(
      (rows) => rows
          .map(
            (row) => DownloadedEpisodeSummary(
              sourceId: row.sourceId,
              subjectId: row.subjectId,
              episodeKey: row.episodeKey,
              subjectName: row.subjectName,
              episodeLabel: row.episodeLabel,
              localPath: row.localPath,
              status: row.status,
              errorMessage: row.errorMessage,
            ),
          )
          .toList(),
    );
