import 'package:animeko_flutter/data/subject/collection_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CollectionType wire mapping', () {
    test('wireValue maps every enum value to its SCREAMING_SNAKE_CASE wire string', () {
      expect(CollectionType.wish.wireValue, 'WISH');
      expect(CollectionType.doing.wireValue, 'DOING');
      expect(CollectionType.done.wireValue, 'DONE');
      expect(CollectionType.onHold.wireValue, 'ON_HOLD');
      expect(CollectionType.dropped.wireValue, 'DROPPED');
    });

    test('collectionTypeFromWire parses every valid wire value', () {
      expect(collectionTypeFromWire('WISH'), CollectionType.wish);
      expect(collectionTypeFromWire('DOING'), CollectionType.doing);
      expect(collectionTypeFromWire('DONE'), CollectionType.done);
      expect(collectionTypeFromWire('ON_HOLD'), CollectionType.onHold);
      expect(collectionTypeFromWire('DROPPED'), CollectionType.dropped);
    });

    test('collectionTypeFromWire throws FormatException for an unknown value', () {
      expect(() => collectionTypeFromWire('BOGUS'), throwsFormatException);
    });

    test('collectionTypeFromWireNullable returns null for null input', () {
      expect(collectionTypeFromWireNullable(null), isNull);
    });

    test('collectionTypeFromWireNullable parses a non-null value', () {
      expect(collectionTypeFromWireNullable('DOING'), CollectionType.doing);
    });

    test('collectionTypeToWireNullable returns null for null input', () {
      expect(collectionTypeToWireNullable(null), isNull);
    });

    test('collectionTypeToWireNullable serializes a non-null value', () {
      expect(collectionTypeToWireNullable(CollectionType.dropped), 'DROPPED');
    });
  });
}
