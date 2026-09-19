import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sailune_mobile/main.dart';
import 'package:sailune_mobile/widgets/story_card.dart';
import 'package:sailune_mobile/widgets/status_fold.dart';
import 'package:sailune_mobile/screens/story_screen.dart';

import 'support/fake_library.dart';

void main() {
  testWidgets(
    'chapter actions open and copy the displayed chapter without changing progress',
    (tester) async {
      final library = FakeLibrary();
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(SailuneApp(library: library));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chapter 7 / 24'));
      await tester.pumpAndSettle();
      expect(find.text('Chapter 7 / 24'), findsNothing);
      await tester.tap(find.byTooltip('Open chapter 7'));
      await tester.pumpAndSettle();
      expect(library.links.single, endsWith('/7'));
      expect(library.rows.first['chapter'], 7);
      await tester.tap(find.text('Chapter 7 / 24'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Copy chapter 7 link'));
      await tester.pumpAndSettle();
      expect(copied, endsWith('/7'));
      expect(library.requests.where((r) => r['op'] == 'update'), isEmpty);
      expect(find.text('Chapter 7 / 24'), findsOneWidget);
      await tester.tap(find.text('Chapter 7 / 24'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Your reading room'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Open chapter 7'), findsNothing);
    },
  );

  testWidgets('chapter zero opens the first chapter', (tester) async {
    final library = FakeLibrary(
      rows: [
        {...sample(), 'chapter': 0},
      ],
    );
    await tester.pumpWidget(SailuneApp(library: library));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chapter 0 / 24'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open chapter 1'));
    await tester.pumpAndSettle();
    expect(library.links.single, endsWith('/1'));
    expect(library.rows.single['chapter'], 0);
  });

  testWidgets('long press asks before deletion and never opens story', (
    tester,
  ) async {
    final library = FakeLibrary();
    await tester.pumpWidget(SailuneApp(library: library));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('The quiet between the stars'));
    await tester.pumpAndSettle();
    expect(find.byType(StoryScreen), findsNothing);
    expect(find.text('Remove this bookmark?'), findsOneWidget);
    await tester.tap(find.text('Keep story'));
    await tester.pumpAndSettle();
    expect(library.rows.length, 2);
    await tester.longPress(find.text('The quiet between the stars'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(library.rows.length, 1);
    expect(find.text('The quiet between the stars'), findsNothing);
  });

  testWidgets(
    'fold alone twists, persists both directions, and rolls back a failure',
    (tester) async {
      final library = FakeLibrary(rows: [sample()]);
      await tester.pumpWidget(SailuneApp(library: library));
      await tester.pumpAndSettle();
      final cardRect = tester.getRect(find.byType(StoryCard));
      final corner = find.byType(StatusFold);
      final gesture = await tester.startGesture(tester.getCenter(corner));
      await gesture.moveBy(const Offset(38, 0));
      await tester.pump();
      final transform = tester.widget<Transform>(
        find.byKey(const ValueKey('fold-transform')),
      );
      expect(transform.transform.isIdentity(), isFalse);
      expect(tester.getRect(find.byType(StoryCard)), cardRect);
      expect(library.rows.single['status'], 'reading');
      await gesture.up();
      await tester.pumpAndSettle();
      expect(library.rows.single['status'], 'completed');
      expect(tester.getRect(find.byType(StoryCard)), cardRect);
      await tester.drag(corner, const Offset(-65, 0));
      await tester.pumpAndSettle();
      expect(library.rows.single['status'], 'reading');
      library.failSave = true;
      await tester.drag(corner, const Offset(65, 0));
      await tester.pumpAndSettle();
      expect(library.rows.single['status'], 'reading');
      expect(tester.widget<StatusFold>(corner).status, 'reading');
      expect(
        tester
            .widget<Transform>(find.byKey(const ValueKey('fold-transform')))
            .transform
            .isIdentity(),
        isTrue,
      );
    },
  );

  testWidgets('tiny swipe and cancelled swipe do not write; statuses wrap', (
    tester,
  ) async {
    final library = FakeLibrary(
      rows: [
        {...sample(), 'status': 'planned'},
      ],
    );
    await tester.pumpWidget(SailuneApp(library: library));
    await tester.pumpAndSettle();
    final corner = find.byType(StatusFold);
    await tester.drag(corner, const Offset(5, 0));
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(tester.getCenter(corner));
    await gesture.moveBy(const Offset(45, 0));
    await tester.pump();
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(library.requests.where((r) => r['op'] == 'update'), isEmpty);
    await tester.drag(corner, const Offset(-65, 0));
    await tester.pumpAndSettle();
    expect(library.rows.single['status'], 'dropped');
  });
  testWidgets('status change respects the active shelf', (tester) async {
    final library = FakeLibrary(rows: [sample()]);
    await tester.pumpWidget(SailuneApp(library: library));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reading').last);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(StatusFold), const Offset(65, 0));
    await tester.pumpAndSettle();
    expect(library.rows.single['status'], 'completed');
    expect(find.byType(StoryCard), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'reduced motion changes status without twisting or moving the card',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final library = FakeLibrary(rows: [sample()]);
      await tester.pumpWidget(SailuneApp(library: library));
      await tester.pumpAndSettle();
      final drag = await tester.startGesture(
        tester.getCenter(find.byType(StatusFold)),
      );
      await drag.moveBy(const Offset(45, 0));
      await tester.pump();
      expect(
        tester
            .widget<Transform>(find.byKey(const ValueKey('fold-transform')))
            .transform
            .isIdentity(),
        isTrue,
      );
      await drag.up();
      await tester.pumpAndSettle();
      expect(library.rows.single['status'], 'completed');
    },
  );
}
