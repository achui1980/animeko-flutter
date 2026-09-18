// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'downloaded_episode_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(downloadedEpisodeRepository)
final downloadedEpisodeRepositoryProvider =
    DownloadedEpisodeRepositoryProvider._();

final class DownloadedEpisodeRepositoryProvider
    extends
        $FunctionalProvider<
          DownloadedEpisodeRepository,
          DownloadedEpisodeRepository,
          DownloadedEpisodeRepository
        >
    with $Provider<DownloadedEpisodeRepository> {
  DownloadedEpisodeRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'downloadedEpisodeRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$downloadedEpisodeRepositoryHash();

  @$internal
  @override
  $ProviderElement<DownloadedEpisodeRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DownloadedEpisodeRepository create(Ref ref) {
    return downloadedEpisodeRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DownloadedEpisodeRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DownloadedEpisodeRepository>(value),
    );
  }
}

String _$downloadedEpisodeRepositoryHash() =>
    r'8c59fb4b8715bbee55b4c216263d680821e61ec3';

@ProviderFor(downloadedEpisodeByKey)
final downloadedEpisodeByKeyProvider = DownloadedEpisodeByKeyFamily._();

final class DownloadedEpisodeByKeyProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  DownloadedEpisodeByKeyProvider._({
    required DownloadedEpisodeByKeyFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'downloadedEpisodeByKeyProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$downloadedEpisodeByKeyHash();

  @override
  String toString() {
    return r'downloadedEpisodeByKeyProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    final argument = this.argument as String;
    return downloadedEpisodeByKey(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is DownloadedEpisodeByKeyProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$downloadedEpisodeByKeyHash() =>
    r'1eb4cfd2aa1178f97633a4f92f0b28db6a0338ad';

final class DownloadedEpisodeByKeyFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<bool>, String> {
  DownloadedEpisodeByKeyFamily._()
    : super(
        retry: null,
        name: r'downloadedEpisodeByKeyProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  DownloadedEpisodeByKeyProvider call(String episodeKey) =>
      DownloadedEpisodeByKeyProvider._(argument: episodeKey, from: this);

  @override
  String toString() => r'downloadedEpisodeByKeyProvider';
}

@ProviderFor(downloadedEpisodeForEpisode)
final downloadedEpisodeForEpisodeProvider =
    DownloadedEpisodeForEpisodeFamily._();

final class DownloadedEpisodeForEpisodeProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  DownloadedEpisodeForEpisodeProvider._({
    required DownloadedEpisodeForEpisodeFamily super.from,
    required (int, String) super.argument,
  }) : super(
         retry: null,
         name: r'downloadedEpisodeForEpisodeProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$downloadedEpisodeForEpisodeHash();

  @override
  String toString() {
    return r'downloadedEpisodeForEpisodeProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    final argument = this.argument as (int, String);
    return downloadedEpisodeForEpisode(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is DownloadedEpisodeForEpisodeProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$downloadedEpisodeForEpisodeHash() =>
    r'2cc9685199b15f611e4e8dec45c9fc27ea75a5a0';

final class DownloadedEpisodeForEpisodeFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<bool>, (int, String)> {
  DownloadedEpisodeForEpisodeFamily._()
    : super(
        retry: null,
        name: r'downloadedEpisodeForEpisodeProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  DownloadedEpisodeForEpisodeProvider call(
    int subjectId,
    String episodeTitle,
  ) => DownloadedEpisodeForEpisodeProvider._(
    argument: (subjectId, episodeTitle),
    from: this,
  );

  @override
  String toString() => r'downloadedEpisodeForEpisodeProvider';
}
