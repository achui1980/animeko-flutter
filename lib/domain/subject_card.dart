/// Unified internal representation of an anime "card" shown in Home,
/// Search, and Schedule lists. None of the four Ani API endpoint groups
/// (trends, home recommendations, search, schedule) return a shared wire
/// model -- each has its own incompatible field set (different names for
/// id/image, inconsistent presence of nameCn/score/tags). Rather than
/// have the UI branch on four different types, every API-specific model
/// is mapped into this one type via a factory constructor added in the
/// task that introduces that API (see SubjectCard.fromTrending,
/// .fromRecommendation, .fromSearchResult, .fromScheduledSubject).
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
}
