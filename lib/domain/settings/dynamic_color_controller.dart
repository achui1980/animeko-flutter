import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/settings/settings_storage.dart';

part 'dynamic_color_controller.g.dart';

@riverpod
class DynamicColorController extends _$DynamicColorController {
  @override
  Future<bool> build() async {
    final storage = await ref.watch(settingsStorageProvider.future);
    return storage.getUseDynamicColor();
  }

  Future<void> setUseDynamicColor(bool enabled) async {
    final storage = await ref.read(settingsStorageProvider.future);
    await storage.setUseDynamicColor(enabled);
    state = AsyncData(enabled);
  }
}
