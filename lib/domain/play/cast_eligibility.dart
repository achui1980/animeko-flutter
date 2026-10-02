import '../../data/agedm/agedm_models.dart';
import '../../data/dilidili/dilidili_models.dart';
import '../../data/omofun/omofun_models.dart';
import '../../data/xifan/xifan_models.dart';
import '../../data/yinghua/yinghua_models.dart';
import '../media/media_source.dart';

/// Whether [source] can be cast to an AirPlay receiver.
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
bool isCastable(MediaPlaybackSource source) {
  return source is XifanPlaybackSource ||
      source is AgedmPlaybackSource ||
      source is OmofunPlaybackSource ||
      source is YinghuaPlaybackSource ||
      source is DilidiliPlaybackSource;
}
