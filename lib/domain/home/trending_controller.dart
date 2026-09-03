// lib/domain/home/trending_controller.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/home/trends_api.dart';
import '../subject_card.dart';

part 'trending_controller.g.dart';

/// The home page's "trending" carousel data. `GET /v1/trends` has no
/// pagination params -- it's a small, curated, fixed-size list meant for
/// a carousel, not a scrollable feed (see the design doc).
@riverpod
Future<List<SubjectCard>> trending(Ref ref) async {
  final api = ref.watch(trendsApiProvider);
  final response = await api.getTrends();
  return response.trendingSubjects.map(SubjectCard.fromTrending).toList();
}
