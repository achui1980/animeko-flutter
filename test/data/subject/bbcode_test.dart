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

    test('strips a size tag with its parameter', () {
      expect(stripBbcode('[size=16]大字[/size]'), '大字');
    });

    test('strips a url tag with its parameter', () {
      expect(stripBbcode('[url=https://example.com]链接[/url]'), '链接');
    });

    test('discards img tags entirely, including their content', () {
      expect(stripBbcode('看这个[img]https://example.com/a.jpg[/img]很棒'), '看这个很棒');
    });

    test('discards img tags with parameters', () {
      expect(stripBbcode('[img=100]https://example.com/a.jpg[/img]结束'), '结束');
    });

    test('discards mask tags entirely, so spoilers are never leaked', () {
      expect(stripBbcode('[mask]主角最后死了[/mask]'), '');
    });

    test('keeps the prose surrounding a discarded mask tag', () {
      expect(stripBbcode('结局[mask]主角最后死了[/mask]很震撼'), '结局很震撼');
    });

    test('does not treat a mismatched block pair as a block', () {
      // The closing tag has to match the opening one; otherwise both are
      // stripped as stray tags and the text between them survives.
      expect(stripBbcode('[img]保留我[/mask]'), '保留我');
    });

    test('strips an unclosed tag and keeps the remaining text', () {
      expect(stripBbcode('[b]没有闭合的粗体'), '没有闭合的粗体');
    });

    test('strips a stray closing tag', () {
      expect(stripBbcode('孤立的闭合标签[/b]'), '孤立的闭合标签');
    });

    test('discards every img block when several appear in one input', () {
      expect(
        stripBbcode('前面[img]a.jpg[/img]中间正文[img]b.jpg[/img]后面'),
        '前面中间正文后面',
      );
    });

    test('discards an img block that spans multiple lines', () {
      expect(stripBbcode('前[img]https://x/\na.jpg[/img]后'), '前后');
    });

    test('discards an uppercase IMG block', () {
      expect(stripBbcode('[IMG]https://example.com/a.jpg[/IMG]结束'), '结束');
    });

    test('keeps literal square brackets that are not BBCode tags', () {
      expect(stripBbcode('我给[9/10]分，[b]神作[/b]'), '我给[9/10]分，神作');
    });

    test('trims whitespace left behind by a leading img block', () {
      expect(stripBbcode('[img]https://example.com/a.jpg[/img]\n正文'), '正文');
    });

    test('trims whitespace left behind by a trailing img block', () {
      expect(stripBbcode('正文\n[img]https://example.com/a.jpg[/img]'), '正文');
    });

    test('handles a mix of everything', () {
      expect(stripBbcode('[b]总评[/b]：[img]x.jpg[/img]还[i]不错'), '总评：还不错');
    });
  });
}
