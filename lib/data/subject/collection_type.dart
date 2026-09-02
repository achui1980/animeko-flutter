// lib/data/subject/collection_type.dart

/// A subject's collection status in the current user's library. Mirrors
/// the Kotlin-generated `AniCollectionType` enum's wire values exactly
/// (verified against the real client code) -- these are
/// SCREAMING_SNAKE_CASE, not json_serializable's default camelCase
/// mapping, so a custom converter is required wherever this type appears
/// on the wire (see [collectionTypeFromWireNullable]/
/// [collectionTypeToWireNullable]).
enum CollectionType { wish, doing, done, onHold, dropped }

extension CollectionTypeWireValue on CollectionType {
  String get wireValue => switch (this) {
    CollectionType.wish => 'WISH',
    CollectionType.doing => 'DOING',
    CollectionType.done => 'DONE',
    CollectionType.onHold => 'ON_HOLD',
    CollectionType.dropped => 'DROPPED',
  };
}

CollectionType collectionTypeFromWire(String wire) => switch (wire) {
  'WISH' => CollectionType.wish,
  'DOING' => CollectionType.doing,
  'DONE' => CollectionType.done,
  'ON_HOLD' => CollectionType.onHold,
  'DROPPED' => CollectionType.dropped,
  _ => throw FormatException('Unknown CollectionType wire value: $wire'),
};

/// json_serializable `@JsonKey(fromJson: ...)` converter for a *nullable*
/// [CollectionType] field (null means "not in the user's collection").
CollectionType? collectionTypeFromWireNullable(String? wire) =>
    wire == null ? null : collectionTypeFromWire(wire);

/// json_serializable `@JsonKey(toJson: ...)` converter for a *nullable*
/// [CollectionType] field.
String? collectionTypeToWireNullable(CollectionType? type) => type?.wireValue;
