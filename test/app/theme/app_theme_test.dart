import 'package:animeko_flutter/app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('kSeedColor matches the reference Animeko app seed color', () {
    expect(kSeedColor, const Color(0xFF4F378B));
  });

  test('AppTheme.light() builds a Material 3 light theme', () {
    final theme = AppTheme.light();
    expect(theme.useMaterial3, isTrue);
    expect(theme.brightness, Brightness.light);
    expect(theme.colorScheme.brightness, Brightness.light);
  });

  test('AppTheme.dark() builds a Material 3 dark theme', () {
    final theme = AppTheme.dark();
    expect(theme.useMaterial3, isTrue);
    expect(theme.brightness, Brightness.dark);
    expect(theme.colorScheme.brightness, Brightness.dark);
  });

  test('both themes derive a non-null primary color from the seed', () {
    expect(AppTheme.light().colorScheme.primary, isNotNull);
    expect(AppTheme.dark().colorScheme.primary, isNotNull);
  });
}
