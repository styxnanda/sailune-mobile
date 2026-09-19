import 'dart:async';

import 'package:flutter/material.dart';

import '../data/library.dart';

class ScrapeCancelled implements Exception {
  @override
  String toString() => 'Cancelled. Your details are still here.';
}

/// Owns one silent fetch; the screen renders progress inline, never a route.
class ScrapeTask extends ChangeNotifier {
  ScrapeTask(this.library);
  final Library library;
  static int _sequence = 0;
  String? _id;
  Timer? _deadline;
  bool cancelling = false, _timedOut = false, _disposed = false;
  bool get running => _id != null;

  Future<dynamic> run(Map<String, dynamic> request) async {
    if (running) throw StateError('A fetch is already running.');
    final id = 'scrape-${DateTime.now().microsecondsSinceEpoch}-${_sequence++}';
    _id = id;
    cancelling = false;
    _timedOut = false;
    _deadline = Timer(const Duration(seconds: 15), () => cancel(timeout: true));
    notifyListeners();
    try {
      // A successful commit wins a simultaneous cancellation.
      return await library.call(request, requestId: id);
    } catch (e) {
      if (_timedOut || errorMessage(e).contains('context deadline exceeded')) {
        throw Exception(
          'Website details unavailable. Try again later or save offline.',
        );
      }
      if (cancelling) throw ScrapeCancelled();
      rethrow;
    } finally {
      _deadline?.cancel();
      _id = null;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> cancel({bool timeout = false}) async {
    final id = _id;
    if (id == null || cancelling) return;
    cancelling = true;
    _timedOut = timeout;
    if (!_disposed) notifyListeners();
    try {
      await library.cancel(id);
    } catch (_) {
      /* Native deadline remains authoritative. */
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _deadline?.cancel();
    unawaited(cancel());
    super.dispose();
  }
}

class InlineScrapeProgress extends StatelessWidget {
  const InlineScrapeProgress({super.key, required this.task});
  final ScrapeTask task;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: task,
    builder: (context, _) => task.running
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                const Expanded(child: Text('Fetching website details…')),
                TextButton(
                  onPressed: task.cancelling ? null : () => task.cancel(),
                  child: Text(task.cancelling ? 'Cancelling…' : 'Cancel'),
                ),
              ],
            ),
          )
        : const SizedBox.shrink(),
  );
}
