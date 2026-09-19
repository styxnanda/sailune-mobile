import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/story.dart';
import 'chapter_actions.dart';
import 'status_fold.dart';

class StoryCard extends StatelessWidget {
  final Story story;
  final VoidCallback onOpen;
  final ValueChanged<int>? onProgress;
  final Future<void> Function(bool copy)? onChapter;
  final VoidCallback? onDelete;
  final Future<bool> Function(String status)? onStatus;
  const StoryCard({
    super.key,
    required this.story,
    required this.onOpen,
    this.onProgress,
    this.onChapter,
    this.onDelete,
    this.onStatus,
  });
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onLongPress: onDelete,
      child: Card(
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
                Semantics(
                  label:
                      '${story.site} story, ${shelves[story.status] ?? story.status}',
                  child: InkWell(
                    onTap: onOpen,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(22, 20, 22, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 18),
                            child: Text(
                              story.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
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
                              if (story.rating > 0) ...[
                                const SizedBox(width: 8),
                                const Icon(Icons.star_rounded, size: 14),
                                const SizedBox(width: 3),
                                Text(
                                  '${story.rating}',
                                  semanticsLabel:
                                      '${story.rating} out of 5 stars',
                                ),
                              ],
                              const SizedBox(width: 12),
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
                        child: ChapterActions(
                          story: story,
                          onAction: onChapter,
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
            Positioned(
              top: 0,
              right: 0,
              child: StatusFold(status: story.status, onChanged: onStatus),
            ),
          ],
        ),
      ),
    );
  }
}

class _SiteWatermark extends StatelessWidget {
  final String site;
  const _SiteWatermark({required this.site});
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    // Low-opacity black on white, pearl on charcoal. Only the logo silhouette is shaded;
    // no plate, badge, or visible website label competes with the story title.
    final tones = dark
        ? const [Color(0x0ae1e6eb), Color(0x1affffff), Color(0x0ebbc4cd)]
        : const [Color(0x16000000), Color(0x0d000000), Color(0x1c000000)];
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
