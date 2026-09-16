import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../api_client.dart';
import 'collection_type.dart';
import 'review_models.dart';
import 'subject_models.dart';

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
    final response = await _dio.get<Map<String, dynamic>>(
      '/v2/subjects/$subjectId',
    );
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

  /// Characters (cast). Always requested with `withActors=true` so the
  /// UI can show each character's voice actor.
  ///
  /// The endpoint returns a BARE JSON ARRAY, not an `{items: [...]}`
  /// envelope -- an earlier version of this method declared
  /// `get<Map<String, dynamic>>` and read `data['items']`, which threw
  /// on every single call. The `data is List` branch below is
  /// defensive in case the backend ever adds an envelope.
  Future<List<RelatedCharacter>> getCharacters(int subjectId) async {
    final response = await _dio.get<dynamic>(
      '/v2/subjects/$subjectId/characters',
      queryParameters: {'withActors': true},
    );
    final data = response.data;
    final items = data is List<dynamic>
        ? data
        : (data as Map<String, dynamic>)['items'] as List<dynamic>;
    return items
        .map((item) => RelatedCharacter.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// GET /v2/subjects/list -- the "My Collection" library page, filtered
  /// by [type] (null = all 5 states, though the UI always passes a
  /// concrete type -- see `MyCollectionsController`). Pagination is
  /// offset-based (see `MyCollectionsController.loadMore`).
  Future<PaginatedCollections> getMyCollections({
    CollectionType? type,
    required int offset,
    required int limit,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v2/subjects/list',
      queryParameters: {
        if (type != null) 'type': type.wireValue,
        'offset': offset,
        'limit': limit,
      },
    );
    return PaginatedCollections.fromJson(response.data!);
  }

  /// Other users' reviews (热门评价) for a subject. Ordering is whatever
  /// the backend returns -- it has not been verified, so don't rely on
  /// it being newest-first or most-liked-first.
  ///
  /// The response's `total` is a `limit + 1` sentinel, not a real count
  /// -- see [PaginatedReviews]. Both [offset] and [limit] are required:
  /// the backend defaults `limit` to 30, but callers own their page size.
  Future<PaginatedReviews> getReviews({
    required int subjectId,
    required int offset,
    required int limit,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v2/subjects/$subjectId/reviews',
      queryParameters: {'offset': offset, 'limit': limit},
    );
    return PaginatedReviews.fromJson(response.data!);
  }
}

@riverpod
SubjectApi subjectApi(Ref ref) => SubjectApi(ref.watch(dioProvider));
