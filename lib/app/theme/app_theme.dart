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

  static ThemeData light({Color seedColor = kSeedColor}) => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
    ),
  );

  static ThemeData dark({Color seedColor = kSeedColor}) => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
    ),
  );

  /// Builds a theme directly from a platform-provided dynamic
  /// [ColorScheme] (see `DynamicColorBuilder` in `main.dart`), bypassing
  /// [kSeedColor]/[light]/[dark] entirely.
  static ThemeData fromDynamicColorScheme(ColorScheme colorScheme) => ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
  );
}
