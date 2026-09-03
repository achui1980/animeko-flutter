import 'package:animeko_flutter/data/home/home_recommendations_api.dart';
import 'package:animeko_flutter/data/home/home_recommendations_models.dart';
import 'package:animeko_flutter/domain/home/home_recommendations_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class MockHomeRecommendationsApi extends Mock implements HomeRecommendationsApi {}

void main() {
  late MockHomeRecommendationsApi api;
  late ProviderContainer container;

  setUp(() {
    api = MockHomeRecommendationsApi();
    container = ProviderContainer(
      overrides: [homeRecommendationsApiProvider.overrideWithValue(api)],
      retry: (retryCount, error) => null,
    );
    addTearDown(container.dispose);
  });

  group('build', () {
    test('fetches the first page at offset 0 and maps to SubjectCard', () async {
      when(() => api.getRecommendations(offset: 0, limit: 20)).thenAnswer(
        (_) async => const HomeRecommendationsResponse(
          total: 1,
          items: [
            SubjectRecommendation(
              subjectName: 'B',
              subjectNameCn: 'B-cn',
              imageUrl: 'b.jpg',
              desc1: 'd1',
              desc2: 'd2',
              subjectId: 2,
            ),
          ],
        ),
      );

      final result = await container.read(homeRecommendationsControllerProvider.future);

      expect(result.items, hasLength(1));
      expect(result.items.single.name, 'B');
      expect(result.hasMore, isFalse);
    });

    test('hasMore is true when items.length < total', () async {
      when(() => api.getRecommendations(offset: 0, limit: 20)).thenAnswer(
        (_) async => HomeRecommendationsResponse(
          total: 30,
          items: List.generate(
            20,
            (i) => SubjectRecommendation(
              subjectName: 'S$i',
              subjectNameCn: 'S$i-cn',
              imageUrl: 's$i.jpg',
              desc1: '',
              desc2: '',
              subjectId: i,
            ),
          ),
        ),
      );

      final result = await container.read(homeRecommendationsControllerProvider.future);

      expect(result.hasMore, isTrue);
    });

    test('surfaces an error from the API', () async {
      when(() => api.getRecommendations(offset: 0, limit: 20)).thenThrow(Exception('boom'));

      // With riverpod 3.2.1 (pinned by this repo), an autoDispose
      // AsyncNotifier whose build() rejects, when read via `.future` with
      // no persistent listener, races the auto-dispose scheduler and
      // never settles with the real error under `package:test` -- it
      // hangs until timeout. Keep a listener alive + `container.pump()` +
      // a synchronous `container.read()` (returns AsyncValue) instead,
      // matching riverpod's own test suite and this repo's precedent
      // (the deleted `home_controller_test.dart`'s error-path test).
      final sub = container.listen(homeRecommendationsControllerProvider, (_, _) {});
      addTearDown(sub.close);

      await container.pump();

      final value = container.read(homeRecommendationsControllerProvider);
      expect(value.hasError, isTrue);
      expect(value.error, isA<Exception>());
    });
  });

  group('loadMore', () {
    test('fetches the next page using the current length as offset and appends it', () async {
      when(() => api.getRecommendations(offset: 0, limit: 20)).thenAnswer(
        (_) async => HomeRecommendationsResponse(
          total: 21,
          items: List.generate(
            20,
            (i) => SubjectRecommendation(
              subjectName: 'S$i',
              subjectNameCn: 'S$i-cn',
              imageUrl: 's$i.jpg',
              desc1: '',
              desc2: '',
              subjectId: i,
            ),
          ),
        ),
      );
      await container.read(homeRecommendationsControllerProvider.future);

      when(() => api.getRecommendations(offset: 20, limit: 20)).thenAnswer(
        (_) async => const HomeRecommendationsResponse(
          total: 21,
          items: [
            SubjectRecommendation(
              subjectName: 'Last',
              subjectNameCn: 'Last-cn',
              imageUrl: 'last.jpg',
              desc1: '',
              desc2: '',
              subjectId: 20,
            ),
          ],
        ),
      );

      await container.read(homeRecommendationsControllerProvider.notifier).loadMore();

      final result = container.read(homeRecommendationsControllerProvider).value!;
      expect(result.items, hasLength(21));
      expect(result.items.last.id, 20);
      expect(result.hasMore, isFalse);
    });

    test('does nothing when hasMore is already false', () async {
      when(() => api.getRecommendations(offset: 0, limit: 20)).thenAnswer(
        (_) async => const HomeRecommendationsResponse(
          total: 1,
          items: [
            SubjectRecommendation(
              subjectName: 'Only',
              subjectNameCn: 'Only-cn',
              imageUrl: 'only.jpg',
              desc1: '',
              desc2: '',
              subjectId: 1,
            ),
          ],
        ),
      );
      await container.read(homeRecommendationsControllerProvider.future);

      await container.read(homeRecommendationsControllerProvider.notifier).loadMore();

      verifyNever(() => api.getRecommendations(offset: 1, limit: 20));
    });
  });
}
