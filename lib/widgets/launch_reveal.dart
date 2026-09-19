import 'package:flutter/material.dart';

/// Static branding while preferences load; no artificial delay or animation.
class LaunchReveal extends StatelessWidget {
  final Widget child;
  final bool ready;
  const LaunchReveal({super.key, required this.child, required this.ready});
  @override
  Widget build(BuildContext context) => ready
      ? child
      : ColoredBox(
          key: const ValueKey('launch-brand'),
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipOval(
                  child: Image.asset(
                    'assets/sailune.png',
                    width: 88,
                    height: 88,
                    excludeFromSemantics: true,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'sailune',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: -.7,
                  ),
                ),
              ],
            ),
          ),
        );
}
