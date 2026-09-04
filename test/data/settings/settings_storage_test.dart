import 'package:animeko_flutter/data/settings/settings_storage.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SettingsStorage', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('getProxyUrl returns null when nothing is stored', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = SettingsStorage(prefs);
      expect(storage.getProxyUrl(), isNull);
    });

    test('setProxyUrl persists and getProxyUrl reads it back', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = SettingsStorage(prefs);
      await storage.setProxyUrl('http://127.0.0.1:2222');
      expect(storage.getProxyUrl(), 'http://127.0.0.1:2222');
    });

    test('setProxyUrl(null) clears a previously stored value', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = SettingsStorage(prefs);
      await storage.setProxyUrl('http://127.0.0.1:2222');
      await storage.setProxyUrl(null);
      expect(storage.getProxyUrl(), isNull);
    });

    group('theme mode', () {
      test('getThemeMode returns null when nothing is stored', () async {
        final prefs = await SharedPreferences.getInstance();
        final storage = SettingsStorage(prefs);
        expect(storage.getThemeMode(), isNull);
      });

      test('setThemeMode persists and getThemeMode reads it back', () async {
        final prefs = await SharedPreferences.getInstance();
        final storage = SettingsStorage(prefs);
        await storage.setThemeMode(ThemeMode.dark);
        expect(storage.getThemeMode(), ThemeMode.dark);
      });

      test('getThemeMode returns null for an unrecognized stored value', () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('theme_mode', 'bogus');
        final storage = SettingsStorage(prefs);
        expect(storage.getThemeMode(), isNull);
      });

      test('setThemeMode(ThemeMode.system) round-trips', () async {
        final prefs = await SharedPreferences.getInstance();
        final storage = SettingsStorage(prefs);
        await storage.setThemeMode(ThemeMode.system);
        expect(storage.getThemeMode(), ThemeMode.system);
      });
    });

    group('playback speed', () {
      test('getPlaybackSpeed returns 1.0 when nothing is stored', () async {
        final prefs = await SharedPreferences.getInstance();
        final storage = SettingsStorage(prefs);
        expect(storage.getPlaybackSpeed(), 1.0);
      });

      test('setPlaybackSpeed persists and getPlaybackSpeed reads it back', () async {
        final prefs = await SharedPreferences.getInstance();
        final storage = SettingsStorage(prefs);
        await storage.setPlaybackSpeed(1.5);
        expect(storage.getPlaybackSpeed(), 1.5);
      });
    });

    group('dynamic color', () {
      test('getUseDynamicColor returns false when nothing is stored', () async {
        final prefs = await SharedPreferences.getInstance();
        final storage = SettingsStorage(prefs);
        expect(storage.getUseDynamicColor(), false);
      });

      test('setUseDynamicColor persists and getUseDynamicColor reads it back', () async {
        final prefs = await SharedPreferences.getInstance();
        final storage = SettingsStorage(prefs);
        await storage.setUseDynamicColor(true);
        expect(storage.getUseDynamicColor(), true);
      });
    });

    group('seed color', () {
      test('getSeedColorValue returns null when nothing is stored', () async {
        final prefs = await SharedPreferences.getInstance();
        final storage = SettingsStorage(prefs);
        expect(storage.getSeedColorValue(), isNull);
      });

      test('setSeedColorValue persists and getSeedColorValue reads it back', () async {
        final prefs = await SharedPreferences.getInstance();
        final storage = SettingsStorage(prefs);
        await storage.setSeedColorValue(0xFF00FF00);
        expect(storage.getSeedColorValue(), 0xFF00FF00);
      });
    });
  });
}
