import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/home/home_recommendations_api.dart';
import '../../data/home/home_recommendations_models.dart';
import '../../data/home/trends_api.dart';
import '../../data/home/trends_models.dart';
import '../subject_card.dart';

part 'home_controller.g.dart';

class HomeData {
  const HomeData({required this.trending, required this.recommendations});

  final List<SubjectCard> trending;
  final List<SubjectCard> recommendations;
}

@riverpod
class HomeController extends _$HomeController {
  @override
  Future<HomeData> build() async {
    final trendsApi = ref.watch(trendsApiProvider);
    final recommendationsApi = ref.watch(homeRecommendationsApiProvider);

    final results = await Future.wait([
      trendsApi.getTrends(),
      recommendationsApi.getRecommendations(),
    ]);

    final trends = results[0] as TrendsResponse;
    final recommendations = results[1] as HomeRecommendationsResponse;

    return HomeData(
      trending: trends.trendingSubjects.map(SubjectCard.fromTrending).toList(),
      recommendations: recommendations.items
          .map(SubjectCard.fromRecommendation)
          .toList(),
    );
  }
}
