import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/library.dart';
import 'editor_screen.dart';

Future<bool?> showAddStorySheet(
  BuildContext context,
  Library library,
  Rect origin,
) {
  final reduceMotion = MediaQuery.disableAnimationsOf(context);
  final fillColor = Theme.of(context).colorScheme.primary;
  return Navigator.of(context).push<bool>(
    PageRouteBuilder<bool>(
      opaque: false,
      barrierDismissible: false,
      transitionDuration: Duration(milliseconds: reduceMotion ? 0 : 680),
      reverseTransitionDuration: Duration(milliseconds: reduceMotion ? 0 : 360),
      pageBuilder: (_, _, _) => EditorScreen(library: library, asSheet: true),
      transitionsBuilder: (context, animation, _, child) => AnimatedBuilder(
        animation: animation,
        child: child,
        builder: (context, child) {
          final media = MediaQuery.of(context);
          final size = media.size;
          final fill = const Interval(
            0,
            .42,
            curve: Curves.easeInOutCubic,
          ).transform(animation.value);
          final rise = const Interval(
            .42,
            1,
            curve: Curves.easeOutCubic,
          ).transform(animation.value);
          final target = Rect.fromLTWH(
            0,
            size.height * .68,
            size.width,
            size.height * .32,
          );
          final rectangle = Rect.lerp(origin, target, fill)!;
          final sheetHeight = math.max(
            0.0,
            math.min(
              size.height * .86,
              size.height - media.padding.top - media.viewInsets.bottom - 12,
            ),
          );
          return Stack(
            children: [
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: .32 * animation.value),
                ),
              ),
              Positioned.fromRect(
                rect: rectangle,
                child: Opacity(
                  opacity: animation.value == 0 ? 0 : 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: fillColor,
                      borderRadius: BorderRadius.circular(16 * (1 - fill)),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom:
                    media.viewInsets.bottom -
                    (1 - rise) * (sheetHeight + media.viewInsets.bottom),
                height: sheetHeight,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  child: MediaQuery.removeViewInsets(
                    context: context,
                    removeBottom: true,
                    child: child!,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
