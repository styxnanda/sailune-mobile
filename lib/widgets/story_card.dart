import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/story.dart';

class StoryCard extends StatelessWidget {
  final Story story;
  final VoidCallback onOpen;
  final ValueChanged<int>? onProgress;
  const StoryCard({
    super.key,
    required this.story,
    required this.onOpen,
    this.onProgress,
  });
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -28,
            bottom: -36,
            width: 182,
            height: 182,
            child: _SiteWatermark(site: story.site),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  children: [
                    const SizedBox(width: 22),
                    if (story.rating > 0) ...[
                      const Icon(Icons.star_rounded, size: 15),
                      const SizedBox(width: 3),
                      Text(
                        '${story.rating}',
                        semanticsLabel: '${story.rating} out of 5 stars',
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: _StatusRibbon(status: story.status),
                      ),
                    ),
                  ],
                ),
              ),
              Semantics(
                label: '${story.site} story',
                child: InkWell(
                  onTap: onOpen,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        Text(
                          story.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          story.author.isEmpty
                              ? 'Author unknown'
                              : 'by ${story.author}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: colors.onSurfaceVariant),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                story.fandoms.isEmpty
                                    ? 'Your next little escape'
                                    : story.fandoms.join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_rounded, size: 18),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      tooltip: 'Previous chapter',
                      onPressed: story.chapter > 0 && onProgress != null
                          ? () => onProgress!(story.chapter - 1)
                          : null,
                      icon: const Icon(Icons.remove_rounded, size: 20),
                    ),
                    Expanded(
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          story.progressLabel,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Mark next chapter read',
                      onPressed: !story.caughtUp && onProgress != null
                          ? () => onProgress!(story.chapter + 1)
                          : null,
                      icon: const Icon(Icons.add_rounded, size: 20),
                    ),
                  ],
                ),
              ),
              if (story.progress != null)
                LinearProgressIndicator(
                  value: story.progress,
                  minHeight: 3,
                  backgroundColor: colors.surfaceContainerHighest,
                  color: colors.onSurfaceVariant,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusRibbon extends StatelessWidget {
  final String status;
  const _StatusRibbon({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'completed' => const Color(0xff386c50),
      'reading' => const Color(0xff395c84),
      'planned' => const Color(0xff71608c),
      'hold' => const Color(0xff866524),
      'dropped' => const Color(0xff8c535b),
      _ => const Color(0xff626873),
    };
    return ClipPath(
      clipper: const _BookmarkClipper(),
      child: ColoredBox(
        color: color,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(23, 6, 20, 6),
          child: Text(
            shelves[status] ?? status,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: .2,
            ),
          ),
        ),
      ),
    );
  }
}

// A horizontal bookmark: the notched tail faces the card's center.
class _BookmarkClipper extends CustomClipper<Path> {
  const _BookmarkClipper();
  @override
  Path getClip(Size size) => Path()
    ..moveTo(0, 0)
    ..lineTo(size.width, 0)
    ..lineTo(size.width, size.height)
    ..lineTo(0, size.height)
    ..lineTo(10, size.height / 2)
    ..close();
  @override
  bool shouldReclip(_BookmarkClipper oldClipper) => false;
}

class _SiteWatermark extends StatelessWidget {
  final String site;
  const _SiteWatermark({required this.site});
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    // Silver on white, pearl on charcoal. Only the logo silhouette is shaded;
    // no plate, badge, or visible website label competes with the story title.
    final tones = dark
        ? const [Color(0x0ae1e6eb), Color(0x1affffff), Color(0x0ebbc4cd)]
        : const [Color(0x2496a0ab), Color(0x14778390), Color(0x2cb5bdc5)];
    return IgnorePointer(
      child: ExcludeSemantics(
        child: ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: tones,
            stops: const [0, .45, 1],
          ).createShader(bounds),
          child: SvgPicture.asset(
            site == 'AO3' ? 'assets/sites/ao3.svg' : 'assets/sites/ffn.svg',
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
