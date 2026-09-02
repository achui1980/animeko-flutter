import '../data/home/home_recommendations_models.dart';
import '../data/home/trends_models.dart';
import '../data/schedule/schedule_models.dart';
import '../data/search/search_models.dart';
import '../data/subject/subject_models.dart';

/// Unified internal representation of an anime "card" shown in Home,
/// Search, Schedule, and My-Collection lists. None of the five Ani API
/// endpoint groups (trends, home recommendations, search, schedule) return a shared wire
/// model -- each has its own incompatible field set (different names for
/// id/image, inconsistent presence of nameCn/score/tags). Rather than
/// have the UI branch on four different types, every API-specific model
/// is mapped into this one type via a factory constructor added in the
/// task that introduces that API (see SubjectCard.fromTrending,
/// .fromRecommendation, .fromSearchResult, .fromScheduledSubject, .fromMyCollectionSubject).
class SubjectCard {
  const SubjectCard({
    required this.id,
    required this.name,
    this.nameCn,
    this.imageUrl,
    this.score,
    this.tags,
    this.airDate,
  });

  final int? id;
  final String name;
  final String? nameCn;
  final String? imageUrl;
  final String? score;
  final List<String>? tags;
  final String? airDate;

  factory SubjectCard.fromTrending(TrendingSubject t) => SubjectCard(
    id: t.bangumiId,
    name: t.nameCn,
    nameCn: t.nameCn,
    imageUrl: t.imageLarge,
  );

  factory SubjectCard.fromRecommendation(SubjectRecommendation r) =>
      SubjectCard(
        id: r.subjectId,
        name: r.subjectName,
        nameCn: r.subjectNameCn,
        imageUrl: r.imageUrl,
      );

  factory SubjectCard.fromSearchResult(SubjectSearchResult s) => SubjectCard(
    id: s.id,
    name: s.name,
    nameCn: s.nameCn,
    imageUrl: s.imageLarge,
    score: s.score,
    tags: s.tags.map((t) => t.name).toList(),
    airDate: s.airDate,
  );

  factory SubjectCard.fromScheduledSubject(ScheduledAnimeSubject s) =>
      SubjectCard(
        id: s.subjectId,
        name: s.name,
        nameCn: s.nameCn,
        imageUrl: s.imageLarge,
      );

  factory SubjectCard.fromMyCollectionSubject(MyCollectionSubject s) =>
      SubjectCard(id: s.subjectId, name: s.name, nameCn: s.nameCn);
}
