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
