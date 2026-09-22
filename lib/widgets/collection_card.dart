import 'package:flutter/material.dart';

import '../data/library.dart';
import '../models/story.dart';
import 'artwork.dart';

class CollectionCard extends StatelessWidget {
  final Library library;
  final Map<String, dynamic> overview;
  final String mode;
  final int revision;
  final VoidCallback onTap, onLongPress;
  const CollectionCard({
    super.key,
    required this.library,
    required this.overview,
    required this.mode,
    required this.onTap,
    required this.onLongPress,
    this.revision = 0,
  });
  @override
  Widget build(BuildContext context) {
    final c = overview['collection'] as Map;
    final stories = (overview['preview'] as List)
        .take(5)
        .map((s) => Story(Map<String, dynamic>.from(s as Map)))
        .toList();
    final colors = Theme.of(context).colorScheme;
    final art = mode != 'hidden';
    final ink = art ? Colors.white : colors.onSurface;
    final average = (overview['average'] as num).toDouble();
    return Semantics(
      label: '${c['name']}, ${overview['count']} stories',
      hint: 'Open collection. Hold to delete the collection without deleting stories.',
      child: Card(
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: SizedBox(
            height:
                220 +
                (MediaQuery.textScalerOf(context).scale(16) - 16).clamp(0, 64) *
                    2,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (stories.isNotEmpty)
                  ExcludeSemantics(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < stories.length; i++)
                          Expanded(
                            flex: i == 0
                                ? (stories.length == 1 ? 100 : 40)
                                : 60 ~/ (stories.length - 1),
                            child: ClipRect(
                              child: art
                                  ? StoryArtwork(
                                      library: library,
                                      id: stories[i].id,
                                      site: stories[i].site,
                                      role: mode == 'background'
                                          ? 'background'
                                          : 'cover',
                                      revision: revision,
                                      square: true,
                                    )
                                  : Container(
                                      decoration: BoxDecoration(
                                        border: Border(
                                          right: BorderSide(
                                            color: colors.outlineVariant,
                                          ),
                                        ),
                                      ),
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        14,
                                        0,
                                        0,
                                      ),
                                      child: OverflowBox(
                                        alignment: Alignment.topLeft,
                                        minWidth: 260,
                                        maxWidth: 260,
                                        child: Text(
                                          stories[i].title,
                                          maxLines: 3,
                                          overflow: TextOverflow.clip,
                                          style: TextStyle(
                                            fontSize: 32,
                                            height: 1.05,
                                            fontWeight: FontWeight.w700,
                                            color: colors.onSurface.withValues(
                                              alpha: .19,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                      ],
                    ),
                  ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: art
                          ? [
                              Colors.black.withValues(alpha: .12),
                              Colors.black.withValues(alpha: .85),
                            ]
                          : [
                              colors.surface.withValues(alpha: 0),
                              colors.surface,
                            ],
                      stops: const [0, .85],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        c['name'] as String,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ink,
                          fontSize: 23,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                          Text(
                            '${overview['count']} stories',
                            style: TextStyle(color: ink),
                          ),
                          Tooltip(
                            message:
                                'Average of ${overview['rated']} rated stories',
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (average > 0) ...[
                                  Icon(
                                    Icons.star_rounded,
                                    size: 16,
                                    color: ink,
                                  ),
                                  const SizedBox(width: 4),
                                ],
                                Text(
                                  average > 0
                                      ? '${average.toStringAsFixed(1)} / 5'
                                      : 'No ratings yet',
                                  style: TextStyle(color: ink),
                                ),
                              ],
                            ),
                          ),
                        ],
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
