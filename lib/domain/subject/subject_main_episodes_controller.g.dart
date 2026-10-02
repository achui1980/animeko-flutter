// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subject_main_episodes_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
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
///  * The "is this watchable" test is now `type == 'MAIN' || type ==
///    'SPECIAL'` (see [SubjectEpisode.isPlayable]) rather than Bangumi's
///    numeric `type == 0`. SPECIAL is where theatrical movies/剧场版 and
///    extra specials land, since this API has no dedicated movie type, so
///    it merges into the grid alongside MAIN. OP/ED stay excluded --
///    they're theme songs, not watchable content.

@ProviderFor(SubjectMainEpisodesController)
final subjectMainEpisodesControllerProvider =
    SubjectMainEpisodesControllerFamily._();

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
///  * The "is this watchable" test is now `type == 'MAIN' || type ==
///    'SPECIAL'` (see [SubjectEpisode.isPlayable]) rather than Bangumi's
///    numeric `type == 0`. SPECIAL is where theatrical movies/剧场版 and
///    extra specials land, since this API has no dedicated movie type, so
///    it merges into the grid alongside MAIN. OP/ED stay excluded --
///    they're theme songs, not watchable content.
final class SubjectMainEpisodesControllerProvider
    extends
        $AsyncNotifierProvider<
          SubjectMainEpisodesController,
          List<SubjectEpisode>
        > {
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
  ///  * The "is this watchable" test is now `type == 'MAIN' || type ==
  ///    'SPECIAL'` (see [SubjectEpisode.isPlayable]) rather than Bangumi's
  ///    numeric `type == 0`. SPECIAL is where theatrical movies/剧场版 and
  ///    extra specials land, since this API has no dedicated movie type, so
  ///    it merges into the grid alongside MAIN. OP/ED stay excluded --
  ///    they're theme songs, not watchable content.
  SubjectMainEpisodesControllerProvider._({
    required SubjectMainEpisodesControllerFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'subjectMainEpisodesControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$subjectMainEpisodesControllerHash();

  @override
  String toString() {
    return r'subjectMainEpisodesControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  SubjectMainEpisodesController create() => SubjectMainEpisodesController();

  @override
  bool operator ==(Object other) {
    return other is SubjectMainEpisodesControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$subjectMainEpisodesControllerHash() =>
    r'b8e48e85209f3d5424947b3de5dff991a473fbae';

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
///  * The "is this watchable" test is now `type == 'MAIN' || type ==
///    'SPECIAL'` (see [SubjectEpisode.isPlayable]) rather than Bangumi's
///    numeric `type == 0`. SPECIAL is where theatrical movies/剧场版 and
///    extra specials land, since this API has no dedicated movie type, so
///    it merges into the grid alongside MAIN. OP/ED stay excluded --
///    they're theme songs, not watchable content.

final class SubjectMainEpisodesControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          SubjectMainEpisodesController,
          AsyncValue<List<SubjectEpisode>>,
          List<SubjectEpisode>,
          FutureOr<List<SubjectEpisode>>,
          int
        > {
  SubjectMainEpisodesControllerFamily._()
    : super(
        retry: null,
        name: r'subjectMainEpisodesControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

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
  ///  * The "is this watchable" test is now `type == 'MAIN' || type ==
  ///    'SPECIAL'` (see [SubjectEpisode.isPlayable]) rather than Bangumi's
  ///    numeric `type == 0`. SPECIAL is where theatrical movies/剧场版 and
  ///    extra specials land, since this API has no dedicated movie type, so
  ///    it merges into the grid alongside MAIN. OP/ED stay excluded --
  ///    they're theme songs, not watchable content.

  SubjectMainEpisodesControllerProvider call({required int subjectId}) =>
      SubjectMainEpisodesControllerProvider._(argument: subjectId, from: this);

  @override
  String toString() => r'subjectMainEpisodesControllerProvider';
}

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
///  * The "is this watchable" test is now `type == 'MAIN' || type ==
///    'SPECIAL'` (see [SubjectEpisode.isPlayable]) rather than Bangumi's
///    numeric `type == 0`. SPECIAL is where theatrical movies/剧场版 and
///    extra specials land, since this API has no dedicated movie type, so
///    it merges into the grid alongside MAIN. OP/ED stay excluded --
///    they're theme songs, not watchable content.

abstract class _$SubjectMainEpisodesController
    extends $AsyncNotifier<List<SubjectEpisode>> {
  late final _$args = ref.$arg as int;
  int get subjectId => _$args;

  FutureOr<List<SubjectEpisode>> build({required int subjectId});
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<List<SubjectEpisode>>, List<SubjectEpisode>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<SubjectEpisode>>,
                List<SubjectEpisode>
              >,
              AsyncValue<List<SubjectEpisode>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(subjectId: _$args));
  }
}
