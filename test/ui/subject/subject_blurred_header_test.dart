import 'package:animeko_flutter/ui/subject/subject_blurred_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SubjectBlurredHeader', () {
    testWidgets('renders a blurred background and a sharp foreground cover', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SubjectBlurredHeader(imageUrl: 'https://example.com/cover.png'),
          ),
        ),
      );

      // The blurred background layer.
      expect(find.byType(ImageFiltered), findsOneWidget);
      // Two Image widgets total: the blurred background + the sharp
      // foreground thumbnail.
      expect(find.byType(Image), findsNWidgets(2));
    });

    testWidgets('sizes itself to the fixed header height', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SubjectBlurredHeader(imageUrl: 'https://example.com/cover.png'),
          ),
        ),
      );

      final size = tester.getSize(find.byType(SubjectBlurredHeader));
      expect(size.height, SubjectBlurredHeader.height);
    });

    testWidgets('renders the optional info slot next to the thumbnail', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SubjectBlurredHeader(
              imageUrl: 'https://example.com/cover.png',
              info: const Text('Some Title'),
            ),
          ),
        ),
      );

      expect(find.text('Some Title'), findsOneWidget);
    });
  });
}
