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
    extends
        $AsyncNotifierProvider<
          MyCollectionsController,
          List<MyCollectionSubject>
        > {
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
    r'688a4999e050336f745fe6c02f6e62c219f66d9a';

/// Backs the "My Collection" library page (Task 11), one instance per
/// segmented-control tab. `type: null` fetches all 5 states -- the UI
/// itself always passes a concrete [CollectionType] (one per tab), but
/// this controller doesn't require that.

final class MyCollectionsControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          MyCollectionsController,
          AsyncValue<List<MyCollectionSubject>>,
          List<MyCollectionSubject>,
          FutureOr<List<MyCollectionSubject>>,
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
    extends $AsyncNotifier<List<MyCollectionSubject>> {
  late final _$args = ref.$arg as CollectionType?;
  CollectionType? get type => _$args;

  FutureOr<List<MyCollectionSubject>> build({required CollectionType? type});
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<List<MyCollectionSubject>>,
              List<MyCollectionSubject>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<MyCollectionSubject>>,
                List<MyCollectionSubject>
              >,
              AsyncValue<List<MyCollectionSubject>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(type: _$args));
  }
}
