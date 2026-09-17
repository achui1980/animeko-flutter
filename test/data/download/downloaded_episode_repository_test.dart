import 'dart:io';

import 'package:animeko_flutter/data/download/downloaded_episode_repository.dart';
import 'package:animeko_flutter/data/local_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late DownloadedEpisodeRepository repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = DownloadedEpisodeRepository(db);
  });

  tearDown(() => db.close());

  test('upsert replaces the record with the same episode key', () async {
    await repository.upsert(
      const DownloadedEpisodeWrite(
        sourceId: 'xifan',
        subjectId: 1,
        episodeKey: '1::xifan::1',
        subjectName: '测试番剧',
        episodeLabel: '1',
        localPath: '/tmp/one.mp4',
        format: 'mp4',
        status: DownloadStatus.downloading,
      ),
    );
    await repository.upsert(
      const DownloadedEpisodeWrite(
        sourceId: 'xifan',
        subjectId: 1,
        episodeKey: '1::xifan::1',
        subjectName: '测试番剧',
        episodeLabel: '1',
        localPath: '/tmp/one.mp4',
        format: 'mp4',
        status: DownloadStatus.completed,
        fileSizeBytes: 100,
      ),
    );

    final rows = await repository.getAll();
    expect(rows, hasLength(1));
    expect(rows.single.status, DownloadStatus.completed.name);
    expect(rows.single.fileSizeBytes, 100);
  });

  test('findCompleted returns only a completed local file', () async {
    await repository.upsert(
      const DownloadedEpisodeWrite(
        sourceId: 'anime1',
        subjectId: 2,
        episodeKey: '2::anime1::2',
        subjectName: '测试番剧',
        episodeLabel: '2',
        localPath: '/tmp/two.mp4',
        format: 'mp4',
        status: DownloadStatus.failed,
        errorMessage: '403',
      ),
    );

    expect(await repository.findCompleted('2::anime1::2'), isNull);
  });

  test('delete removes the matching record', () async {
    await repository.upsert(
      const DownloadedEpisodeWrite(
        sourceId: 'xifan',
        subjectId: 3,
        episodeKey: '3::xifan::3',
        subjectName: '测试番剧',
        episodeLabel: '3',
        localPath: '/tmp/three.mp4',
        format: 'mp4',
        status: DownloadStatus.completed,
      ),
    );

    await repository.delete('3::xifan::3');

    expect(await repository.findByKey('3::xifan::3'), isNull);
  });

  test('watchAll emits downloads ordered by newest first', () async {
    final first = DateTime(2026, 9, 17, 10);
    var now = first;
    repository = DownloadedEpisodeRepository(db, now: () => now);
    await repository.upsert(
      const DownloadedEpisodeWrite(
        sourceId: 'anime1',
        subjectId: 1,
        episodeKey: '1::anime1::1',
        subjectName: '第一部',
        episodeLabel: '1',
        localPath: '/tmp/one.mp4',
        format: 'mp4',
        status: DownloadStatus.completed,
      ),
    );
    now = first.add(const Duration(minutes: 1));
    await repository.upsert(
      const DownloadedEpisodeWrite(
        sourceId: 'xifan',
        subjectId: 2,
        episodeKey: '2::xifan::2',
        subjectName: '第二部',
        episodeLabel: '2',
        localPath: '/tmp/two.mp4',
        format: 'mp4',
        status: DownloadStatus.failed,
      ),
    );

    final rows = await repository.watchAll().first;

    expect(rows.map((row) => row.episodeKey), ['2::xifan::2', '1::anime1::1']);
  });

  test(
    'reconcileInterrupted marks every downloading row as interrupted',
    () async {
      await repository.upsert(
        const DownloadedEpisodeWrite(
          sourceId: 'anime1',
          subjectId: 1,
          episodeKey: '1::anime1::1',
          subjectName: '测试番剧',
          episodeLabel: '1',
          localPath: '/tmp/one',
          format: 'mp4',
          status: DownloadStatus.downloading,
        ),
      );
      await repository.upsert(
        const DownloadedEpisodeWrite(
          sourceId: 'xifan',
          subjectId: 2,
          episodeKey: '2::xifan::2',
          subjectName: '测试番剧2',
          episodeLabel: '2',
          localPath: '/tmp/two.mp4',
          format: 'mp4',
          status: DownloadStatus.completed,
        ),
      );

      await repository.reconcileInterrupted();

      final rows = await repository.getAll();
      final one = rows.firstWhere((row) => row.episodeKey == '1::anime1::1');
      final two = rows.firstWhere((row) => row.episodeKey == '2::xifan::2');
      expect(one.status, DownloadStatus.interrupted.name);
      expect(two.status, DownloadStatus.completed.name);
    },
  );

  test('findCompletedForEpisode ignores sourceId', () async {
    await repository.upsert(
      const DownloadedEpisodeWrite(
        sourceId: 'anime1',
        subjectId: 1,
        episodeKey: '1::anime1::第6话',
        subjectName: '测试番剧',
        episodeLabel: '第6话',
        localPath: '/tmp/six.mp4',
        format: 'mp4',
        status: DownloadStatus.completed,
      ),
    );

    // Currently playing from a *different* source (e.g. mikan) than the
    // one the file was actually downloaded from (anime1) -- automatic
    // source selection (see download_source_resolver.dart) means this
    // mismatch is expected, not a bug.
    final found = await repository.findCompletedForEpisode(1, '第6话');
    expect(found, isNotNull);
    expect(found!.sourceId, 'anime1');

    expect(await repository.findCompletedForEpisode(1, '第7话'), isNull);
    expect(await repository.findCompletedForEpisode(2, '第6话'), isNull);
  });

  test('deleteWithFiles removes the record and its directory', () async {
    final dir = await Directory.systemTemp.createTemp('repo_delete_test_');
    addTearDown(() async {
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    });
    final file = File('${dir.path}/video.mp4');
    await file.writeAsBytes([1, 2, 3]);
    await repository.upsert(
      DownloadedEpisodeWrite(
        sourceId: 'anime1',
        subjectId: 1,
        episodeKey: '1::anime1::1',
        subjectName: '测试番剧',
        episodeLabel: '1',
        localPath: file.path,
        format: 'mp4',
        status: DownloadStatus.completed,
        episodeDir: dir.path,
      ),
    );

    await repository.deleteWithFiles('1::anime1::1');

    expect(await repository.findByKey('1::anime1::1'), isNull);
    expect(await dir.exists(), isFalse);
  });

  test('deleteWithFiles is a no-op for an unknown key', () async {
    await repository.deleteWithFiles('missing::key::1');
    // No exception -- nothing to assert beyond "did not throw".
  });

  test('updateProgress writes byte progress and bumps lastProgressAt', () async {
    var now = DateTime(2026, 9, 17, 10);
    repository = DownloadedEpisodeRepository(db, now: () => now);
    await repository.upsert(
      const DownloadedEpisodeWrite(
        sourceId: 'anime1',
        subjectId: 1,
        episodeKey: '1::anime1::1',
        subjectName: '测试番剧',
        episodeLabel: '1',
        localPath: '/tmp/one',
        episodeDir: '/tmp/one',
        format: 'mp4',
        status: DownloadStatus.downloading,
      ),
    );

    now = now.add(const Duration(seconds: 5));
    await repository.updateProgress(
      '1::anime1::1',
      receivedBytes: 512,
      totalBytes: 2048,
    );

    final row = await repository.findByKey('1::anime1::1');
    expect(row!.receivedBytes, 512);
    expect(row.totalBytes, 2048);
    expect(row.downloadedSegments, isNull);
    expect(row.totalSegments, isNull);
    expect(row.lastProgressAt, now);
  });

  test('updateProgress writes segment progress for HLS downloads', () async {
    await repository.upsert(
      const DownloadedEpisodeWrite(
        sourceId: 'anime1',
        subjectId: 1,
        episodeKey: '1::anime1::1',
        subjectName: '测试番剧',
        episodeLabel: '1',
        localPath: '/tmp/one',
        episodeDir: '/tmp/one',
        format: 'hls',
        status: DownloadStatus.downloading,
      ),
    );

    await repository.updateProgress(
      '1::anime1::1',
      downloadedSegments: 3,
      totalSegments: 12,
    );

    final row = await repository.findByKey('1::anime1::1');
    expect(row!.downloadedSegments, 3);
    expect(row.totalSegments, 12);
    expect(row.receivedBytes, 0);
    expect(row.totalBytes, isNull);
  });
}
