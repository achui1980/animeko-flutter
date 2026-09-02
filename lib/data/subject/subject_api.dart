import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../api_client.dart';
import 'collection_type.dart';
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

  /// PATCH /v2/subjects/{subjectId} -- edits (or creates) the current
  /// user's collection status and/or self-rating in one call. Passing
  /// only one of the two named params sends only that field.
  Future<void> updateCollection(
    int subjectId, {
    CollectionType? collectionType,
    SelfRating? selfRating,
  }) async {
    final body = <String, dynamic>{
      if (collectionType != null) 'collectionType': collectionType.wireValue,
      if (selfRating != null) 'selfRating': selfRating.toJson(),
    };
    await _dio.patch<void>('/v2/subjects/$subjectId', data: body);
  }

  /// DELETE /v2/subjects/{subjectId} -- removes the subject from the
  /// current user's collection entirely (this also discards any
  /// self-rating -- there is no partial-removal endpoint).
  Future<void> deleteCollection(int subjectId) async {
    await _dio.delete<void>('/v2/subjects/$subjectId');
  }
}

@riverpod
SubjectApi subjectApi(Ref ref) => SubjectApi(ref.watch(dioProvider));
