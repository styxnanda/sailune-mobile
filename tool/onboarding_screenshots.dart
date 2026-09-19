// Regenerate: flutter test --update-goldens tool/onboarding_screenshots.dart
// Actual app screens with synthetic stories; no account information.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sailune_mobile/main.dart';
import 'package:sailune_mobile/screens/settings_screen.dart';
import 'package:sailune_mobile/theme.dart';

import '../test/support/fake_library.dart';

Future<void> cutout(
  WidgetTester tester,
  Finder target,
  String name, {
  double radius = 22,
}) async {
  final element = tester.element(target);
  RenderObject boundary = element.renderObject!;
  while (!boundary.isRepaintBoundary) {
    boundary = boundary.parent!;
  }
  final box = boundary as RenderBox;
  final rect = tester.getRect(target).shift(-box.localToGlobal(Offset.zero));
  final layer = boundary.debugLayer! as OffsetLayer;
  final source = await layer.toImage(rect, pixelRatio: 2);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final size = Size(source.width.toDouble(), source.height.toDouble());
  canvas.clipRRect(
    RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius * 2)),
  );
  canvas.drawImage(source, Offset.zero, Paint());
  final picture = recorder.endRecording();
  final image = await picture.toImage(source.width, source.height);
  await expectLater(image, matchesGoldenFile('../assets/onboarding/$name.png'));
  image.dispose();
  picture.dispose();
  source.dispose();
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
  for (final dark in [false, true]) {
    testWidgets('capture onboarding $dark', (tester) async {
      tester.view.physicalSize = const Size(390, 680);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final mode = dark ? 'dark' : 'light';
      final library = FakeLibrary(rows: [])..theme = mode;
      await tester.pumpWidget(SailuneApp(library: library));
      await tester.pumpAndSettle();
      await cutout(
        tester,
        find.widgetWithText(FilledButton, 'Add story'),
        'add_$mode',
      );
      await cutout(
        tester,
        find.byTooltip('Settings'),
        'settings_$mode',
        radius: 24,
      );
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
      await cutout(
        tester,
        find.ancestor(
          of: find.text('Follow device'),
          matching: find.byType(Card),
        ),
        'appearance_$mode',
      );
      await tester.ensureVisible(find.text('Website sessions'));
      await tester.pumpAndSettle();
      await cutout(
        tester,
        find.ancestor(
          of: find.text('Archive of Our Own'),
          matching: find.byType(Card),
        ),
        'sessions_$mode',
      );
      await tester.ensureVisible(find.text('Your collection'));
      await tester.pumpAndSettle();
      await cutout(
        tester,
        find.ancestor(
          of: find.text('Save a backup'),
          matching: find.byType(Card),
        ),
        'backup_$mode',
      );
    });
  }
}
