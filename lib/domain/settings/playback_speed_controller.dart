import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/settings/settings_storage.dart';

part 'playback_speed_controller.g.dart';

@riverpod
class PlaybackSpeedController extends _$PlaybackSpeedController {
  @override
  Future<double> build() async {
    final storage = await ref.watch(settingsStorageProvider.future);
    return storage.getPlaybackSpeed();
  }

  Future<void> setPlaybackSpeed(double speed) async {
    final storage = await ref.read(settingsStorageProvider.future);
    await storage.setPlaybackSpeed(speed);
    state = AsyncData(speed);
  }
}
