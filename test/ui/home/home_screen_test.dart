import 'package:animeko_flutter/domain/auth/auth_controller.dart';
import 'package:animeko_flutter/domain/auth/auth_state.dart';
import 'package:animeko_flutter/domain/home/home_recommendations_controller.dart';
import 'package:animeko_flutter/domain/home/trending_controller.dart';
import 'package:animeko_flutter/domain/subject_card.dart';
import 'package:animeko_flutter/ui/common/anime_cover_card.dart';
import 'package:animeko_flutter/ui/home/home_screen.dart';
import 'package:animeko_flutter/ui/home/trending_carousel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthenticatedController extends AuthController {
  @override
  AuthState build() => const AuthAuthenticated('user-1');
}

class _FakeUnauthenticatedController extends AuthController {
  @override
  AuthState build() => const AuthUnauthenticated();
}

class _FakeHomeRecommendationsController extends HomeRecommendationsController {
  @override
  Future<HomeRecommendationsPage> build() async {
    return const HomeRecommendationsPage(
      items: [
        SubjectCard(
          id: 2,
          name: 'Bar',
          nameCn: 'Bar',
          imageUrl: 'https://example.com/2.png',
        ),
      ],
      hasMore: false,
    );
  }
}

/// Records [loadMore] calls instead of hitting the (unavailable in tests)
/// API, so tests can assert whether pagination was spuriously triggered.
/// `hasMore: true` so a real bug -- e.g. the load-more scroll listener
/// reacting to bubbled notifications from a nested scrollable such as
/// `TrendingCarousel` -- would actually call [loadMore] if not fixed.
class _RecordingHomeRecommendationsController
    extends HomeRecommendationsController {
  int loadMoreCallCount = 0;

  @override
  Future<HomeRecommendationsPage> build() async {
    return const HomeRecommendationsPage(
      items: [
        SubjectCard(
          id: 2,
          name: 'Bar',
          nameCn: 'Bar',
          imageUrl: 'https://example.com/2.png',
        ),
      ],
      hasMore: true,
    );
  }

  @override
  Future<void> loadMore() async {
    loadMoreCallCount++;
  }
}

Widget _wrap(Widget child) {
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(() => _FakeAuthenticatedController()),
      trendingProvider.overrideWith(
        (ref) async => const [
          SubjectCard(
            id: 1,
            name: 'Foo',
            nameCn: 'Foo',
            imageUrl: 'https://example.com/1.png',
          ),
        ],
      ),
      homeRecommendationsControllerProvider.overrideWith(
        () => _FakeHomeRecommendationsController(),
      ),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  // Bounded pumps, not pumpAndSettle(): TrendingCarousel owns a
  // Timer.periodic that keeps scheduling frames every simulated 5
  // seconds for as long as the widget stays mounted, so pumpAndSettle()
  // would never see "no more frames scheduled".
  testWidgets(
    'shows the trending carousel and recommendations grid with Chinese titles',
    (tester) async {
      await tester.pumpWidget(_wrap(const HomeScreen()));
      await tester.pump();
      await tester.pump();

      expect(find.text('最近热门'), findsOneWidget);
      expect(find.text('为你推荐'), findsOneWidget);
      expect(find.byType(TrendingCarousel), findsOneWidget);
      expect(find.text('Foo'), findsOneWidget);
      expect(find.byType(AnimeCoverCard), findsOneWidget);
      expect(find.text('Bar'), findsOneWidget);
    },
  );

  testWidgets('AppBar shows the collection action', (tester) async {
    await tester.pumpWidget(_wrap(const HomeScreen()));
    await tester.pump();
    await tester.pump();

    expect(find.byIcon(Icons.bookmark), findsOneWidget);
  });

  testWidgets(
    "the trending carousel's own auto-advance/scrolling does not trigger "
    'loadMore on the recommendations controller',
    (tester) async {
      final recController = _RecordingHomeRecommendationsController();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(
              () => _FakeAuthenticatedController(),
            ),
            trendingProvider.overrideWith(
              (ref) async => const [
                SubjectCard(
                  id: 1,
                  name: 'Foo',
                  nameCn: 'Foo',
                  imageUrl: 'https://example.com/1.png',
                ),
                SubjectCard(
                  id: 3,
                  name: 'Baz',
                  nameCn: 'Baz',
                  imageUrl: 'https://example.com/3.png',
                ),
              ],
            ),
            homeRecommendationsControllerProvider.overrideWith(
              () => recController,
            ),
          ],
          child: MaterialApp(home: const HomeScreen()),
        ),
      );
      await tester.pump();
      await tester.pump();

      // Let the carousel's internal 5-second auto-advance Timer.periodic
      // fire and its animateToItem animation actually run (bounded pumps,
      // never pumpAndSettle() -- the periodic timer means it would never
      // observe "no more scheduled frames").
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 350));

      expect(
        recController.loadMoreCallCount,
        0,
        reason:
            'The carousel auto-advancing its own nested horizontal '
            'Scrollable must not be mistaken for the user scrolling the '
            "outer CustomScrollView near the grid's bottom.",
      );
    },
  );

  testWidgets(
    'guest (unauthenticated) sees a login prompt instead of the '
    'recommendations grid',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(
              () => _FakeUnauthenticatedController(),
            ),
            trendingProvider.overrideWith(
              (ref) async => const [
                SubjectCard(
                  id: 1,
                  name: 'Foo',
                  nameCn: 'Foo',
                  imageUrl: 'https://example.com/1.png',
                ),
              ],
            ),
            homeRecommendationsControllerProvider.overrideWith(
              () => _FakeHomeRecommendationsController(),
            ),
          ],
          child: MaterialApp(home: const HomeScreen()),
        ),
      );
      await tester.pump();
      await tester.pump();

      // The public "最近热门" trending carousel is unaffected...
      expect(find.text('最近热门'), findsOneWidget);
      expect(find.byType(TrendingCarousel), findsOneWidget);
      // ...the auth-jwt-gated "为你推荐" section heading still shows
      // (matching the original Animeko app's behavior)...
      expect(find.text('为你推荐'), findsOneWidget);
      // ...but a login prompt replaces the grid instead of a doomed-to-401
      // fetch, and no recommendation cards are shown.
      expect(find.text('登录后即可查看推荐内容'), findsOneWidget);
      expect(find.byType(AnimeCoverCard), findsNothing);
    },
  );
}
