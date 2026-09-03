import 'package:animeko_flutter/data/home/trends_api.dart';
import 'package:animeko_flutter/data/home/trends_models.dart';
import 'package:animeko_flutter/domain/home/trending_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class MockTrendsApi extends Mock implements TrendsApi {}

void main() {
  late MockTrendsApi api;
  late ProviderContainer container;

  setUp(() {
    api = MockTrendsApi();
    container = ProviderContainer(overrides: [trendsApiProvider.overrideWithValue(api)]);
    addTearDown(container.dispose);
  });

  test('maps TrendsResponse.trendingSubjects to SubjectCard', () async {
    when(() => api.getTrends()).thenAnswer(
      (_) async => const TrendsResponse(
        trendingSubjects: [
          TrendingSubject(bangumiId: 1, nameCn: 'A', imageLarge: 'a.jpg'),
          TrendingSubject(bangumiId: 2, nameCn: 'B', imageLarge: 'b.jpg'),
        ],
      ),
    );

    final result = await container.read(trendingProvider.future);

    expect(result, hasLength(2));
    expect(result[0].id, 1);
    expect(result[0].name, 'A');
    expect(result[0].imageUrl, 'a.jpg');
    expect(result[1].id, 2);
  });

  test('returns an empty list when there are no trending subjects', () async {
    when(() => api.getTrends()).thenAnswer(
      (_) async => const TrendsResponse(trendingSubjects: []),
    );

    final result = await container.read(trendingProvider.future);

    expect(result, isEmpty);
  });
}
