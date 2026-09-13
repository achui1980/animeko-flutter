import 'package:animeko_flutter/data/subject/subject_models.dart';
import 'package:animeko_flutter/ui/subject/subject_collection_stats.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatCount', () {
    test('三位以内原样输出', () {
      expect(formatCount(0), '0');
      expect(formatCount(7), '7');
      expect(formatCount(999), '999');
    });

    test('四位及以上插入千分位逗号', () {
      expect(formatCount(1000), '1,000');
      expect(formatCount(1449), '1,449');
      expect(formatCount(7781), '7,781');
      expect(formatCount(1234567), '1,234,567');
    });
  });

  group('SubjectCollectionStats', () {
    testWidgets('favorite 为 null 时什么都不渲染', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SubjectCollectionStats(favorite: null)),
        ),
      );

      expect(find.text('收藏'), findsNothing);
      expect(find.text('在看'), findsNothing);
      expect(find.text('想看'), findsNothing);
      // 三个标签不在还不够：整块必须什么都不渲染，而不是渲染三个 0。
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('按 done/doing/wish 映射到 收藏/在看/想看', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SubjectCollectionStats(
              favorite: SubjectFavorite(
                wish: 1449,
                done: 7781,
                doing: 5959,
                onHold: 360,
                dropped: 177,
              ),
            ),
          ),
        ),
      );

      expect(find.text('7,781'), findsOneWidget);
      expect(find.text('收藏'), findsOneWidget);
      expect(find.text('5,959'), findsOneWidget);
      expect(find.text('在看'), findsOneWidget);
      expect(find.text('1,449'), findsOneWidget);
      expect(find.text('想看'), findsOneWidget);

      // 上面六个断言只说明这六段文字都在，不说明谁配谁；把每个 _StatItem 的
      // Column 里「数字在上、标签在下」的配对也钉住，否则把 收藏/想看 两个
      // 标签对调的实现同样能通过这个测试。
      final pairs = <String, String>{};
      for (final column in tester.widgetList<Column>(find.byType(Column))) {
        final texts = column.children.whereType<Text>().toList();
        if (texts.length == 2) pairs[texts.last.data!] = texts.first.data!;
      }
      expect(pairs, {'收藏': '7,781', '在看': '5,959', '想看': '1,449'});
    });

    testWidgets('不展示 搁置/弃番 的数字', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SubjectCollectionStats(
              favorite: SubjectFavorite(
                wish: 1,
                done: 2,
                doing: 3,
                onHold: 360,
                dropped: 177,
              ),
            ),
          ),
        ),
      );

      expect(find.text('360'), findsNothing);
      expect(find.text('177'), findsNothing);
      expect(find.text('搁置'), findsNothing);
      expect(find.text('弃番'), findsNothing);
    });
  });
}
