import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sailune_mobile/main.dart';
import 'package:sailune_mobile/models/story.dart';
import 'package:sailune_mobile/screens/editor_screen.dart';
import 'package:sailune_mobile/screens/story_screen.dart';
import 'package:sailune_mobile/theme.dart';

import 'support/fake_library.dart';

void main() {
  setUpAll(() async {
    final text = FontLoader('Sailune');
    for (final weight in ['Regular', 'Medium', 'Bold']) {
      text.addFont(rootBundle.load('assets/fonts/Roboto-$weight.ttf'));
    }
    await text.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  testWidgets('empty library gives a real add path', (tester) async {
    await tester.pumpWidget(SailuneApp(library: FakeLibrary(rows: [])));
    await tester.pumpAndSettle();
    expect(find.text('A home for your stories'), findsOneWidget);
    await tester.tap(find.text('Add your first story'));
    await tester.pumpAndSettle();
    expect(find.text('Add a story'), findsOneWidget);
  });
  testWidgets('search is debounced and progress persists after opening', (
    tester,
  ) async {
    final library = FakeLibrary();
    await tester.pumpWidget(SailuneApp(library: library));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Mark next chapter read').first);
    await tester.pumpAndSettle();
    expect(library.rows.first['chapter'], 8);
    await tester.enterText(find.byType(TextField).first, 'map');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.text('The quiet between the stars'), findsNothing);
    expect(find.text('A map of little things'), findsOneWidget);
  });
  testWidgets('read next opens a resolved link without changing progress', (
    tester,
  ) async {
    final library = FakeLibrary();
    await tester.pumpWidget(SailuneApp(library: library));
    await tester.pumpAndSettle();
    await tester.tap(find.text('The quiet between the stars'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Read next chapter'));
    await tester.pumpAndSettle();
    expect(library.links.single, endsWith('/8'));
    expect(library.rows.first['chapter'], 7);
  });
  testWidgets('failed edit preserves form and patches only changed fields', (
    tester,
  ) async {
    final library = FakeLibrary()..failSave = true;
    await tester.pumpWidget(
      MaterialApp(
        theme: sailuneTheme(Brightness.light),
        home: EditorScreen(library: library, story: Story(sample())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Title'),
      'Changed title',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Save changes'),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save changes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(find.text('Could not save. Please try again.'), findsOneWidget);
    expect(library.requests.last['patch'], {'Title': 'Changed title'});
    library.failSave = false;
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save changes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(library.rows.first['title'], 'Changed title');
    expect(library.rows.first['chapter'], 7);
  });
  testWidgets('load failure offers recovery', (tester) async {
    final library = FakeLibrary()..failList = true;
    await tester.pumpWidget(SailuneApp(library: library));
    await tester.pumpAndSettle();
    expect(find.text('Library unavailable'), findsOneWidget);
    library.failList = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('The quiet between the stars'), findsOneWidget);
  });
  for (final dark in [false, true]) {
    testWidgets('reading room golden ${dark ? 'dark' : 'light'}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final library = FakeLibrary(
        rows: [
          {
            ...sample(),
            'site': 'ao3',
            'url': 'https://archiveofourown.org/works/1',
          },
          {...sample(id: 2), 'status': 'completed', 'chapter': 24},
        ],
      )..theme = dark ? 'dark' : 'light';
      await tester.pumpWidget(
        RepaintBoundary(child: SailuneApp(library: library)),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(SailuneApp),
        matchesGoldenFile('goldens/library_${dark ? 'dark' : 'light'}.png'),
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('large text and narrow screen do not overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(SailuneApp(library: FakeLibrary()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(
      MaterialApp(
        theme: sailuneTheme(Brightness.light),
        home: StoryScreen(library: FakeLibrary(), initial: Story(sample())),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
