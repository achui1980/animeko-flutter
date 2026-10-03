import 'dart:io' show Platform;

import '../../data/agedm/agedm_models.dart';
import '../../data/dilidili/dilidili_models.dart';
import '../../data/omofun/omofun_models.dart';
import '../../data/xifan/xifan_models.dart';
import '../../data/yinghua/yinghua_models.dart';
import '../media/media_source.dart';

/// Whether [source] can be cast to an AirPlay receiver.
///
/// AirPlay casting is implemented via a macOS-only native plugin
/// (`AVPlayer` + `AVRoutePickerView`, see `macos/Runner/AirPlayCastEngine.swift`
/// / `AirPlayButtonOverlay.swift`) — there is no corresponding native
/// handler registered on Android/Windows/iOS for the
/// `"animeko/airplay_cast"` MethodChannel. [isMacOS] therefore gates
/// castability on the current platform first (defaulting to the real
/// `Platform.isMacOS`, injectable here only for testing, since
/// `Platform.isMacOS` itself can't be overridden from a test): without
/// this gate, a non-macOS build would still construct and show the
/// cast button for an otherwise-castable source, and every tap would
/// throw a `MissingPluginException` instead of casting anything.
///
/// Deliberately an allow-list, not a block-list: an AirPlay receiver in
/// standard "URL mode" fetches the video directly over the network
/// itself and does NOT forward the sending app's custom HTTP headers
/// (see `docs/superpowers/specs/2026-10-02-airplay-casting-design.md`
/// §2 "技术约束"). Only sources confirmed to need no headers, or whose
/// only requirement (direct-connection/no-proxy) is naturally satisfied
/// by the receiver fetching over the LAN itself, are listed here.
///
/// `Anime1PlaybackSource` (confirmed session-cookie 403 without the
/// header), `TorrentPlaybackSource` (BT/Mikan), and
/// `LocalFilePlaybackSource` (downloaded files, including NAS-mounted
/// paths) are excluded by omission — along with any future/unknown
/// `MediaPlaybackSource` subtype — rather than being named here.
bool isCastable(
  MediaPlaybackSource source, {
  bool Function() isMacOS = _realIsMacOS,
}) {
  if (!isMacOS()) return false;
  return source is XifanPlaybackSource ||
      source is AgedmPlaybackSource ||
      source is OmofunPlaybackSource ||
      source is YinghuaPlaybackSource ||
      source is DilidiliPlaybackSource;
}

bool _realIsMacOS() => Platform.isMacOS;
