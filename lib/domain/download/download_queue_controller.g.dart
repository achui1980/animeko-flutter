// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_queue_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(downloadDio)
final downloadDioProvider = DownloadDioProvider._();

final class DownloadDioProvider extends $FunctionalProvider<Dio, Dio, Dio>
    with $Provider<Dio> {
  DownloadDioProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'downloadDioProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$downloadDioHash();

  @$internal
  @override
  $ProviderElement<Dio> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Dio create(Ref ref) {
    return downloadDio(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Dio value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Dio>(value),
    );
  }
}

String _$downloadDioHash() => r'0d8874d02e666b680c6a42e36ced59e8be247f95';

@ProviderFor(DownloadQueueController)
final downloadQueueControllerProvider = DownloadQueueControllerProvider._();

final class DownloadQueueControllerProvider
    extends
        $AsyncNotifierProvider<
          DownloadQueueController,
          Map<String, DownloadQueueItem>
        > {
  DownloadQueueControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'downloadQueueControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$downloadQueueControllerHash();

  @$internal
  @override
  DownloadQueueController create() => DownloadQueueController();
}

String _$downloadQueueControllerHash() =>
    r'5ecd95ec69746e2f7924baf365007eb7151d0b54';

abstract class _$DownloadQueueController
    extends $AsyncNotifier<Map<String, DownloadQueueItem>> {
  FutureOr<Map<String, DownloadQueueItem>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<Map<String, DownloadQueueItem>>,
              Map<String, DownloadQueueItem>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<Map<String, DownloadQueueItem>>,
                Map<String, DownloadQueueItem>
              >,
              AsyncValue<Map<String, DownloadQueueItem>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
