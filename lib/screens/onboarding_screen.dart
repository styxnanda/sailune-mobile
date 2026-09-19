import 'package:flutter/material.dart';

import '../data/library.dart';

const _pages = [
  (
    image: 'add',
    title: 'Add a story',
    caption: 'Tap Add story in your library. Paste a link to begin.',
  ),
  (
    image: 'appearance',
    title: 'Your appearance',
    caption: 'Find your theme in Settings, under Appearance.',
  ),
  (
    image: 'sessions',
    title: 'Sign in',
    caption: 'In Settings, open Website sessions and choose a site.',
  ),
  (
    image: 'backup',
    title: 'Back up your library',
    caption: 'Save or import a backup in Settings, under Your collection.',
  ),
];

class OnboardingScreen extends StatefulWidget {
  final Future<void> Function() onDone;
  const OnboardingScreen({super.key, required this.onDone});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _go(int page) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpToPage(page);
    } else {
      _controller.animateToPage(
        page,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Future<void> _finish() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onDone();
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mode = theme.brightness == Brightness.dark ? 'dark' : 'light';
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 12, 0),
                  child: Row(
                    children: [
                      const Spacer(),
                      TextButton(
                        onPressed: _saving ? null : _finish,
                        child: const Text('Skip'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: _pages.length,
                    onPageChanged: (page) => setState(() => _page = page),
                    itemBuilder: (context, index) {
                      final page = _pages[index];
                      return LayoutBuilder(
                        builder: (context, bounds) => SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            children: [
                              SizedBox(
                                height: (bounds.maxHeight * .66).clamp(
                                  300.0,
                                  460.0,
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (index > 0) ...[
                                        DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.surface,
                                            borderRadius: BorderRadius.circular(
                                              28,
                                            ),
                                            border: Border.all(
                                              color: theme
                                                  .colorScheme
                                                  .outlineVariant,
                                            ),
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                              right: 18,
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Image.asset(
                                                  'assets/onboarding/settings_$mode.png',
                                                  width: 48,
                                                  height: 48,
                                                  excludeFromSemantics: true,
                                                ),
                                                const Text(
                                                  'Settings',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 16,
                                          ),
                                          child: Icon(
                                            Icons.arrow_downward_rounded,
                                            size: 20,
                                            color: theme.colorScheme.outline,
                                          ),
                                        ),
                                      ],
                                      Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          DecoratedBox(
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(22),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: theme
                                                      .colorScheme
                                                      .shadow
                                                      .withValues(alpha: .10),
                                                  blurRadius: 36,
                                                  offset: const Offset(0, 16),
                                                ),
                                              ],
                                            ),
                                            child: Image.asset(
                                              'assets/onboarding/${page.image}_$mode.png',
                                              width: 342,
                                              fit: BoxFit.contain,
                                              excludeFromSemantics: true,
                                            ),
                                          ),
                                          Positioned(
                                            right: 30,
                                            top: index == 0 ? 24 : 34,
                                            child: ExcludeSemantics(
                                              child: Container(
                                                width: 34,
                                                height: 34,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: theme
                                                      .colorScheme
                                                      .surface
                                                      .withValues(alpha: .8),
                                                  border: Border.all(
                                                    color: theme
                                                        .colorScheme
                                                        .primary,
                                                    width: 1.5,
                                                  ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: theme
                                                          .colorScheme
                                                          .primary
                                                          .withValues(
                                                            alpha: .08,
                                                          ),
                                                      spreadRadius: 7,
                                                    ),
                                                  ],
                                                ),
                                                child: Icon(
                                                  Icons.touch_app_outlined,
                                                  size: 20,
                                                  color:
                                                      theme.colorScheme.primary,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                page.title,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -.6,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                page.caption,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Semantics(
                  label: 'Page ${_page + 1} of ${_pages.length}',
                  liveRegion: true,
                  child: ExcludeSemantics(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _pages.length,
                        (index) => AnimatedContainer(
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 12,
                          ),
                          height: 6,
                          width: index == _page ? 26 : 6,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: index == _page
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outlineVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Semantics(liveRegion: true, child: Text(_error!)),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _page == 0 || _saving
                              ? null
                              : () => _go(_page - 1),
                          child: const Text('Back'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: _saving
                              ? null
                              : _page == _pages.length - 1
                              ? _finish
                              : () => _go(_page + 1),
                          child: Text(
                            _saving
                                ? 'Opening…'
                                : _page == _pages.length - 1
                                ? 'Start reading'
                                : 'Next',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
