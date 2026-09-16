import 'package:animeko_flutter/data/subject/review_models.dart';
import 'package:animeko_flutter/data/subject/subject_api.dart';
import 'package:animeko_flutter/domain/subject/subject_reviews_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class MockSubjectApi extends Mock implements SubjectApi {}

SubjectReview review(String id) => SubjectReview(
  id: id,
  subjectId: 1,
  source: 'bangumi',
  author: ReviewAuthor(id: 'u$id', nickname: 'user $id'),
  contentBbcode: 'comment $id',
);

void main() {
  late MockSubjectApi api;
  late ProviderContainer container;

  setUp(() {
    api = MockSubjectApi();
    container = ProviderContainer(
      overrides: [subjectApiProvider.overrideWithValue(api)],
      retry: (retryCount, error) => null,
    );
    addTearDown(container.dispose);
  });

  final provider = subjectReviewsControllerProvider(subjectId: 1);

  // Builds a page the way the backend does: `total` is a has-more sentinel
  // that exceeds the returned row count exactly when more rows exist. (The
  // real backend returns `limit + 1`; scaled down here so the fixtures stay
  // short -- see `PaginatedReviews`'s class doc.)
  PaginatedReviews page(List<SubjectReview> items, {required bool more}) =>
      PaginatedReviews(total: items.length + (more ? 1 : 0), items: items);

  test('loads the first page with offset 0', () async {
    when(
      () => api.getReviews(subjectId: 1, offset: 0, limit: 20),
    ).thenAnswer((_) async => page([review('a'), review('b')], more: true));

    final result = await container.read(provider.future);

    expect(result.items.map((e) => e.id), ['a', 'b']);
    expect(result.hasMore, isTrue);
    verify(() => api.getReviews(subjectId: 1, offset: 0, limit: 20)).called(1);
  });

  test('loadMore appends the next page and advances the offset', () async {
    when(
      () => api.getReviews(subjectId: 1, offset: 0, limit: 20),
    ).thenAnswer((_) async => page([review('a'), review('b')], more: true));
    when(
      () => api.getReviews(subjectId: 1, offset: 2, limit: 20),
    ).thenAnswer((_) async => page([review('c')], more: false));

    await container.read(provider.future);
    await container.read(provider.notifier).loadMore();

    final result = container.read(provider).requireValue;
    expect(result.items.map((e) => e.id), ['a', 'b', 'c']);
    expect(result.hasMore, isFalse);
  });

  // The regression test this whole task exists for. If the controller kept
  // an accumulated `PaginatedReviews` and let its `hasMore` getter
  // recompute, page 2's sentinel of 3 would be compared against the 4
  // accumulated rows, `hasMore` would silently flip to false, and every
  // row after page 2 would be unreachable. `hasMore` must come from the
  // freshly fetched page alone.
  test('keeps hasMore true when a full second page still has more', () async {
    when(
      () => api.getReviews(subjectId: 1, offset: 0, limit: 20),
    ).thenAnswer((_) async => page([review('a'), review('b')], more: true));
    when(
      () => api.getReviews(subjectId: 1, offset: 2, limit: 20),
    ).thenAnswer((_) async => page([review('c'), review('d')], more: true));

    await container.read(provider.future);
    await container.read(provider.notifier).loadMore();

    final result = container.read(provider).requireValue;
    expect(result.items.map((e) => e.id), ['a', 'b', 'c', 'd']);
    expect(result.hasMore, isTrue);
  });

  test('loadMore is a no-op once hasMore is false', () async {
    when(
      () => api.getReviews(subjectId: 1, offset: 0, limit: 20),
    ).thenAnswer((_) async => page([review('a')], more: false));

    await container.read(provider.future);
    await container.read(provider.notifier).loadMore();

    verifyNever(() => api.getReviews(subjectId: 1, offset: 1, limit: 20));
    expect(container.read(provider).requireValue.items.length, 1);
  });

  test('loadMore is a no-op when the first page failed', () async {
    when(
      () => api.getReviews(subjectId: 1, offset: 0, limit: 20),
    ).thenThrow(Exception('network error'));

    await expectLater(
      container.read(provider.future),
      throwsA(isA<Exception>()),
    );
    await container.read(provider.notifier).loadMore();

    verifyNever(() => api.getReviews(subjectId: 1, offset: 1, limit: 20));
  });

  test('propagates a first-page failure', () async {
    when(
      () => api.getReviews(subjectId: 1, offset: 0, limit: 20),
    ).thenThrow(Exception('network error'));

    await expectLater(
      container.read(provider.future),
      throwsA(isA<Exception>()),
    );
  });
}
