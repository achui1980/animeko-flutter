import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'last_played_episode_storage.g.dart';

const _keyPrefix = 'lastPlayedEpisode:';

/// Remembers which episode was last *started* for a subject, so the
/// detail page's primary button can say 「继续观看 第 N 集」 instead of
/// always 「开始观看」.
///
/// This is deliberately NOT a watched/unwatched progress system: the
/// backend exposes no per-episode collection state (probed -- see the
/// design doc's 「后端接口实测结果」 section), and `PlaybackPositionStorage`
/// (`lib/data/play/playback_position_storage.dart`) is keyed on an opaque
/// `subjectId::sourceId::title` string that cannot be mapped back to a
/// Bangumi `episodeId`. So this stores exactly one `int` per subject and
/// nothing else. Local-only, no cloud sync, same as
/// `PlaybackPositionStorage`.
class LastPlayedEpisodeStorage {
  LastPlayedEpisodeStorage(this._prefs);
  final SharedPreferences _prefs;

  /// The Bangumi `episodeId` last started for [subjectId], or null when
  /// this subject has never been played on this device.
  int? get(int subjectId) => _prefs.getInt('$_keyPrefix$subjectId');

  Future<void> set(int subjectId, int episodeId) async {
    await _prefs.setInt('$_keyPrefix$subjectId', episodeId);
  }
}

@riverpod
Future<LastPlayedEpisodeStorage> lastPlayedEpisodeStorage(Ref ref) async {
  final prefs = await SharedPreferences.getInstance();
  return LastPlayedEpisodeStorage(prefs);
}
