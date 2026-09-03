import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'playback_position_storage.g.dart';

const _keyPrefix = 'playback_position_';

/// Persists "resume from where I left off" playback positions, keyed by
/// an opaque per-episode string the caller constructs (see
/// `PlayerScreen._positionKey`). Local-only -- no cloud sync (see the
/// playback feature backlog doc's rationale for skipping the reference
/// app's Bangumi-account-tied sync for now).
class PlaybackPositionStorage {
  PlaybackPositionStorage(this._prefs);
  final SharedPreferences _prefs;

  /// Returns the last saved position for [key], in milliseconds, or
  /// `null` if none is stored.
  int? getPosition(String key) => _prefs.getInt('$_keyPrefix$key');

  /// Persists [positionMs] as the last playback position for [key].
  Future<void> setPosition(String key, int positionMs) async {
    await _prefs.setInt('$_keyPrefix$key', positionMs);
  }

  /// Clears the saved position for [key] (e.g. once an episode finishes).
  Future<void> clearPosition(String key) async {
    await _prefs.remove('$_keyPrefix$key');
  }
}

@riverpod
Future<PlaybackPositionStorage> playbackPositionStorage(Ref ref) async {
  final prefs = await SharedPreferences.getInstance();
  return PlaybackPositionStorage(prefs);
}
