import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sailune_mobile/data/library.dart';
import 'package:sailune_mobile/widgets/scrape_dialog.dart';

import 'support/fake_library.dart';

class PendingLibrary extends FakeLibrary {
  final response = Completer<dynamic>();
  String? started, cancelled;
  bool committed = false;
  @override
  Future<dynamic> call(Map<String, dynamic> request, {String? requestId}) {
    started = requestId;
    return response.future;
  }

  @override
  Future<void> cancel(String requestId) async {
    cancelled = requestId;
    if (committed) {
      response.complete({'id': 1});
    } else {
      response.completeError(
        PlatformException(code: 'library', message: 'context canceled'),
      );
    }
  }
}

Widget harness(Library library) => MaterialApp(
  home: Builder(
    builder: (context) => Scaffold(
      body: FilledButton(
        onPressed: () async {
          String text;
          try {
            await scrapeWithDialog(context, library, {
              'op': 'refresh',
              'id': 1,
            });
            text = 'Saved';
          } catch (e) {
            text = errorMessage(e);
          }
          if (context.mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(text)));
          }
        },
        child: const Text('Fetch'),
      ),
    ),
  ),
);

void main() {
  testWidgets('cycles five messages and cancel reaches the same request', (
    tester,
  ) async {
    final library = PendingLibrary();
    await tester.pumpWidget(harness(library));
    await tester.tap(find.text('Fetch'));
    await tester.pump(const Duration(milliseconds: 250));
    for (var i = 0; i < scrapeWaitMessages.length; i++) {
      expect(find.text(scrapeWaitMessages[i]), findsOneWidget);
      if (i < 4) {
        await tester.pump(const Duration(milliseconds: 2700));
        await tester.pump(const Duration(milliseconds: 460));
      }
    }
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(library.cancelled, library.started);
    expect(find.byType(Dialog), findsNothing);
    expect(
      find.text('Cancelled. Your details are still here.'),
      findsOneWidget,
    );
  });
  testWidgets(
    'fifteen seconds cancels the native request and explains recovery',
    (tester) async {
      final library = PendingLibrary();
      await tester.pumpWidget(harness(library));
      await tester.tap(find.text('Fetch'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 15));
      await tester.pumpAndSettle();
      expect(library.cancelled, library.started);
      expect(
        find.text('The website took too long. Try again or save offline.'),
        findsOneWidget,
      );
    },
  );
  testWidgets('a save that wins the cancel race is reported as saved', (
    tester,
  ) async {
    final library = PendingLibrary()..committed = true;
    await tester.pumpWidget(harness(library));
    await tester.tap(find.text('Fetch'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsOneWidget);
  });
  testWidgets('network failure closes overlay and returns its error', (
    tester,
  ) async {
    final library = PendingLibrary();
    await tester.pumpWidget(harness(library));
    await tester.tap(find.text('Fetch'));
    await tester.pump();
    library.response.completeError(
      PlatformException(code: 'library', message: 'Website unavailable'),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('Website unavailable'), findsOneWidget);
  });
}
