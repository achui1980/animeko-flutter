// lib/domain/subject/subject_main_episodes_controller.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/subject/subject_episode_models.dart';
import 'subject_detail_controller.dart';

part 'subject_main_episodes_controller.g.dart';

/// The 主线剧集 (main episode) list that drives the episode grid on the
/// subject detail screen.
///
/// Derived purely from [subjectDetailControllerProvider] -- the episode data
/// is already embedded in `GET /v2/subjects/{id}`'s response, so this makes
/// no network request of its own.
///
/// This replaced a controller that called Bangumi's own
/// `https://api.bgm.tv/v0/episodes` directly. That host is DNS-poisoned and
/// SNI-blocked from mainland networks (verified: TCP connects to the real
/// Cloudflare IP, then the TLS ClientHello gets an injected RST purely
/// because of the `api.bgm.tv` SNI -- the same IP handshakes fine with a
/// different SNI). It was the only direct-Bangumi caller in the app, which
/// is why the episode grid was the one thing on this screen that required a
/// proxy while the title, summary, characters and staff all loaded fine.
///
/// Two behaviour changes came with the switch:
///  * No more `limit=100` truncation -- 航海王 now yields all 1155 episodes
///    instead of 100. The grid renders these in segments; see
///    `EpisodeNumberGrid`.
///  * The "is this a 正片" test is now `type == 'MAIN'` rather than Bangumi's
///    numeric `type == 0`.
@riverpod
class SubjectMainEpisodesController extends _$SubjectMainEpisodesController {
  @override
  Future<List<SubjectEpisode>> build({required int subjectId}) async {
    final subject = await ref.watch(
      subjectDetailControllerProvider(subjectId: subjectId).future,
    );

    // A null `episodes` means the response omitted the key entirely; the
    // grid treats "no episodes" and "key absent" identically, so both
    // collapse to an empty list here. (`SubjectDetail.episodeCount` keeps
    // the distinction for the 话数 line.)
    final episodes = subject.episodes;
    if (episodes == null) return const [];

    // The backend returns MAIN and SPECIAL entries interleaved and in no
    // guaranteed order, so sorting is required, not defensive polish.
    return episodes.where((episode) => episode.isMain).toList()
      ..sort((a, b) => a.sort.compareTo(b.sort));
  }
}
