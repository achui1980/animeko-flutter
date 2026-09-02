import 'package:flutter/material.dart' show ThemeMode;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/settings/settings_storage.dart';

part 'theme_mode_controller.g.dart';

@riverpod
class ThemeModeController extends _$ThemeModeController {
  @override
  Future<ThemeMode> build() async {
    final storage = await ref.watch(settingsStorageProvider.future);
    return storage.getThemeMode() ?? ThemeMode.system;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final storage = await ref.read(settingsStorageProvider.future);
    await storage.setThemeMode(mode);
    state = AsyncData(mode);
  }
}
