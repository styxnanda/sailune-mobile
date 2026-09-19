import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sailune_mobile/widgets/scrape_task.dart';

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

void main() {
  testWidgets('silent fetch has inline cancellation and no popup', (
    tester,
  ) async {
    final lib = PendingLibrary();
    final task = ScrapeTask(lib);
    addTearDown(task.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: InlineScrapeProgress(task: task)),
      ),
    );
    final result = task.run({'op': 'refresh'});
    final check = expectLater(result, throwsA(isA<ScrapeCancelled>()));
    await tester.pump();
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('Fetching website details…'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await check;
    expect(lib.cancelled, lib.started);
  });
  testWidgets('15 second total deadline cancels the native request', (
    tester,
  ) async {
    final lib = PendingLibrary();
    final task = ScrapeTask(lib);
    addTearDown(task.dispose);
    final check = expectLater(
      task.run({'op': 'refresh'}),
      throwsA(
        predicate((e) => e.toString().contains('Website details unavailable')),
      ),
    );
    await tester.pump(const Duration(seconds: 15));
    await check;
    expect(lib.cancelled, lib.started);
  });
  test('successful commit wins cancellation', () async {
    final lib = PendingLibrary()..committed = true;
    final task = ScrapeTask(lib);
    addTearDown(task.dispose);
    final result = task.run({'op': 'add'});
    await task.cancel();
    expect(await result, {'id': 1});
  });
  test('disposal cancels background work', () async {
    final lib = PendingLibrary();
    final task = ScrapeTask(lib);
    final check = expectLater(
      task.run({'op': 'refresh'}),
      throwsA(isA<ScrapeCancelled>()),
    );
    task.dispose();
    await check;
    expect(lib.cancelled, lib.started);
  });
}
