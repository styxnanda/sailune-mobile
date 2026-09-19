import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sailune_mobile/main.dart';
import 'package:sailune_mobile/screens/settings_screen.dart';
import 'package:sailune_mobile/theme.dart';
import 'package:sailune_mobile/widgets/story_card.dart';
import 'package:sailune_mobile/widgets/status_fold.dart';

import 'support/fake_library.dart';

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
  for (final dark in [false, true]) {
    testWidgets('card gestures and clipped settings highlight $dark', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final mode = dark ? 'dark' : 'light';
      final library = FakeLibrary(rows: [sample()])..theme = mode;
      await tester.pumpWidget(SailuneApp(library: library));
      await tester.runAsync(
        () => precacheImage(
          const AssetImage('assets/sailune.png'),
          tester.element(find.byType(SailuneApp)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chapter 7 / 24'));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(SailuneApp),
        matchesGoldenFile('goldens/chapter_actions_$mode.png'),
      );
      await tester.tap(find.text('Your reading room'));
      await tester.pumpAndSettle();
      final cardRect = tester.getRect(find.byType(StoryCard));
      final drag = await tester.startGesture(
        tester.getCenter(find.byType(StatusFold)),
      );
      await drag.moveBy(const Offset(-35, 10));
      await tester.pump();
      expect(tester.getRect(find.byType(StoryCard)), cardRect);
      await expectLater(
        find.byType(SailuneApp),
        matchesGoldenFile('goldens/status_twist_$mode.png'),
      );
      await drag.cancel();
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: sailuneTheme(dark ? Brightness.dark : Brightness.light),
          home: SettingsScreen(
            library: library,
            theme: mode,
            onTheme: (_) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final label in ['Follow device', 'Dark']) {
        final press = await tester.startGesture(
          tester.getCenter(find.text(label)),
        );
        await tester.pump(const Duration(milliseconds: 120));
        await tester.pump(const Duration(milliseconds: 480));
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/settings_hold_${label == 'Dark' ? 'bottom' : 'top'}_$mode.png',
          ),
        );
        await press.cancel();
        await tester.pumpAndSettle();
      }
    });
  }
}
