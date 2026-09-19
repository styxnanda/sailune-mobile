import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sailune_mobile/screens/settings_screen.dart';

import 'support/fake_library.dart';

void main() {
  testWidgets('website login needs consent and clearing preserves bookmarks', (
    tester,
  ) async {
    final library = FakeLibrary();
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          library: library,
          theme: 'light',
          onTheme: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Archive of Our Own'), 200);
    await tester.tap(find.text('Archive of Our Own'));
    await tester.pumpAndSettle();
    expect(library.sessionConnections, isEmpty);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(library.sessionConnections, isEmpty);
    await tester.tap(find.text('Archive of Our Own'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue to website'));
    await tester.pumpAndSettle();
    expect(library.sessionConnections, ['ao3']);
    expect(find.text('Signed in'), findsWidgets);
    await tester.scrollUntilVisible(find.text('Clear website sessions'), 100);
    await tester.tap(find.text('Clear website sessions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep sessions'));
    await tester.pumpAndSettle();
    expect(library.sessions['ao3'], true);
    await tester.tap(find.text('Clear website sessions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear sessions'));
    await tester.pumpAndSettle();
    expect(library.sessions.values.every((v) => !v), true);
    expect(library.rows.length, 2);
  });
}
