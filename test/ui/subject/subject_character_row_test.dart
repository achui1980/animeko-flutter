import 'dart:async';

import 'package:animeko_flutter/data/subject/subject_api.dart';
import 'package:animeko_flutter/data/subject/subject_models.dart';
import 'package:animeko_flutter/ui/subject/subject_character_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSubjectApi extends Mock implements SubjectApi {}

/// `imageMedium` 默认留 null，这样绝大多数 fixture 都不会让 `NetworkImage`
/// 在 `flutter_test` 里发起被拦截的 HTTP 请求并把异常报到测试上。只有
/// 「头像加载失败」那个测试显式传 URL —— 它要的正是那个被拦截的请求
/// (`statusCode: 400`) 触发 `onBackgroundImageError`。
RelatedCharacter related({
  required int id,
  required String name,
  String? nameCn,
  String? imageMedium,
  List<PersonInfo> actors = const [],
}) {
  return RelatedCharacter(
    index: id,
    character: CharacterInfo(
      id: id,
      name: name,
      nameCn: nameCn,
      imageMedium: imageMedium,
      actors: actors,
    ),
    role: 1,
  );
}

PersonInfo actor(String name) => PersonInfo(id: 900, name: name);

Widget wrap(Widget child, {required List<Override> overrides}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  late MockSubjectApi api;
  late List<Override> overrides;

  setUp(() {
    api = MockSubjectApi();
    overrides = [subjectApiProvider.overrideWithValue(api)];
  });

  testWidgets('renders one cell per character, preferring nameCn', (
    tester,
  ) async {
    when(() => api.getCharacters(1)).thenAnswer(
      (_) async => [
        related(id: 1, name: '黒崎一護', nameCn: '黑崎一护'),
        related(id: 2, name: '朽木ルキア'),
      ],
    );

    await tester.pumpWidget(
      wrap(const SubjectCharacterRow(subjectId: 1), overrides: overrides),
    );
    await tester.pumpAndSettle();

    expect(find.text('角色'), findsOneWidget);
    expect(find.text('黑崎一护'), findsOneWidget);
    expect(find.text('朽木ルキア'), findsOneWidget);
    expect(find.text('黒崎一護'), findsNothing);
  });

  testWidgets('shows the primary actor name below the character name', (
    tester,
  ) async {
    when(() => api.getCharacters(1)).thenAnswer(
      (_) async => [
        related(id: 1, name: '黑崎一护', actors: [actor('森田成一'), actor('ignored')]),
      ],
    );

    await tester.pumpWidget(
      wrap(const SubjectCharacterRow(subjectId: 1), overrides: overrides),
    );
    await tester.pumpAndSettle();

    expect(find.text('森田成一'), findsOneWidget);
    expect(find.text('ignored'), findsNothing);
  });

  testWidgets('omits the actor line when actors is empty', (tester) async {
    when(
      () => api.getCharacters(1),
    ).thenAnswer((_) async => [related(id: 1, name: '黑崎一护')]);

    await tester.pumpWidget(
      wrap(const SubjectCharacterRow(subjectId: 1), overrides: overrides),
    );
    await tester.pumpAndSettle();

    // 只有角色名一个 Text 在 cell 里（外加 header 的「角色」和按钮文字）。
    expect(find.text('黑崎一护'), findsOneWidget);
    expect(find.byIcon(Icons.person), findsOneWidget);
    // 并且 cell 里除了角色名没有第二个 `Text`：`actors` 为空时 CV 行必须
    // 整行不存在，而不是渲染成一个空/占位字符串。上一个测试证明 CV 行在
    // `actors` 非空时确实会渲染，所以这里断言的是真实的「缺席」。
    final cell = find
        .ancestor(of: find.text('黑崎一护'), matching: find.byType(Column))
        .first;
    expect(
      find.descendant(of: cell, matching: find.byType(Text)),
      findsOneWidget,
    );
  });

  testWidgets('renders the fallback icon when there is no avatar url', (
    tester,
  ) async {
    when(
      () => api.getCharacters(1),
    ).thenAnswer((_) async => [related(id: 1, name: 'A')]);

    await tester.pumpWidget(
      wrap(const SubjectCharacterRow(subjectId: 1), overrides: overrides),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.person), findsOneWidget);
  });

  testWidgets('renders the fallback icon when the avatar fails to load', (
    tester,
  ) async {
    when(() => api.getCharacters(1)).thenAnswer(
      (_) async => [
        related(
          id: 1,
          name: 'A',
          imageMedium: 'https://api.animeko.org/v2/characters/3320/image',
        ),
      ],
    );

    await tester.pumpWidget(
      wrap(const SubjectCharacterRow(subjectId: 1), overrides: overrides),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.person), findsOneWidget);
  });

  testWidgets('keeps the card frame and shows a spinner while loading', (
    tester,
  ) async {
    final pending = Completer<List<RelatedCharacter>>();
    when(() => api.getCharacters(1)).thenAnswer((_) => pending.future);

    await tester.pumpWidget(
      wrap(const SubjectCharacterRow(subjectId: 1), overrides: overrides),
    );
    await tester.pump();

    expect(find.text('角色'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    pending.complete(const []);
    await tester.pumpAndSettle();
  });

  testWidgets('hides the whole section on error', (tester) async {
    when(() => api.getCharacters(1)).thenThrow(Exception('boom'));

    await tester.pumpWidget(
      wrap(const SubjectCharacterRow(subjectId: 1), overrides: overrides),
    );
    await tester.pumpAndSettle();

    expect(find.text('角色'), findsNothing);
  });

  testWidgets('hides the whole section when the list is empty', (tester) async {
    when(() => api.getCharacters(1)).thenAnswer((_) async => []);

    await tester.pumpWidget(
      wrap(const SubjectCharacterRow(subjectId: 1), overrides: overrides),
    );
    await tester.pumpAndSettle();

    expect(find.text('角色'), findsNothing);
  });

  testWidgets('caps the inline row at maxVisible cells', (tester) async {
    when(() => api.getCharacters(1)).thenAnswer(
      (_) async => [
        for (var i = 0; i < SubjectCharacterRow.maxVisible + 3; i++)
          related(id: i, name: 'C$i'),
      ],
    );

    await tester.pumpWidget(
      wrap(const SubjectCharacterRow(subjectId: 1), overrides: overrides),
    );
    await tester.pumpAndSettle();

    expect(find.text('C0'), findsOneWidget);
    expect(find.text('C${SubjectCharacterRow.maxVisible - 1}'), findsOneWidget);
    expect(find.text('C${SubjectCharacterRow.maxVisible}'), findsNothing);
  });

  testWidgets('tapping 查看全部 opens the full-cast sheet', (tester) async {
    when(() => api.getCharacters(1)).thenAnswer(
      (_) async => [
        related(id: 1, name: '黑崎一护', actors: [actor('森田成一')]),
      ],
    );

    await tester.pumpWidget(
      wrap(const SubjectCharacterRow(subjectId: 1), overrides: overrides),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('查看全部 ›'));
    await tester.pumpAndSettle();

    expect(find.text('全部角色'), findsOneWidget);
    // sheet 复用横向行已经填好的 provider 缓存，不会再打一次接口。
    verify(() => api.getCharacters(1)).called(1);
  });
}
