// lib/app/router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/play/subject_episodes_controller.dart';
import '../ui/auth/login_screen.dart';
import '../ui/collection/my_collection_screen.dart';
import '../ui/download/download_manager_screen.dart';
import '../ui/home/home_screen.dart';
import '../ui/player/player_screen.dart';
import '../ui/schedule/schedule_screen.dart';
import '../ui/search/search_screen.dart';
import '../ui/settings/proxy_settings_screen.dart';
import '../ui/settings/settings_screen.dart';
import '../ui/shell/main_shell.dart';
import '../ui/subject/subject_detail_screen.dart';

part 'router.g.dart';

/// Most of the app is browsable without logging in. There is no global
/// auth gate: guest users land straight on `/home`, and only the specific
/// actions/screens that actually require a Bangumi session send the user
/// to `/login` on demand (see `domain/auth/auth_gate.dart`'s
/// `requireLogin()`).
@riverpod
GoRouter appRouter(Ref ref) {
  final router = GoRouter(
    initialLocation: '/home',
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
          final subjectId = int.parse(state.pathParameters['subjectId']!);
          final subjectName = state.uri.queryParameters['name'] ?? '';
          return PlayerScreen(
            episode: extra,
            subjectId: subjectId,
            subjectName: subjectName,
          );
        },
      ),
      GoRoute(
        path: '/settings/proxy',
        builder: (context, state) => const ProxySettingsScreen(),
      ),
      GoRoute(
        path: '/collection',
        builder: (context, state) => const MyCollectionScreen(),
      ),
      GoRoute(
        path: '/downloads',
        builder: (context, state) => const DownloadManagerScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/search',
                builder: (context, state) => const SearchScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/schedule',
                builder: (context, state) => const ScheduleScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
}
