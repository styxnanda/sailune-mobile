import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sailune_mobile/widgets/launch_reveal.dart';
import 'package:sailune_mobile/widgets/app_feedback.dart';
import 'package:sailune_mobile/theme.dart';

void main() {
  testWidgets(
    'cold launch covers the screen, settles into logo, and never replays',
    (tester) async {
      final logo = GlobalKey();
      Widget app(bool ready) => MaterialApp(
        theme: sailuneTheme(Brightness.dark),
        home: LaunchReveal(
          ready: ready,
          logoKey: logo,
          child: Scaffold(
            appBar: AppBar(title: SizedBox(key: logo, width: 30, height: 30)),
          ),
        ),
      );
      await tester.pumpWidget(app(false));
      expect(find.byType(ClipRRect), findsOneWidget);
      final initial = tester.getRect(find.byType(ClipRRect));
      expect(
        initial.size,
        tester.view.physicalSize / tester.view.devicePixelRatio,
      );
      await tester.pumpWidget(app(true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      final mid = tester.getRect(find.byType(ClipRRect));
      expect(mid.width, lessThan(initial.width));
      expect(mid.height, lessThan(initial.height));
      await tester.pumpAndSettle();
      expect(find.byType(ClipRRect), findsNothing);
      await tester.pumpWidget(app(true));
      await tester.pump();
      expect(find.byType(ClipRRect), findsNothing);
    },
  );

  testWidgets('reduced motion skips launch travel', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: LaunchReveal(
            ready: true,
            logoKey: GlobalKey(),
            child: const Scaffold(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ClipRRect), findsNothing);
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
