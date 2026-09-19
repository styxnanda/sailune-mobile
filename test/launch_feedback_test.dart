import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sailune_mobile/widgets/launch_reveal.dart';
import 'package:sailune_mobile/widgets/app_feedback.dart';
import 'package:sailune_mobile/theme.dart';

void main() {
  testWidgets('launch is a static centered icon and name until ready', (
    tester,
  ) async {
    Widget app(bool ready) => MaterialApp(
      theme: sailuneTheme(Brightness.dark),
      home: LaunchReveal(
        ready: ready,
        child: const Scaffold(body: Text('Library')),
      ),
    );
    await tester.pumpWidget(app(false));
    expect(find.text('sailune'), findsOneWidget);
    expect(find.text('Library'), findsNothing);
    final before = tester.getRect(find.byType(Image));
    await tester.pump(const Duration(seconds: 2));
    expect(tester.getRect(find.byType(Image)), before);
    expect(before.size, const Size(88, 88));
    await tester.pumpWidget(app(true));
    expect(find.text('Library'), findsOneWidget);
    expect(find.byKey(const ValueKey('launch-brand')), findsNothing);
  });

  testWidgets('custom confirmation preserves explicit cancel and confirm', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: sailuneTheme(Brightness.dark),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await confirmAction(
                  context,
                  title: 'Remove this bookmark?',
                  message: 'The story stays on its website.',
                  confirm: 'Remove',
                  cancel: 'Keep story',
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(BottomSheet), findsOneWidget);
    await tester.tap(find.text('Keep story'));
    await tester.pumpAndSettle();
    expect(result, false);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(result, true);
  });
}
