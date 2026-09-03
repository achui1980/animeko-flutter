// lib/data/user/user_api.dart
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../api_client.dart';
import 'user_models.dart';

part 'user_api.g.dart';

/// Direct calls against the real `https://api.animeko.org` server (via
/// the shared [dioProvider], which already carries the Plan-1b-1
/// `AuthInterceptor`) -- same style as `SubjectApi`.
class UserApi {
  UserApi(this._dio);
  final Dio _dio;

  /// GET /v1/me -- the current user's own profile. Requires auth-jwt
  /// authentication.
  Future<SelfUser> getSelf() async {
    final response = await _dio.get<Map<String, dynamic>>('/v1/me');
    return SelfUser.fromJson(response.data!);
  }
}

@riverpod
UserApi userApi(Ref ref) => UserApi(ref.watch(dioProvider));
