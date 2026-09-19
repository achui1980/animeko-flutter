// lib/domain/auth/auth_gate.dart
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'auth_controller.dart';
import 'auth_state.dart';

/// Guards an action that requires a logged-in Bangumi session.
///
/// Most of the app is browsable as a guest (see `app/router.dart`'s doc
/// comment); only specific actions -- following a subject, rating it,
/// viewing "my collection" -- need a session. Call this at the top of such
/// an action: if the user isn't authenticated, it pushes `/login` (so the
/// user can back out to where they were) and returns `false`, telling the
/// caller to skip the guarded action. On success it returns `true` and
/// does nothing else -- per design, a completed login does *not*
/// automatically retry the original action; the user taps it again.
bool requireLogin(BuildContext context, WidgetRef ref) {
  final isAuthenticated = ref.read(authControllerProvider) is AuthAuthenticated;
  if (!isAuthenticated) {
    context.push('/login');
  }
  return isAuthenticated;
}
