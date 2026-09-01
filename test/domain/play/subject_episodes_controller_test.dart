import 'package:animeko_flutter/data/anime1/anime1_models.dart';
import 'package:animeko_flutter/domain/play/subject_episodes_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('matchBestCategory', () {
    test('returns null for an empty candidate list', () {
      expect(matchBestCategory([], '葬送的芙莉蓮'), isNull);
    });

    test('returns the exact title match', () {
      const target = Anime1Category(id: 1, title: '葬送的芙莉蓮');
      const other = Anime1Category(id: 2, title: '無關的番劇');
      final result = matchBestCategory([other, target], '葬送的芙莉蓮');
      expect(result, target);
    });

    test('matches case-insensitively and ignores whitespace', () {
      const target = Anime1Category(id: 1, title: 'Attack On Titan');
      final result = matchBestCategory([target], 'attack  on titan');
      expect(result, target);
    });

    test('normalizes full-width Latin characters to half-width', () {
      const target = Anime1Category(id: 1, title: 'ＦＲＩＥＲＥＮ');
      final result = matchBestCategory([target], 'FRIEREN');
      expect(result, target);
    });

    test('matches when one title contains the other', () {
      const target = Anime1Category(id: 1, title: '葬送的芙莉蓮 第二季');
      final result = matchBestCategory([target], '葬送的芙莉蓮');
      expect(result, target);
    });

    test('returns null when no candidate is similar enough', () {
      const unrelated = Anime1Category(id: 1, title: '完全無關的標題');
      final result = matchBestCategory([unrelated], '葬送的芙莉蓮');
      expect(result, isNull);
    });

    test('picks the highest-scoring candidate among several', () {
      const exact = Anime1Category(id: 1, title: '葬送的芙莉蓮');
      const partial = Anime1Category(id: 2, title: '葬送的芙莉蓮 特別篇');
      final result = matchBestCategory([partial, exact], '葬送的芙莉蓮');
      expect(result, exact);
    });
  });
}
