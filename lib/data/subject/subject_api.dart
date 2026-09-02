import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../api_client.dart';
import 'subject_models.dart';

export 'collection_type.dart' show CollectionTypeWireValue;

part 'subject_api.g.dart';

/// Direct calls against the real `https://api.animeko.org` server (via
/// the shared [dioProvider], which already carries the Plan-1b-1
/// `AuthInterceptor`). No local caching/Drift layer this round -- see
/// the plan's Global Constraints.
class SubjectApi {
  SubjectApi(this._dio);
  final Dio _dio;

  /// GET /v2/subjects/{subjectId} -- also returns the current user's own
  /// collectionType/selfRating if authenticated (null-valued if not
  /// collected/rated).
  Future<SubjectDetail> getSubject(int subjectId) async {
    final response = await _dio.get<Map<String, dynamic>>('/v2/subjects/$subjectId');
    return SubjectDetail.fromJson(response.data!);
  }
}

@riverpod
SubjectApi subjectApi(Ref ref) => SubjectApi(ref.watch(dioProvider));
