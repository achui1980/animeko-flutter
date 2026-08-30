import 'package:animeko_flutter/data/search/search_api.dart';
import 'package:animeko_flutter/data/search/search_models.dart';
import 'package:animeko_flutter/domain/search/search_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class MockSearchApi extends Mock implements SearchApi {}

void main() {
  late MockSearchApi api;
  late ProviderContainer container;

  setUp(() {
    api = MockSearchApi();
    container = ProviderContainer(
      overrides: [
        searchApiProvider.overrideWithValue(api),
        // Zero debounce so tests don't need to wait on a real timer.
        searchDebounceDurationProvider.overrideWithValue(Duration.zero),
      ],
    );
    addTearDown(container.dispose);
    // searchControllerProvider is autoDispose (matching HomeController's
    // pattern). container.read() alone does not keep an autoDispose
    // provider alive once the synchronous call stack returns, so without
    // an active listener the notifier -- and its pending debounce Timer --
    // would be torn down (via ref.onDispose) before the timer ever fires.
    // A held subscription keeps it alive for the duration of each test.
    addTearDown(container.listen(searchControllerProvider, (_, _) {}).close);
  });

  test('initial state is an empty list', () async {
    final result = await container.read(searchControllerProvider.future);
    expect(result, isEmpty);
  });

  test('empty keywords resets to an empty list without calling the API', () async {
    await container.read(searchControllerProvider.future);
    container.read(searchControllerProvider.notifier).search(keywords: '   ');
    // No debounce wait needed -- empty-keyword path is synchronous.
    final state = container.read(searchControllerProvider);
    expect(state.value, isEmpty);
    verifyNever(() => api.search(keywords: any(named: 'keywords')));
  });

  test('non-empty keywords call the API after the debounce and map results', () async {
    when(
      () => api.search(
        keywords: any(named: 'keywords'),
        tags: any(named: 'tags'),
        sortBy: any(named: 'sortBy'),
      ),
    ).thenAnswer(
      (_) async => const SearchResponse(
        items: [
          SubjectSearchResult(
            id: 1,
            name: 'Frieren',
            nameCn: '芙莉莲',
            imageLarge: 'https://example.com/f.jpg',
            airDate: '2023-09-29',
            tags: [],
          ),
        ],
      ),
    );

    await container.read(searchControllerProvider.future);
    container.read(searchControllerProvider.notifier).search(keywords: 'frieren');

    // Debounce is zero, but the timer callback still runs as a
    // microtask/event -- pump the event loop once.
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final state = container.read(searchControllerProvider);
    expect(state.value, isNotNull);
    expect(state.value!.single.name, 'Frieren');
    expect(state.value!.single.id, 1);
  });

  test('a thrown API error surfaces as AsyncError', () async {
    when(
      () => api.search(
        keywords: any(named: 'keywords'),
        tags: any(named: 'tags'),
        sortBy: any(named: 'sortBy'),
      ),
    ).thenThrow(Exception('network down'));

    await container.read(searchControllerProvider.future);
    container.read(searchControllerProvider.notifier).search(keywords: 'frieren');

    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final state = container.read(searchControllerProvider);
    expect(state.hasError, isTrue);
  });
}
