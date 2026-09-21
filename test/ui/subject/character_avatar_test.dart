import 'package:animeko_flutter/data/subject/subject_models.dart';
import 'package:animeko_flutter/ui/subject/character_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Bangumi serves character art as *tall* portraits (`/r/400/pic/crt/...`,
/// measured at 400x533 up to 400x1164), so a circular avatar has to be cropped
/// to the *top* of the image. With the default centre alignment the visible
/// band lands on the torso and the row shows clothing instead of faces.
void main() {
  // flutter_test's HttpClient always fails, so `Image.network` resolves into its
  // errorBuilder. The `Image` widget itself stays in the tree either way, which
  // is what lets these tests inspect fit/alignment without real network access.
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('crops the portrait to its top so the face is visible', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const CharacterAvatar(
          character: CharacterInfo(
            id: 1,
            name: 'Zhu Huiyue',
            imageMedium: 'https://lain.bgm.tv/r/400/pic/crt/l/zhu.jpg',
          ),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.fit, BoxFit.cover);
    expect(image.alignment, Alignment.topCenter);
  });

  testWidgets('clips the image to a circle sized from the radius', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const CharacterAvatar(
          radius: 20,
          character: CharacterInfo(
            id: 1,
            name: 'Zhu Huiyue',
            imageMedium: 'https://lain.bgm.tv/r/400/pic/crt/l/zhu.jpg',
          ),
        ),
      ),
    );

    expect(find.byType(ClipOval), findsOneWidget);
    expect(tester.getSize(find.byType(ClipOval)), const Size(40, 40));
  });

  testWidgets('falls back to the person placeholder when there is no image', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const CharacterAvatar(
          character: CharacterInfo(id: 1, name: 'Zhu Huiyue'),
        ),
      ),
    );

    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.person), findsOneWidget);
  });

  testWidgets('falls back to the person placeholder when the image fails', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const CharacterAvatar(
          character: CharacterInfo(
            id: 1,
            name: 'Zhu Huiyue',
            imageMedium: 'https://lain.bgm.tv/r/400/pic/crt/l/zhu.jpg',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.person), findsOneWidget);
  });
}
