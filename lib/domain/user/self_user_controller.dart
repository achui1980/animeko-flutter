// lib/domain/user/self_user_controller.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/user/user_api.dart';
import '../../data/user/user_models.dart';

part 'self_user_controller.g.dart';

/// The current user's own profile. The account screen is the only
/// consumer -- no caching/refresh policy beyond Riverpod's default is
/// needed.
@riverpod
Future<SelfUser> selfUser(Ref ref) async {
  final api = ref.watch(userApiProvider);
  return api.getSelf();
}
