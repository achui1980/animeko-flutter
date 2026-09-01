// lib/data/settings/settings_storage.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'settings_storage.g.dart';

const _proxyUrlKey = 'proxy_url';

/// Thin wrapper around [SharedPreferences] for simple app settings that
/// don't need [SecureTokenStorage]'s encryption -- a proxy URL is not
/// sensitive credential material.
class SettingsStorage {
  SettingsStorage(this._prefs);
  final SharedPreferences _prefs;

  /// Returns the persisted proxy URL, or `null` if none is set (direct
  /// connection).
  String? getProxyUrl() => _prefs.getString(_proxyUrlKey);

  /// Persists [url] as the proxy URL. Passing `null` clears it (reverts to
  /// direct connection).
  Future<void> setProxyUrl(String? url) async {
    if (url == null) {
      await _prefs.remove(_proxyUrlKey);
    } else {
      await _prefs.setString(_proxyUrlKey, url);
    }
  }
}

@riverpod
Future<SettingsStorage> settingsStorage(Ref ref) async {
  final prefs = await SharedPreferences.getInstance();
  return SettingsStorage(prefs);
}
