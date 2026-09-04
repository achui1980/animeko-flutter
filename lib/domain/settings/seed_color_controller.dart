import 'package:flutter/material.dart' show Color;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../app/theme/app_theme.dart';
import '../../data/settings/settings_storage.dart';

part 'seed_color_controller.g.dart';

/// The preset seed colors offered in the settings palette picker, matching
/// the reference Kotlin app's own preset swatches plus [kSeedColor] itself.
const seedColorPresets = <Color>[
  kSeedColor,
  Color(0xFF6750A4),
  Color(0xFF006A6A),
  Color(0xFF8C4A2F),
  Color(0xFF3A608F),
  Color(0xFF7D5260),
];

@riverpod
class SeedColorController extends _$SeedColorController {
  @override
  Future<Color> build() async {
    final storage = await ref.watch(settingsStorageProvider.future);
    final value = storage.getSeedColorValue();
    return value == null ? kSeedColor : Color(value);
  }

  Future<void> setSeedColor(Color color) async {
    final storage = await ref.read(settingsStorageProvider.future);
    await storage.setSeedColorValue(color.toARGB32());
    state = AsyncData(color);
  }
}
