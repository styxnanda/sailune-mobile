import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

import '../models/story.dart';

const statusCycle = ['planned', 'reading', 'completed', 'hold', 'dropped'];

Color statusColor(String status) => switch (status) {
  'completed' => const Color(0xff386c50),
  'reading' => const Color(0xff395c84),
  'planned' => const Color(0xff71608c),
  'hold' => const Color(0xff866524),
  'dropped' => const Color(0xff8c535b),
  _ => const Color(0xff626873),
};

class StatusFold extends StatefulWidget {
  final String status;
  final Future<bool> Function(String)? onChanged;
  const StatusFold({super.key, required this.status, this.onChanged});
  @override
  State<StatusFold> createState() => _StatusFoldState();
}

class _StatusFoldState extends State<StatusFold>
    with SingleTickerProviderStateMixin {
  late final _settle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );
  Offset _drag = Offset.zero, _release = Offset.zero;
  bool _busy = false;
  bool _cancelled = false;
  final _pointers = <int>{};
  String? _preview;
  @override
  void initState() {
    super.initState();
    _settle.addListener(() {
      setState(
        () => _drag =
            _release * (1 - Curves.easeOutCubic.transform(_settle.value)),
      );
    });
  }

  @override
  void dispose() {
    _settle.dispose();
    super.dispose();
  }

  double get _distance =>
      _drag.dx.abs() >= _drag.dy.abs() ? _drag.dx : _drag.dy;
  String _next(int direction) {
    final index = statusCycle.indexOf(widget.status);
    return statusCycle[((index < 0 ? 0 : index) + direction) %
        statusCycle.length];
  }

  void _reset() {
    if (!mounted) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      setState(() {
        _drag = Offset.zero;
        _preview = null;
      });
    } else {
      _release = _drag;
      _settle.forward(from: 0).whenCompleteOrCancel(() {
        if (mounted) setState(() => _preview = null);
      });
    }
  }

  Future<void> _commit(int direction) async {
    if (_busy || widget.onChanged == null) {
      _reset();
      return;
    }
    final next = _next(direction);
    setState(() {
      _busy = true;
      _preview = next;
    });
    try {
      final saved = await widget.onChanged!(next);
      if (mounted && !saved) setState(() => _preview = null);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _reset();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = !_busy && widget.onChanged != null;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final amount = (_distance / 60).clamp(-1.0, 1.0);
    final color = Color.lerp(
      statusColor(widget.status),
      statusColor(_preview ?? _next(amount < 0 ? -1 : 1)),
      _preview != null ? 1 : amount.abs().clamp(0, .8),
    )!;
    return Listener(
      onPointerDown: (event) {
        _pointers.add(event.pointer);
        _cancelled = _pointers.length > 1;
      },
      onPointerUp: (event) => _pointers.remove(event.pointer),
      onPointerCancel: (event) {
        _pointers.remove(event.pointer);
        _cancelled = true;
      },
      child: Semantics(
        label: 'Story status',
        value: shelves[widget.status] ?? widget.status,
        increasedValue: shelves[_next(1)],
        decreasedValue: shelves[_next(-1)],
        onIncrease: enabled ? () => _commit(1) : null,
        onDecrease: enabled ? () => _commit(-1) : null,
        child: Tooltip(
          triggerMode: TooltipTriggerMode.tap,
          message: shelves[widget.status] ?? widget.status,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            dragStartBehavior: DragStartBehavior.down,
            onPanStart: enabled
                ? (_) {
                    _settle.stop();
                    setState(() {
                      _drag = Offset.zero;
                      _preview = null;
                    });
                  }
                : null,
            onPanUpdate: enabled
                ? (event) => setState(() {
                    _drag += event.delta;
                  })
                : null,
            onPanCancel: enabled ? _reset : null,
            onPanEnd: enabled
                ? (event) {
                    if (_cancelled) {
                      _reset();
                      return;
                    }
                    final speed = _drag.dx.abs() >= _drag.dy.abs()
                        ? event.velocity.pixelsPerSecond.dx
                        : event.velocity.pixelsPerSecond.dy;
                    if (_distance.abs() >= 20 ||
                        (_distance.abs() >= 8 && speed.abs() > 350)) {
                      _commit(_distance < 0 ? -1 : 1);
                    } else {
                      _reset();
                    }
                  }
                : null,
            child: SizedBox(
              width: 56,
              height: 56,
              child: Align(
                alignment: Alignment.topRight,
                child: Transform(
                  key: const ValueKey('fold-transform'),
                  alignment: Alignment.topRight,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, reduced || amount == 0 ? 0 : .002)
                    ..rotateZ(reduced ? 0 : amount * .3)
                    ..rotateY(reduced ? 0 : amount * math.pi * .42)
                    ..rotateX(reduced ? 0 : (_drag.dy / 100).clamp(-.5, .5)),
                  child: CustomPaint(
                    size: const Size(34, 34),
                    painter: FoldPainter(color),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class FoldPainter extends CustomPainter {
  final Color color;
  const FoldPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final triangle = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawShadow(triangle, Colors.black.withValues(alpha: .2), 2, false);
    canvas.drawPath(
      triangle,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: [color, Color.lerp(color, Colors.white, .28)!],
        ).createShader(Offset.zero & size),
    );
    canvas.drawLine(
      Offset.zero,
      Offset(size.width, size.height),
      Paint()
        ..color = Colors.white.withValues(alpha: .22)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(FoldPainter oldDelegate) => oldDelegate.color != color;
}
