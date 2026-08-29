import 'package:animeko_flutter/data/home/home_recommendations_api.dart';
import 'package:animeko_flutter/data/home/home_recommendations_models.dart';
import 'package:animeko_flutter/data/home/trends_api.dart';
import 'package:animeko_flutter/data/home/trends_models.dart';
import 'package:animeko_flutter/domain/home/home_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class MockTrendsApi extends Mock implements TrendsApi {}

class MockHomeRecommendationsApi extends Mock
    implements HomeRecommendationsApi {}

void main() {
  late MockTrendsApi trendsApi;
  late MockHomeRecommendationsApi recommendationsApi;
  late ProviderContainer container;

  setUp(() {
    trendsApi = MockTrendsApi();
    recommendationsApi = MockHomeRecommendationsApi();
    container = ProviderContainer(
      overrides: [
        trendsApiProvider.overrideWithValue(trendsApi),
        homeRecommendationsApiProvider.overrideWithValue(recommendationsApi),
      ],
    );
    addTearDown(container.dispose);
  });

  test(
    'loads trending and recommendations in parallel and maps to SubjectCard',
    () async {
      when(() => trendsApi.getTrends()).thenAnswer(
        (_) async => const TrendsResponse(
          trendingSubjects: [
            TrendingSubject(bangumiId: 1, nameCn: 'A', imageLarge: 'a.jpg'),
          ],
        ),
      );
      when(() => recommendationsApi.getRecommendations()).thenAnswer(
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

      final data = await container.read(homeControllerProvider.future);

      expect(data.trending, hasLength(1));
      expect(data.trending.single.name, 'A');
      expect(data.recommendations, hasLength(1));
      expect(data.recommendations.single.name, 'B');
    },
  );

  test('surfaces an error if either API call fails', () async {
    when(() => trendsApi.getTrends()).thenThrow(Exception('boom'));
    when(() => recommendationsApi.getRecommendations()).thenAnswer(
      (_) async => const HomeRecommendationsResponse(total: 0, items: []),
    );

    // Deliberately not using `await container.read(homeControllerProvider
    // .future)` + `throwsA` here: with riverpod 3.2.1 (pinned by this repo)
    // an autoDispose AsyncNotifier whose build() rejects, when read via
    // `.future` with no persistent listener, races the auto-dispose
    // scheduler and never settles with the real error under `package:test`
    // -- it hangs until the test times out, then surfaces a generic
    // "disposed during loading state" StateError instead of the thrown
    // Exception. riverpod's own test suite avoids this by keeping a
    // listener alive and using `container.pump()` + a synchronous
    // `container.read(provider)` (returning `AsyncValue`) rather than
    // `.future`; this test follows that same proven pattern.
    final sub = container.listen(homeControllerProvider, (_, _) {});
    addTearDown(sub.close);

    await container.pump();

    final value = container.read(homeControllerProvider);
    expect(value.hasError, isTrue);
    expect(value.error, isA<Exception>());
  });
}
