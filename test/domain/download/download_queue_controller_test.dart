import 'package:animeko_flutter/data/download/downloaded_episode_repository.dart';
import 'package:animeko_flutter/data/download/download_worker.dart';
import 'package:animeko_flutter/data/local_database.dart';
import 'package:animeko_flutter/domain/download/download_queue_controller.dart';
import 'package:animeko_flutter/domain/media/media_registry.dart';
import 'package:animeko_flutter/domain/media/media_source.dart';
import 'package:animeko_flutter/data/settings/settings_storage.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class _SettingsStorage extends Mock implements SettingsStorage {}

class _Episode implements MediaEpisode {
  const _Episode(this.sourceId, this.title);

  @override
  final String sourceId;

  @override
  final String title;
}

const request = DownloadRequest(
  subjectId: 1,
  subjectName: 'Subject',
  sourceId: 'xifan',
  episode: _Episode('xifan', '1'),
  episodeLabel: 'Episode 1',
);

void main() {
  late AppDatabase database;
  late ProviderContainer container;
  late _SettingsStorage settingsStorage;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    settingsStorage = _SettingsStorage();
    when(settingsStorage.getDownloadDirectory).thenReturn('/downloads');
    container = ProviderContainer(
      overrides: [
        settingsStorageProvider.overrideWith((ref) async => settingsStorage),
        mediaSourcesProvider.overrideWithValue(const []),
        downloadDioProvider.overrideWithValue(Dio()),
        downloadedEpisodeRepositoryProvider.overrideWithValue(
          DownloadedEpisodeRepository(database),
        ),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(database.close);
  });

  test('maps worker progress into state indexed by episode key', () async {
    final subscription = container.listen(
      downloadQueueControllerProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);
    await container.read(downloadQueueControllerProvider.future);
    final controller = container.read(downloadQueueControllerProvider.notifier);

    controller.emit(const DownloadProgress(request, 50, 100));
    await container.pump();

    expect(
      container
          .read(downloadQueueControllerProvider)
          .value!['1::xifan::1']!
          .progress,
      .5,
    );
  });

  test('maps worker statuses and removes cancelled entries', () async {
    final subscription = container.listen(
      downloadQueueControllerProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);
    await container.read(downloadQueueControllerProvider.future);
    final controller = container.read(downloadQueueControllerProvider.notifier);

    controller.emit(const DownloadQueued(request));
    expect(
      container
          .read(downloadQueueControllerProvider)
          .value!['1::xifan::1']!
          .status,
      DownloadQueueStatus.queued,
    );

    controller.emit(const DownloadCompleted(request));
    expect(
      container
          .read(downloadQueueControllerProvider)
          .value!['1::xifan::1']!
          .status,
      DownloadQueueStatus.completed,
    );

    controller.emit(const DownloadFailed(request, 'network error'));
    final failed = container
        .read(downloadQueueControllerProvider)
        .value!['1::xifan::1']!;
    expect(failed.status, DownloadQueueStatus.failed);
    expect(failed.errorMessage, 'network error');

    controller.emit(const DownloadCancelled(request));
    expect(
      container.read(downloadQueueControllerProvider).value,
      isNot(contains('1::xifan::1')),
    );
  });
}
