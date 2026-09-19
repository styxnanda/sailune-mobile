import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sailune_mobile/main.dart';
import 'package:sailune_mobile/screens/onboarding_screen.dart';
import 'package:sailune_mobile/theme.dart';

import 'support/fake_library.dart';

class _FailingPreferences extends FakeLibrary {
  @override
  Future<void> completeOnboarding() async =>
      throw Exception('Please try again');
}

void main() {
  setUpAll(() async {
    final fonts = FontLoader('Sailune');
    for (final weight in ['Regular', 'Medium', 'Bold']) {
      fonts.addFont(rootBundle.load('assets/fonts/Roboto-$weight.ttf'));
    }
    await fonts.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  testWidgets(
    'first launch supports next, back, swipe and persists completion',
    (tester) async {
      final library = FakeLibrary()..onboarded = false;
      await tester.pumpWidget(SailuneApp(library: library));
      await tester.pumpAndSettle();
      expect(find.text('Add a story'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Back'))
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Your appearance'), findsOneWidget);
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Add a story'), findsOneWidget);
      for (var i = 0; i < 3; i++) {
        await tester.drag(find.byType(PageView), const Offset(-700, 0));
        await tester.pumpAndSettle();
      }
      expect(find.text('Back up your library'), findsOneWidget);
      await tester.tap(find.text('Start reading'));
      await tester.pumpAndSettle();
      expect(library.onboarded, isTrue);
      expect(find.byType(OnboardingScreen), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(SailuneApp(library: library));
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingScreen), findsNothing);
    },
  );

  testWidgets(
    'skip saves completion; Settings can replay without changing stories',
    (tester) async {
      final library = FakeLibrary()..onboarded = false;
      await tester.pumpWidget(SailuneApp(library: library));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(library.onboarded, isTrue);
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Replay welcome tour'), 400);
      await tester.tap(find.text('Replay welcome tour'));
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingScreen), findsOneWidget);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(find.text('Make yourself at home'), findsOneWidget);
      expect(library.rows.length, 2);
    },
  );

  testWidgets('failed preference write keeps tour open and offers retry', (
    tester,
  ) async {
    await tester.pumpWidget(
      SailuneApp(library: _FailingPreferences()..onboarded = false),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('Please try again'), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Skip'))
          .onPressed,
      isNotNull,
    );
  });

  for (final size in [
    const Size(390, 844),
    const Size(320, 568),
    const Size(740, 360),
  ]) {
    testWidgets('tour fits $size with large text and reduced motion', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final dark in [false, true]) {
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: sailuneTheme(dark ? Brightness.dark : Brightness.light),
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: const TextScaler.linear(2),
                disableAnimations: true,
              ),
              child: OnboardingScreen(key: ValueKey(dark), onDone: () async {}),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (var i = 0; i < 3; i++) {
          await tester.tap(find.text('Next'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        expect(find.text('Start reading'), findsOneWidget);
      }
    });
  }

  for (final dark in [false, true]) {
    testWidgets('onboarding preview $dark', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: sailuneTheme(dark ? Brightness.dark : Brightness.light),
          home: OnboardingScreen(onDone: () async {}),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/onboarding_${dark ? 'dark' : 'light'}.png'),
      );
    });
  }
}
