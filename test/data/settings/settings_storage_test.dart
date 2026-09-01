import 'package:animeko_flutter/data/settings/settings_storage.dart';
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
  });
}
