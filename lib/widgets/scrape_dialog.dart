import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/library.dart';

const scrapeWaitMessages = [
  'Finding your story.',
  'Turning a few digital pages.',
  'Gathering the little details.',
  'Making room on your shelf.',
  'Some stories take a moment.',
];

class ScrapeCancelled implements Exception {
  @override
  String toString() => 'Cancelled. Your details are still here.';
}

class _Outcome {
  final dynamic value;
  final Object? error;
  const _Outcome({this.value, this.error});
}

Future<dynamic> scrapeWithDialog(
  BuildContext context,
  Library library,
  Map<String, dynamic> request,
) async {
  final outcome = await showDialog<_Outcome>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: .35),
    builder: (_) => _ScrapeDialog(library: library, request: request),
  );
  if (outcome == null) throw ScrapeCancelled();
  if (outcome.error != null) throw outcome.error!;
  return outcome.value;
}

class _ScrapeDialog extends StatefulWidget {
  final Library library;
  final Map<String, dynamic> request;
  const _ScrapeDialog({required this.library, required this.request});
  @override
  State<_ScrapeDialog> createState() => _ScrapeDialogState();
}

class _ScrapeDialogState extends State<_ScrapeDialog>
    with SingleTickerProviderStateMixin {
  static int _sequence = 0;
  late final String _id;
  late final AnimationController _spin;
  Timer? _messages, _deadline;
  int _message = 0;
  bool _cancelling = false, _timedOut = false, _finished = false;

  @override
  void initState() {
    super.initState();
    _id = 'scrape-${DateTime.now().microsecondsSinceEpoch}-${_sequence++}';
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _messages = Timer.periodic(const Duration(milliseconds: 2700), (_) {
      if (mounted) {
        setState(() => _message = (_message + 1) % scrapeWaitMessages.length);
      }
    });
    _deadline = Timer(
      const Duration(seconds: 15),
      () => _cancel(timeout: true),
    );
    _fetch();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _spin.stop();
    } else if (!_spin.isAnimating) {
      _spin.repeat();
    }
  }

  Future<void> _fetch() async {
    _Outcome outcome;
    try {
      final value = await widget.library.call(widget.request, requestId: _id);
      // A completed save wins over a simultaneous Cancel. Never report a saved
      // story as cancelled or encourage a duplicate retry.
      outcome = _Outcome(value: value);
    } catch (e) {
      final timeout =
          _timedOut || errorMessage(e).contains('context deadline exceeded');
      outcome = _Outcome(
        error: timeout
            ? Exception('The website took too long. Try again or save offline.')
            : _cancelling
            ? ScrapeCancelled()
            : e,
      );
    }
    _finished = true;
    _messages?.cancel();
    _deadline?.cancel();
    if (mounted) Navigator.of(context).pop(outcome);
  }

  Future<void> _cancel({bool timeout = false}) async {
    if (_finished || _cancelling) return;
    setState(() {
      _cancelling = true;
      _timedOut = timeout;
    });
    try {
      await widget.library.cancel(_id);
      // Wait for the native result to acknowledge cancellation (or a commit).
    } catch (_) {
      // The core has its own 15-second deadline even if channel cancellation
      // fails. Keep the operation visible until its authoritative result arrives.
    }
  }

  @override
  void dispose() {
    _messages?.cancel();
    _deadline?.cancel();
    _spin.dispose();
    if (!_finished) {
      unawaited(widget.library.cancel(_id).catchError((Object _) {}));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: Dialog(
        constraints: const BoxConstraints.tightFor(width: 280),
        backgroundColor: Theme.of(context).colorScheme.surface,
        insetPadding: const EdgeInsets.all(28),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 34, 28, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                label: 'Fetching story details',
                child: AnimatedBuilder(
                  animation: _spin,
                  builder: (_, _) => CustomPaint(
                    size: const Size(48, 48),
                    painter: _OrbitPainter(
                      _spin.value,
                      Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: AnimatedSwitcher(
                  duration: Duration(milliseconds: reducedMotion ? 0 : 450),
                  child: Text(
                    scrapeWaitMessages[_message],
                    key: ValueKey(_message),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, height: 1.6),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _cancelling ? null : () => _cancel(),
                child: Text(_cancelling ? 'Cancelling…' : 'Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrbitPainter extends CustomPainter {
  final double turn;
  final Color color;
  const _OrbitPainter(this.turn, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final bounds = (Offset.zero & size).deflate(4);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawOval(bounds, paint..color = color.withValues(alpha: .08));
    canvas.drawArc(
      bounds,
      turn * math.pi * 2,
      math.pi * .8,
      false,
      paint..color = color,
    );
    canvas.drawArc(
      bounds.deflate(7),
      -turn * math.pi * 2,
      math.pi * .5,
      false,
      paint..color = color.withValues(alpha: .35),
    );
  }

  @override
  bool shouldRepaint(_OrbitPainter oldDelegate) =>
      oldDelegate.turn != turn || oldDelegate.color != color;
}
