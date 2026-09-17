import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/settings/settings_storage.dart';

part 'download_settings_controller.g.dart';

@riverpod
Future<String> defaultDownloadDirectory(Ref ref) async {
  final support = await getApplicationSupportDirectory();
  final directory = Directory(p.join(support.path, 'downloads'));
  await directory.create(recursive: true);
  return directory.path;
}

@riverpod
class DownloadSettingsController extends _$DownloadSettingsController {
  @override
  Future<String> build() async {
    ref.keepAlive();
    final storage = await ref.watch(settingsStorageProvider.future);
    return storage.getDownloadDirectory() ??
        await ref.watch(defaultDownloadDirectoryProvider.future);
  }

  Future<void> setDownloadDirectory(String path) async {
    final directory = Directory(path);
    if (!await directory.exists()) {
      throw ArgumentError.value(path, 'path', '目录不存在');
    }
    final storage = await ref.read(settingsStorageProvider.future);
    await storage.setDownloadDirectory(path);
    state = AsyncData(path);
  }
}
