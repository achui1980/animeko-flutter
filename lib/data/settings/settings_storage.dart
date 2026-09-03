// lib/data/settings/settings_storage.dart
import 'package:flutter/material.dart' show ThemeMode;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'settings_storage.g.dart';

const _proxyUrlKey = 'proxy_url';
const _themeModeKey = 'theme_mode';
const _playbackSpeedKey = 'playback_speed';

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

  /// Returns the persisted [ThemeMode], or `null` if none is set or the
  /// stored value is unrecognized.
  ThemeMode? getThemeMode() {
    final value = _prefs.getString(_themeModeKey);
    switch (value) {
      case 'system':
        return ThemeMode.system;
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return null;
    }
  }

  /// Persists [mode] as the selected theme mode.
  Future<void> setThemeMode(ThemeMode mode) async {
    await _prefs.setString(_themeModeKey, mode.name);
  }

  /// Returns the persisted playback speed multiplier, or `1.0` if none is
  /// set (normal speed).
  double getPlaybackSpeed() => _prefs.getDouble(_playbackSpeedKey) ?? 1.0;

  /// Persists [speed] as the selected playback speed multiplier.
  Future<void> setPlaybackSpeed(double speed) async {
    await _prefs.setDouble(_playbackSpeedKey, speed);
  }
}

@riverpod
Future<SettingsStorage> settingsStorage(Ref ref) async {
  final prefs = await SharedPreferences.getInstance();
  return SettingsStorage(prefs);
}
