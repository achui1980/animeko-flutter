// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'my_collections_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Backs the "My Collection" library page (Task 11), one instance per
/// segmented-control tab. `type: null` fetches all 5 states -- the UI
/// itself always passes a concrete [CollectionType] (one per tab), but
/// this controller doesn't require that.

@ProviderFor(MyCollectionsController)
final myCollectionsControllerProvider = MyCollectionsControllerFamily._();

/// Backs the "My Collection" library page (Task 11), one instance per
/// segmented-control tab. `type: null` fetches all 5 states -- the UI
/// itself always passes a concrete [CollectionType] (one per tab), but
/// this controller doesn't require that.
final class MyCollectionsControllerProvider
    extends $AsyncNotifierProvider<MyCollectionsController, MyCollectionsPage> {
  /// Backs the "My Collection" library page (Task 11), one instance per
  /// segmented-control tab. `type: null` fetches all 5 states -- the UI
  /// itself always passes a concrete [CollectionType] (one per tab), but
  /// this controller doesn't require that.
  MyCollectionsControllerProvider._({
    required MyCollectionsControllerFamily super.from,
    required CollectionType? super.argument,
  }) : super(
         retry: null,
         name: r'myCollectionsControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$myCollectionsControllerHash();

  @override
  String toString() {
    return r'myCollectionsControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  MyCollectionsController create() => MyCollectionsController();

  @override
  bool operator ==(Object other) {
    return other is MyCollectionsControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$myCollectionsControllerHash() =>
    r'f56c9c4d405dc1db6615e8c0ceb8e2b2b6f199a2';

/// Backs the "My Collection" library page (Task 11), one instance per
/// segmented-control tab. `type: null` fetches all 5 states -- the UI
/// itself always passes a concrete [CollectionType] (one per tab), but
/// this controller doesn't require that.

final class MyCollectionsControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          MyCollectionsController,
          AsyncValue<MyCollectionsPage>,
          MyCollectionsPage,
          FutureOr<MyCollectionsPage>,
          CollectionType?
        > {
  MyCollectionsControllerFamily._()
    : super(
        retry: null,
        name: r'myCollectionsControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Backs the "My Collection" library page (Task 11), one instance per
  /// segmented-control tab. `type: null` fetches all 5 states -- the UI
  /// itself always passes a concrete [CollectionType] (one per tab), but
  /// this controller doesn't require that.

  MyCollectionsControllerProvider call({required CollectionType? type}) =>
      MyCollectionsControllerProvider._(argument: type, from: this);

  @override
  String toString() => r'myCollectionsControllerProvider';
}

/// Backs the "My Collection" library page (Task 11), one instance per
/// segmented-control tab. `type: null` fetches all 5 states -- the UI
/// itself always passes a concrete [CollectionType] (one per tab), but
/// this controller doesn't require that.

abstract class _$MyCollectionsController
    extends $AsyncNotifier<MyCollectionsPage> {
  late final _$args = ref.$arg as CollectionType?;
  CollectionType? get type => _$args;

  FutureOr<MyCollectionsPage> build({required CollectionType? type});
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<MyCollectionsPage>, MyCollectionsPage>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<MyCollectionsPage>, MyCollectionsPage>,
              AsyncValue<MyCollectionsPage>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(type: _$args));
  }
}
