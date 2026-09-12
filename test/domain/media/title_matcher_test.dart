// test/domain/media/title_matcher_test.dart
import 'package:animeko_flutter/data/anime1/anime1_models.dart';
import 'package:animeko_flutter/domain/media/title_matcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('matchBest', () {
    test('returns null for an empty candidate list', () {
      expect(matchBest(<Anime1Category>[], '葬送的芙莉蓮'), isNull);
    });

    test('returns the exact title match', () {
      const target = Anime1Category(id: 1, title: '葬送的芙莉蓮');
      const other = Anime1Category(id: 2, title: '無關的番劇');
      final result = matchBest([other, target], '葬送的芙莉蓮');
      expect(result, target);
    });

    test('matches case-insensitively and ignores whitespace', () {
      const target = Anime1Category(id: 1, title: 'Attack On Titan');
      final result = matchBest([target], 'attack  on titan');
      expect(result, target);
    });

    test('normalizes full-width Latin characters to half-width', () {
      const target = Anime1Category(id: 1, title: 'ＦＲＩＥＲＥＮ');
      final result = matchBest([target], 'FRIEREN');
      expect(result, target);
    });

    test('matches when one title contains the other', () {
      const target = Anime1Category(id: 1, title: '葬送的芙莉蓮 第二季');
      final result = matchBest([target], '葬送的芙莉蓮');
      expect(result, target);
    });

    test('returns null when no candidate is similar enough', () {
      const unrelated = Anime1Category(id: 1, title: '完全無關的標題');
      final result = matchBest([unrelated], '葬送的芙莉蓮');
      expect(result, isNull);
    });

    test('picks the highest-scoring candidate among several', () {
      const exact = Anime1Category(id: 1, title: '葬送的芙莉蓮');
      const partial = Anime1Category(id: 2, title: '葬送的芙莉蓮 特別篇');
      final result = matchBest([partial, exact], '葬送的芙莉蓮');
      expect(result, exact);
    });

    test('matches a Simplified-Chinese subject name against anime1.me\'s '
        'Traditional-Chinese title even when word order differs and the '
        'subject name carries extra subtitle text', () {
      const target = Anime1Category(id: 1948, title: '我是不才惡女');
      final result = matchBest([target], '恶女不才，请多关照 〇雏宫蝶鼠换身传〇');
      expect(result, target);
    });

    test('matches a reordered core title separated from an unrelated, '
        'much longer subtitle by a delimiter', () {
      const target = Anime1Category(id: 1, title: '太喜泼');
      final result = matchBest([target], '泼喜太，某个不相关的很长副标题内容');
      expect(result, target);
    });
  });

  group('titleSimilarity', () {
    test('identical strings score 1.0', () {
      expect(titleSimilarity('恶女不才，请多关照', '恶女不才，请多关照'), 1.0);
    });

    test('empty input scores 0', () {
      expect(titleSimilarity('', '恶女不才'), 0);
      expect(titleSimilarity('恶女不才', ''), 0);
      expect(titleSimilarity('', ''), 0);
    });

    test('containment scores by length ratio', () {
      expect(titleSimilarity('abcd', 'ab'), 0.5);
      expect(titleSimilarity('ab', 'abcd'), 0.5);
    });

    test('disjoint character sets score 0', () {
      expect(titleSimilarity('abc', 'xyz'), 0);
    });

    test('partial overlap scores by character-set ratio', () {
      // {a,b,c} vs {a,b,d}: intersection 2, union 4.
      expect(titleSimilarity('abc', 'abd'), 0.5);
    });

    test('a matching Mikan card title outranks an unrelated one', () {
      const subjectName = '恶女不才，请多关照 ～雏宫蝶鼠换身传～';
      const match = '恶女不才，请多关照'; // plausible Mikan 条目 card title
      const decoy = '不完美恶女 剧场版';
      expect(
        titleSimilarity(match, subjectName),
        greaterThan(titleSimilarity(decoy, subjectName)),
      );
    });
  });
}
