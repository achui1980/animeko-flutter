import 'package:animeko_flutter/domain/subject_card.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SubjectCard stores required and optional fields', () {
    const card = SubjectCard(id: 1, name: 'Test Anime');
    expect(card.id, 1);
    expect(card.name, 'Test Anime');
    expect(card.nameCn, isNull);
    expect(card.imageUrl, isNull);
    expect(card.score, isNull);
    expect(card.tags, isNull);
    expect(card.airDate, isNull);
  });

  test('SubjectCard stores all fields when provided', () {
    const card = SubjectCard(
      id: 2,
      name: 'Full Anime',
      nameCn: '完整动漫',
      imageUrl: 'https://example.com/img.jpg',
      score: '8.5',
      tags: ['Comedy', 'Drama'],
      airDate: '2024-01-01',
    );
    expect(card.nameCn, '完整动漫');
    expect(card.imageUrl, 'https://example.com/img.jpg');
    expect(card.score, '8.5');
    expect(card.tags, ['Comedy', 'Drama']);
    expect(card.airDate, '2024-01-01');
  });
}
