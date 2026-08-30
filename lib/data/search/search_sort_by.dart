// lib/data/search/search_sort_by.dart

/// Mirrors the Kotlin-generated `AniSubjectSearchSortBy` enum's wire
/// values exactly (verified against the real client code -- these do NOT
/// match a naive guess like MATCH/RANK/COLLECTION/DATE).
enum SearchSortBy {
  relevance,
  airDateAsc,
  airDateDesc,
  ratingAsc,
  ratingDesc,
  rankAsc,
  rankDesc,
  collectionDesc,
}

extension SearchSortByWireValue on SearchSortBy {
  String get wireValue => switch (this) {
    SearchSortBy.relevance => 'relevance',
    SearchSortBy.airDateAsc => 'airDateAsc',
    SearchSortBy.airDateDesc => 'airDateDesc',
    SearchSortBy.ratingAsc => 'ratingAsc',
    SearchSortBy.ratingDesc => 'ratingDesc',
    SearchSortBy.rankAsc => 'rankAsc',
    SearchSortBy.rankDesc => 'rankDesc',
    SearchSortBy.collectionDesc => 'collectionDesc',
  };
}
