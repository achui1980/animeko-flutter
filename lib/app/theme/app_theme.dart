import 'package:flutter/material.dart';

/// The app's seed color, matching the reference Animeko (Kotlin/Compose)
/// app's `DefaultSeedColor` (`app/shared/app-platform/.../DefaultSeedColor.kt`).
const kSeedColor = Color(0xFF4F378B);

/// Builds the app's Material 3 theme from [kSeedColor].
///
/// Typography and shape scales are intentionally left at the Flutter M3
/// defaults: the reference app does the same (it only swaps the font
/// family, which this app does not currently customize). See the design
/// doc's "主题系统" section for details.
class AppTheme {
  AppTheme._();

  static ThemeData light() => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: kSeedColor,
      brightness: Brightness.light,
    ),
  );

  static ThemeData dark() => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: kSeedColor,
      brightness: Brightness.dark,
    ),
  );
}
