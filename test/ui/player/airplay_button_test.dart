// test/ui/player/airplay_button_test.dart
import 'package:animeko_flutter/data/play/airplay_cast_channel.dart';
import 'package:animeko_flutter/ui/player/airplay_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAirPlayCastChannel extends Mock implements AirPlayCastChannel {}

void main() {
  late MockAirPlayCastChannel channel;

  setUp(() {
    channel = MockAirPlayCastChannel();
    when(() => channel.events).thenAnswer((_) => const Stream.empty());
    when(
      () => channel.setButtonFrame(
        x: any(named: 'x'),
        y: any(named: 'y'),
        width: any(named: 'width'),
        height: any(named: 'height'),
      ),
    ).thenAnswer((_) async {});
    when(() => channel.setButtonVisible(any())).thenAnswer((_) async {});
  });

  Widget buildButton({required bool visible}) {
    return ProviderScope(
      overrides: [airPlayCastChannelProvider.overrideWith((ref) => channel)],
      child: MaterialApp(
        home: Scaffold(body: AirPlayButton(visible: visible)),
      ),
    );
  }

  testWidgets('reports setButtonVisible(true) once laid out when visible', (
    tester,
  ) async {
    await tester.pumpWidget(buildButton(visible: true));
    await tester.pumpAndSettle();

    verify(
      () => channel.setButtonVisible(true),
    ).called(greaterThanOrEqualTo(1));
    verify(
      () => channel.setButtonFrame(
        x: any(named: 'x'),
        y: any(named: 'y'),
        width: any(named: 'width'),
        height: any(named: 'height'),
      ),
    ).called(greaterThanOrEqualTo(1));
  });

  testWidgets('reports setButtonVisible(false) when not visible', (
    tester,
  ) async {
    await tester.pumpWidget(buildButton(visible: false));
    await tester.pumpAndSettle();

    verify(
      () => channel.setButtonVisible(false),
    ).called(greaterThanOrEqualTo(1));
    verifyNever(
      () => channel.setButtonFrame(
        x: any(named: 'x'),
        y: any(named: 'y'),
        width: any(named: 'width'),
        height: any(named: 'height'),
      ),
    );
  });

  testWidgets('reports setButtonVisible(false) on dispose', (tester) async {
    await tester.pumpWidget(buildButton(visible: true));
    await tester.pumpAndSettle();
    clearInteractions(channel);

    await tester.pumpWidget(const SizedBox());

    verify(() => channel.setButtonVisible(false)).called(1);
  });
}
