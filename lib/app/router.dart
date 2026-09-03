// lib/app/router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/auth/auth_controller.dart';
import '../domain/auth/auth_state.dart';
import '../domain/play/subject_episodes_controller.dart';
import '../ui/auth/login_screen.dart';
import '../ui/collection/my_collection_screen.dart';
import '../ui/home/home_screen.dart';
import '../ui/player/player_screen.dart';
import '../ui/schedule/schedule_screen.dart';
import '../ui/search/search_screen.dart';
import '../ui/settings/proxy_settings_screen.dart';
import '../ui/settings/settings_screen.dart';
import '../ui/shell/main_shell.dart';
import '../ui/subject/subject_detail_screen.dart';

part 'router.g.dart';

/// Bridges Riverpod's [authControllerProvider] state changes into
/// go_router's `refreshListenable`, which is what triggers the `redirect:`
/// callback to be re-evaluated on an *external* state change (e.g. login
/// succeeding while the user is still sitting on the `/login` route).
/// Without this, go_router only re-runs `redirect:` on navigation events,
/// so a successful login would never automatically navigate the user away
/// from the login screen.
class _RouterRefreshNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

@riverpod
GoRouter appRouter(Ref ref) {
  final notifier = _RouterRefreshNotifier();
  ref.listen(authControllerProvider, (_, _) => notifier.notify());
  ref.onDispose(notifier.dispose);

  final router = GoRouter(
    initialLocation: '/login',
    refreshListenable: notifier,
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      final isAuthenticated = authState is AuthAuthenticated;
      final isLoggingIn = state.matchedLocation == '/login';

      if (!isAuthenticated && !isLoggingIn) return '/login';
      if (isAuthenticated && isLoggingIn) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/subject/:subjectId',
        builder: (context, state) {
          final subjectId = int.parse(state.pathParameters['subjectId']!);
          final name = state.uri.queryParameters['name'] ?? '';
          final imageUrl = state.uri.queryParameters['imageUrl'];
          return SubjectDetailScreen(
            subjectId: subjectId,
            subjectName: name,
            imageUrl: imageUrl,
          );
        },
      ),
      GoRoute(
        path: '/subject/:subjectId/play',
        builder: (context, state) {
          final extra = state.extra;
          // Guard against reaching this route without `extra` set (e.g.
          // app restoration or a future deep link) instead of letting an
          // unhandled `TypeError` crash the app -- today
          // `SubjectDetailScreen` always sets `extra` correctly.
          if (extra is! MergedEpisode) {
            return const Scaffold(
              body: Center(child: Text('Invalid navigation')),
            );
          }
          return PlayerScreen(episode: extra);
        },
      ),
      GoRoute(path: '/settings/proxy', builder: (context, state) => const ProxySettingsScreen()),
      GoRoute(path: '/collection', builder: (context, state) => const MyCollectionScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/home', builder: (context, state) => const HomeScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/search', builder: (context, state) => const SearchScreen())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/schedule', builder: (context, state) => const ScheduleScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
}
