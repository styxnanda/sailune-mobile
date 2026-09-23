import 'package:flutter/material.dart';

import '../models/story.dart';

class ChapterActions extends StatefulWidget {
  final Story story;
  final Future<void> Function(bool copy)? onAction;
  const ChapterActions({super.key, required this.story, this.onAction});
  @override
  State<ChapterActions> createState() => _ChapterActionsState();
}

class _ChapterActionsState extends State<ChapterActions> {
  bool _expanded = false;
  bool _busy = false;
  @override
  void didUpdateWidget(ChapterActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.story.chapter != widget.story.chapter) _expanded = false;
  }

  Future<void> _act(bool copy) async {
    if (_busy || widget.onAction == null) return;
    setState(() => _busy = true);
    try {
      await widget.onAction!(copy);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _expanded = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final chapter = widget.story.chapter.clamp(1, 2147483647);
    return TapRegion(
      onTapOutside: (_) {
        if (_expanded && !_busy) setState(() => _expanded = false);
      },
      child: AnimatedSwitcher(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, .15),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: _expanded
            ? Row(
                key: const ValueKey('chapter-actions'),
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Open chapter $chapter',
                    onPressed: _busy || widget.onAction == null
                        ? null
                        : () => _act(false),
                    icon: const Icon(Icons.open_in_new_rounded, size: 20),
                  ),
                  IconButton(
                    tooltip: 'Copy chapter $chapter link',
                    onPressed: _busy || widget.onAction == null
                        ? null
                        : () => _act(true),
                    icon: const Icon(Icons.link_rounded, size: 22),
                  ),
                ],
              )
            : Semantics(
                button: true,
                label: '${widget.story.progressLabel}, chapter actions',
                child: GestureDetector(
                  key: const ValueKey('chapter-count'),
                  onTap: widget.onAction == null
                      ? null
                      : () => setState(() => _expanded = true),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Center(
                      child: Text(
                        widget.story.progressLabel,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          fontFeatures: [FontFeature.tabularFigures()],
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
