import 'package:flutter/material.dart';

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          story.site,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: .5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          shelves[story.status] ?? story.status,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ),
                      if (story.rating > 0) ...[
                        const Icon(Icons.star_rounded, size: 15),
                        const SizedBox(width: 3),
                        Text('${story.rating}'),
                      ],
                    ],
                  ),
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
    );
  }
}
