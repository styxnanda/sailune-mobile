import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/library.dart';

class StoryArtwork extends StatefulWidget {
  final Library library;
  final int id;
  final String site, role;
  final bool small, faded;
  final int revision;
  const StoryArtwork({
    super.key,
    required this.library,
    required this.id,
    required this.site,
    this.role = 'cover',
    this.small = true,
    this.faded = false,
    this.revision = 0,
  });
  @override
  State<StoryArtwork> createState() => _StoryArtworkState();
}

class _StoryArtworkState extends State<StoryArtwork> {
  Uint8List? _bytes;
  double _x = .5, _y = .5;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant StoryArtwork old) {
    super.didUpdateWidget(old);
    if (old.id != widget.id ||
        old.role != widget.role ||
        old.revision != widget.revision ||
        old.small != widget.small) {
      _load();
    }
  }

  Future<void> _load() async {
    final generation = ++_generation;
    try {
      final arts = await organize(widget.library, {
        'action': 'artwork',
        'id': widget.id,
      }) as List;
      final matches = arts.where((a) => a['role'] == widget.role);
      if (matches.isEmpty) {
        if (mounted && generation == _generation) setState(() => _bytes = null);
        return;
      }
      final a = matches.first as Map;
      final data = await widget.library.device('artworkData', {
        'asset': a['asset_id'],
        'small': widget.small,
      });
      if (mounted && generation == _generation) {
        setState(() {
          _bytes = data as Uint8List?;
          _x = (a['x'] as num).toDouble();
          _y = (a['y'] as num).toDouble();
        });
      }
    } catch (_) {
      if (mounted && generation == _generation) setState(() => _bytes = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.role == 'cover' ? 9 : 0),
      child: ColoredBox(
        color: widget.faded ? Colors.transparent : c.surfaceContainerHighest,
        child: _bytes != null
            ? Opacity(
                opacity: widget.faded ? 0.15 : 1.0,
                child: Image.memory(
                  _bytes!,
                  fit: BoxFit.cover,
                  alignment: Alignment(_x * 2 - 1, _y * 2 - 1),
                  gaplessPlayback: true,
                  semanticLabel: widget.role == 'cover'
                      ? 'Story cover'
                      : 'Story background',
                ),
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  Align(
                    alignment: Alignment.bottomRight,
                    child: FractionallySizedBox(
                      widthFactor: .8,
                      heightFactor: .8,
                      child: Opacity(
                        opacity: .13,
                        child: SvgPicture.asset(
                          widget.site.toLowerCase() == 'ao3'
                              ? 'assets/sites/ao3.svg'
                              : 'assets/sites/ffn.svg',
                          colorFilter: ColorFilter.mode(
                            c.onSurface,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class StoryArtHeader extends StatelessWidget {
  final Library library;
  final int id, revision;
  final String site;
  const StoryArtHeader({
    super.key,
    required this.library,
    required this.id,
    required this.site,
    this.revision = 0,
  });
  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    return SizedBox(
      height: 320,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 215,
            child: StoryArtwork(
              library: library,
              id: id,
              site: site,
              role: 'background',
              small: false,
              revision: revision,
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 220,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [bg.withValues(alpha: 0), bg],
                  stops: const [.2, 1],
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Semantics(
                button: true,
                label: 'Preview cover artwork',
                child: GestureDetector(
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (_) => Dialog(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AspectRatio(
                              aspectRatio: 2 / 3,
                              child: StoryArtwork(
                                library: library,
                                id: id,
                                site: site,
                                small: false,
                                revision: revision,
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close preview'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  child: Container(
                    width: 144,
                    height: 216,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(9),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 16,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: StoryArtwork(
                      library: library,
                      id: id,
                      site: site,
                      small: false,
                      revision: revision,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
