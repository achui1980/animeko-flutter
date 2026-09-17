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
}
