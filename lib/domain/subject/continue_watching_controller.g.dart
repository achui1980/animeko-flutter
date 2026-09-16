// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'continue_watching_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Which episode the detail page's primary button should play.
///
/// * stored episode id still present in the main-episode list -> that
///   episode (button reads 「继续观看 第 N 集」)
/// * nothing stored, or the stored id no longer exists (the subject's
///   episode list changed) -> the first main episode (button reads
///   「开始观看」)
/// * reading the stored id threw -> the first main episode as well, so a
///   broken 「最近播放」 record degrades to 「开始观看」 instead of failing the
///   button (the design doc's failure table, line 340:
///   「`continueWatchingProvider` 失败 → 按钮退回「开始观看」播第一集」)
/// * no main episodes at all -> null, and the caller hides the button
///
/// (The first three branches are the design doc's 「新增『最近播放集数』」
/// section, `docs/superpowers/specs/2026-09-12-subject-detail-three-column-layout-design.md`.)
///
/// A failure to load the episode list itself is deliberately NOT absorbed:
/// there is no episode to fall back to, and line 334 of the same table
/// routes that one to a whole-page `ErrorRetryView`.
///
/// The "stale id" fallback matters because [LastPlayedEpisodeStorage] is
/// never garbage-collected -- it exposes only `get`/`set`, no delete, so a
/// subject can drop episodes and the entry still lingers.
///
/// The result carries no "was this resumed?" flag on purpose: a caller that
/// needs to pick between the two button labels compares this episode's id
/// against `lastPlayedEpisodeStorageProvider`
/// (`lib/data/play/last_played_episode_storage.dart`) itself.

@ProviderFor(continueWatching)
final continueWatchingProvider = ContinueWatchingFamily._();

/// Which episode the detail page's primary button should play.
///
/// * stored episode id still present in the main-episode list -> that
///   episode (button reads 「继续观看 第 N 集」)
/// * nothing stored, or the stored id no longer exists (the subject's
///   episode list changed) -> the first main episode (button reads
///   「开始观看」)
/// * reading the stored id threw -> the first main episode as well, so a
///   broken 「最近播放」 record degrades to 「开始观看」 instead of failing the
///   button (the design doc's failure table, line 340:
///   「`continueWatchingProvider` 失败 → 按钮退回「开始观看」播第一集」)
/// * no main episodes at all -> null, and the caller hides the button
///
/// (The first three branches are the design doc's 「新增『最近播放集数』」
/// section, `docs/superpowers/specs/2026-09-12-subject-detail-three-column-layout-design.md`.)
///
/// A failure to load the episode list itself is deliberately NOT absorbed:
/// there is no episode to fall back to, and line 334 of the same table
/// routes that one to a whole-page `ErrorRetryView`.
///
/// The "stale id" fallback matters because [LastPlayedEpisodeStorage] is
/// never garbage-collected -- it exposes only `get`/`set`, no delete, so a
/// subject can drop episodes and the entry still lingers.
///
/// The result carries no "was this resumed?" flag on purpose: a caller that
/// needs to pick between the two button labels compares this episode's id
/// against `lastPlayedEpisodeStorageProvider`
/// (`lib/data/play/last_played_episode_storage.dart`) itself.

final class ContinueWatchingProvider
    extends
        $FunctionalProvider<
          AsyncValue<SubjectEpisode?>,
          SubjectEpisode?,
          FutureOr<SubjectEpisode?>
        >
    with $FutureModifier<SubjectEpisode?>, $FutureProvider<SubjectEpisode?> {
  /// Which episode the detail page's primary button should play.
  ///
  /// * stored episode id still present in the main-episode list -> that
  ///   episode (button reads 「继续观看 第 N 集」)
  /// * nothing stored, or the stored id no longer exists (the subject's
  ///   episode list changed) -> the first main episode (button reads
  ///   「开始观看」)
  /// * reading the stored id threw -> the first main episode as well, so a
  ///   broken 「最近播放」 record degrades to 「开始观看」 instead of failing the
  ///   button (the design doc's failure table, line 340:
  ///   「`continueWatchingProvider` 失败 → 按钮退回「开始观看」播第一集」)
  /// * no main episodes at all -> null, and the caller hides the button
  ///
  /// (The first three branches are the design doc's 「新增『最近播放集数』」
  /// section, `docs/superpowers/specs/2026-09-12-subject-detail-three-column-layout-design.md`.)
  ///
  /// A failure to load the episode list itself is deliberately NOT absorbed:
  /// there is no episode to fall back to, and line 334 of the same table
  /// routes that one to a whole-page `ErrorRetryView`.
  ///
  /// The "stale id" fallback matters because [LastPlayedEpisodeStorage] is
  /// never garbage-collected -- it exposes only `get`/`set`, no delete, so a
  /// subject can drop episodes and the entry still lingers.
  ///
  /// The result carries no "was this resumed?" flag on purpose: a caller that
  /// needs to pick between the two button labels compares this episode's id
  /// against `lastPlayedEpisodeStorageProvider`
  /// (`lib/data/play/last_played_episode_storage.dart`) itself.
  ContinueWatchingProvider._({
    required ContinueWatchingFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'continueWatchingProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$continueWatchingHash();

  @override
  String toString() {
    return r'continueWatchingProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<SubjectEpisode?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SubjectEpisode?> create(Ref ref) {
    final argument = this.argument as int;
    return continueWatching(ref, subjectId: argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ContinueWatchingProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$continueWatchingHash() => r'ca06688aa6baa291092990e9af1faaaae1377e31';

/// Which episode the detail page's primary button should play.
///
/// * stored episode id still present in the main-episode list -> that
///   episode (button reads 「继续观看 第 N 集」)
/// * nothing stored, or the stored id no longer exists (the subject's
///   episode list changed) -> the first main episode (button reads
///   「开始观看」)
/// * reading the stored id threw -> the first main episode as well, so a
///   broken 「最近播放」 record degrades to 「开始观看」 instead of failing the
///   button (the design doc's failure table, line 340:
///   「`continueWatchingProvider` 失败 → 按钮退回「开始观看」播第一集」)
/// * no main episodes at all -> null, and the caller hides the button
///
/// (The first three branches are the design doc's 「新增『最近播放集数』」
/// section, `docs/superpowers/specs/2026-09-12-subject-detail-three-column-layout-design.md`.)
///
/// A failure to load the episode list itself is deliberately NOT absorbed:
/// there is no episode to fall back to, and line 334 of the same table
/// routes that one to a whole-page `ErrorRetryView`.
///
/// The "stale id" fallback matters because [LastPlayedEpisodeStorage] is
/// never garbage-collected -- it exposes only `get`/`set`, no delete, so a
/// subject can drop episodes and the entry still lingers.
///
/// The result carries no "was this resumed?" flag on purpose: a caller that
/// needs to pick between the two button labels compares this episode's id
/// against `lastPlayedEpisodeStorageProvider`
/// (`lib/data/play/last_played_episode_storage.dart`) itself.

final class ContinueWatchingFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<SubjectEpisode?>, int> {
  ContinueWatchingFamily._()
    : super(
        retry: null,
        name: r'continueWatchingProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Which episode the detail page's primary button should play.
  ///
  /// * stored episode id still present in the main-episode list -> that
  ///   episode (button reads 「继续观看 第 N 集」)
  /// * nothing stored, or the stored id no longer exists (the subject's
  ///   episode list changed) -> the first main episode (button reads
  ///   「开始观看」)
  /// * reading the stored id threw -> the first main episode as well, so a
  ///   broken 「最近播放」 record degrades to 「开始观看」 instead of failing the
  ///   button (the design doc's failure table, line 340:
  ///   「`continueWatchingProvider` 失败 → 按钮退回「开始观看」播第一集」)
  /// * no main episodes at all -> null, and the caller hides the button
  ///
  /// (The first three branches are the design doc's 「新增『最近播放集数』」
  /// section, `docs/superpowers/specs/2026-09-12-subject-detail-three-column-layout-design.md`.)
  ///
  /// A failure to load the episode list itself is deliberately NOT absorbed:
  /// there is no episode to fall back to, and line 334 of the same table
  /// routes that one to a whole-page `ErrorRetryView`.
  ///
  /// The "stale id" fallback matters because [LastPlayedEpisodeStorage] is
  /// never garbage-collected -- it exposes only `get`/`set`, no delete, so a
  /// subject can drop episodes and the entry still lingers.
  ///
  /// The result carries no "was this resumed?" flag on purpose: a caller that
  /// needs to pick between the two button labels compares this episode's id
  /// against `lastPlayedEpisodeStorageProvider`
  /// (`lib/data/play/last_played_episode_storage.dart`) itself.

  ContinueWatchingProvider call({required int subjectId}) =>
      ContinueWatchingProvider._(argument: subjectId, from: this);

  @override
  String toString() => r'continueWatchingProvider';
}
