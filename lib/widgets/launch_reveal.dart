import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// One reveal per app instance, never on resume or a theme change.
class LaunchReveal extends StatefulWidget {
  final Widget child;
  final bool ready;
  final GlobalKey logoKey;
  const LaunchReveal({
    super.key,
    required this.child,
    required this.ready,
    required this.logoKey,
  });
  @override
  State<LaunchReveal> createState() => _LaunchRevealState();
}

class _LaunchRevealState extends State<LaunchReveal>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  bool _started = false;
  bool _finished = false;
  Rect? _target;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _schedule();
  }

  @override
  void didUpdateWidget(LaunchReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    _schedule();
  }

  void _schedule() {
    if (!widget.ready || _started) return;
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final box =
          widget.logoKey.currentContext?.findRenderObject() as RenderBox?;
      final root = context.findRenderObject() as RenderBox?;
      if (box != null && root != null) {
        _target = box.localToGlobal(Offset.zero, ancestor: root) & box.size;
      }
      if (!MediaQuery.disableAnimationsOf(context)) {
        await _animation.forward();
      }
      if (mounted) setState(() => _finished = true);
    });
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      AbsorbPointer(absorbing: !_finished, child: widget.child),
      if (!_finished)
        Positioned.fill(
          child: ExcludeSemantics(
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, _) => LayoutBuilder(
                builder: (context, bounds) {
                  final t = Curves.easeInOutCubic.transform(
                    ((_animation.value - .12) / .88).clamp(0.0, 1.0),
                  );
                  final start = Offset.zero & bounds.biggest;
                  final destination =
                      _target ??
                      Rect.fromCenter(
                        center: start.center,
                        width: 64,
                        height: 64,
                      );
                  final rect = Rect.lerp(start, destination, t)!;
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: ColoredBox(
                          color: Theme.of(context).scaffoldBackgroundColor
                              .withValues(alpha: 1 - t),
                        ),
                      ),
                      Positioned.fromRect(
                        rect: rect,
                        child: Opacity(
                          opacity: _target == null ? 1 - t : 1,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              lerpDouble(
                                0,
                                rect.shortestSide / 2,
                                (t * 3).clamp(0.0, 1.0),
                              )!,
                            ),
                            child: Image.asset(
                              'assets/sailune.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
    ],
  );
}
