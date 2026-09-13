import 'package:animeko_flutter/data/subject/bbcode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('stripBbcode', () {
    test('returns the input unchanged when there are no tags', () {
      expect(stripBbcode('对比老tv质的飞跃，观感不错。'), '对比老tv质的飞跃，观感不错。');
    });

    test('returns an empty string for empty input', () {
      expect(stripBbcode(''), '');
    });

    test('strips a simple paired tag but keeps its content', () {
      expect(stripBbcode('这集[b]太强了[/b]！'), '这集太强了！');
    });

    test('strips nested paired tags', () {
      expect(stripBbcode('[b][i]神作[/i][/b]无疑'), '神作无疑');
    });

    test('strips tags with parameters', () {
      expect(stripBbcode('[size=16]大字[/size]'), '大字');
      expect(stripBbcode('[url=https://example.com]链接[/url]'), '链接');
    });

    test('discards img tags entirely, including their content', () {
      expect(stripBbcode('看这个[img]https://example.com/a.jpg[/img]很棒'), '看这个很棒');
    });

    test('discards img tags with parameters', () {
      expect(stripBbcode('[img=100]https://example.com/a.jpg[/img]结束'), '结束');
    });

    test('strips an unclosed tag and keeps the remaining text', () {
      expect(stripBbcode('[b]没有闭合的粗体'), '没有闭合的粗体');
    });

    test('strips a stray closing tag', () {
      expect(stripBbcode('孤立的闭合标签[/b]'), '孤立的闭合标签');
    });

    test('handles a mix of everything', () {
      expect(stripBbcode('[b]总评[/b]：[img]x.jpg[/img]还[i]不错'), '总评：还不错');
    });
  });
}
