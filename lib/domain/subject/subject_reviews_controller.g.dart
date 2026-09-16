// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subject_reviews_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Other users' short reviews (热门评价). Paginated by offset, accumulating
/// into a single [SubjectReviewsPage] so the sheet can just render
/// `state.items`.
///
/// The detail page's right-column card shows only the first few of these;
/// the 查看全部 sheet shows everything and calls [loadMore].
///
/// Failure is silent at the UI level (the 热门评价 card hides) -- see the
/// design doc's 「加载 / 错误 / 空态」 table.

@ProviderFor(SubjectReviewsController)
final subjectReviewsControllerProvider = SubjectReviewsControllerFamily._();

/// Other users' short reviews (热门评价). Paginated by offset, accumulating
/// into a single [SubjectReviewsPage] so the sheet can just render
/// `state.items`.
///
/// The detail page's right-column card shows only the first few of these;
/// the 查看全部 sheet shows everything and calls [loadMore].
///
/// Failure is silent at the UI level (the 热门评价 card hides) -- see the
/// design doc's 「加载 / 错误 / 空态」 table.
final class SubjectReviewsControllerProvider
    extends
        $AsyncNotifierProvider<SubjectReviewsController, SubjectReviewsPage> {
  /// Other users' short reviews (热门评价). Paginated by offset, accumulating
  /// into a single [SubjectReviewsPage] so the sheet can just render
  /// `state.items`.
  ///
  /// The detail page's right-column card shows only the first few of these;
  /// the 查看全部 sheet shows everything and calls [loadMore].
  ///
  /// Failure is silent at the UI level (the 热门评价 card hides) -- see the
  /// design doc's 「加载 / 错误 / 空态」 table.
  SubjectReviewsControllerProvider._({
    required SubjectReviewsControllerFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'subjectReviewsControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$subjectReviewsControllerHash();

  @override
  String toString() {
    return r'subjectReviewsControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  SubjectReviewsController create() => SubjectReviewsController();

  @override
  bool operator ==(Object other) {
    return other is SubjectReviewsControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$subjectReviewsControllerHash() =>
    r'10abc8b70fd64a205a50174fde10bf622cf37340';

/// Other users' short reviews (热门评价). Paginated by offset, accumulating
/// into a single [SubjectReviewsPage] so the sheet can just render
/// `state.items`.
///
/// The detail page's right-column card shows only the first few of these;
/// the 查看全部 sheet shows everything and calls [loadMore].
///
/// Failure is silent at the UI level (the 热门评价 card hides) -- see the
/// design doc's 「加载 / 错误 / 空态」 table.

final class SubjectReviewsControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          SubjectReviewsController,
          AsyncValue<SubjectReviewsPage>,
          SubjectReviewsPage,
          FutureOr<SubjectReviewsPage>,
          int
        > {
  SubjectReviewsControllerFamily._()
    : super(
        retry: null,
        name: r'subjectReviewsControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Other users' short reviews (热门评价). Paginated by offset, accumulating
  /// into a single [SubjectReviewsPage] so the sheet can just render
  /// `state.items`.
  ///
  /// The detail page's right-column card shows only the first few of these;
  /// the 查看全部 sheet shows everything and calls [loadMore].
  ///
  /// Failure is silent at the UI level (the 热门评价 card hides) -- see the
  /// design doc's 「加载 / 错误 / 空态」 table.

  SubjectReviewsControllerProvider call({required int subjectId}) =>
      SubjectReviewsControllerProvider._(argument: subjectId, from: this);

  @override
  String toString() => r'subjectReviewsControllerProvider';
}

/// Other users' short reviews (热门评价). Paginated by offset, accumulating
/// into a single [SubjectReviewsPage] so the sheet can just render
/// `state.items`.
///
/// The detail page's right-column card shows only the first few of these;
/// the 查看全部 sheet shows everything and calls [loadMore].
///
/// Failure is silent at the UI level (the 热门评价 card hides) -- see the
/// design doc's 「加载 / 错误 / 空态」 table.

abstract class _$SubjectReviewsController
    extends $AsyncNotifier<SubjectReviewsPage> {
  late final _$args = ref.$arg as int;
  int get subjectId => _$args;

  FutureOr<SubjectReviewsPage> build({required int subjectId});
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<SubjectReviewsPage>, SubjectReviewsPage>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<SubjectReviewsPage>, SubjectReviewsPage>,
              AsyncValue<SubjectReviewsPage>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(subjectId: _$args));
  }
}
