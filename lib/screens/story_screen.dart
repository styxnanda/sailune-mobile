import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/library.dart';
import '../widgets/app_feedback.dart';
import '../models/story.dart';
import '../widgets/scrape_task.dart';
import 'editor_screen.dart';
import 'artwork_screen.dart';
import 'collections_screen.dart';
import '../widgets/artwork.dart';

class StoryScreen extends StatefulWidget {
  final Library library;
  final Story initial;
  const StoryScreen({super.key, required this.library, required this.initial});
  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen> {
  late Story _story;
  bool _busy = false, _detailArt = true;
  int _artRevision = 0;
  String? _error;
  late final ScrapeTask _scrape;
  @override
  void initState() {
    super.initState();
    _scrape = ScrapeTask(widget.library);
    _story = widget.initial;
    _loadArtworkPreference();
  }

  Future<void> _loadArtworkPreference() async {
    try {
      final p = await widget.library.device('loadArtworkPreferences') as Map;
      if (mounted) setState(() => _detailArt = p['details'] != false);
    } catch (_) {}
  }

  @override
  void dispose() {
    _scrape.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _update(Map<String, dynamic> request) async {
    final result = request['op'] == 'refresh'
        ? await _scrape.run(request)
        : await widget.library.call(request);
    if (mounted) {
      setState(() => _story = Story(Map<String, dynamic>.from(result as Map)));
    }
  }

  Future<void> _open(String op) async {
    final url =
        await widget.library.call({'op': op, 'id': _story.id}) as String;
    await widget.library.openLink(url);
  }

  Future<void> _delete() async {
    final confirmed = await confirmAction(
      context,
      title: 'Remove this bookmark?',
      message: 'Remove this story from your library?',
      confirm: 'Remove',
      cancel: 'Keep story',
    );
    if (confirmed == true) {
      await _run(() async {
        await widget.library.call({'op': 'delete', 'id': _story.id});
        if (mounted) Navigator.pop(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      extendBodyBehindAppBar: _detailArt,
      appBar: AppBar(
        backgroundColor: _detailArt ? Colors.transparent : null,
        actions: [
          IconButton(
            tooltip: 'Edit bookmark',
            onPressed: _busy
                ? null
                : () async {
                    final saved = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditorScreen(
                          library: widget.library,
                          story: _story,
                        ),
                      ),
                    );
                    if (saved == true && mounted) {
                      await _run(() => _update({'op': 'get', 'id': _story.id}));
                    }
                  },
            icon: const Icon(Icons.edit_outlined),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          if (_detailArt)
            StoryArtHeader(
              library: widget.library,
              id: _story.id,
              site: _story.site,
              revision: _artRevision,
            ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${_story.site}  ·  ${shelves[_story.status]}',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      _story.title,
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _story.author.isEmpty
                          ? 'Author unknown'
                          : 'by ${_story.author}',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _run(
                              () => _open(_story.caughtUp ? 'open' : 'resume'),
                            ),
                      icon: const Icon(Icons.auto_stories_outlined),
                      label: Text(
                        _story.caughtUp ? 'Read again' : 'Read next chapter',
                      ),
                    ),
                    const SizedBox(height: 16),
                    _DetailActions(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => assignCollection(
                            context,
                            widget.library,
                            _story.id,
                          ),
                          icon: const Icon(Icons.collections_bookmark_outlined),
                          label: const Text('Add to collection'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => ArtworkScreen(
                                  library: widget.library,
                                  story: _story,
                                ),
                              ),
                            );
                            if (mounted) setState(() => _artRevision++);
                          },
                          icon: const Icon(Icons.image_outlined),
                          label: const Text('Artwork'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (_story.fandoms.isNotEmpty) ...[
                      Text(
                        _story.fandoms.join(' · '),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (_story.summary.isNotEmpty)
                      Text(
                        _story.summary,
                        style: const TextStyle(height: 1.75, fontSize: 15),
                      ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        if (_story.words > 0)
                          Chip(label: Text('${_story.words} words')),
                        if (_story.chapters > 0)
                          Chip(label: Text('${_story.chapters} chapters')),
                        if ((_story.metadata['language'] as String? ?? '')
                            .isNotEmpty)
                          Chip(
                            label: Text(_story.metadata['language'] as String),
                          ),
                        if (_story.rating > 0)
                          Chip(
                            avatar: const Icon(Icons.star_rounded, size: 18),
                            label: Text('${_story.rating} / 5'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const SizedBox(height: 28),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            const Text(
                              'YOUR READING PROGRESS',
                              style: TextStyle(
                                fontSize: 10,
                                letterSpacing: 1.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                IconButton(
                                  tooltip: 'Previous chapter',
                                  onPressed: _busy || _story.chapter == 0
                                      ? null
                                      : () => _run(
                                          () => _update({
                                            'op': 'update',
                                            'id': _story.id,
                                            'patch': {
                                              'Chapter': _story.chapter - 1,
                                            },
                                          }),
                                        ),
                                  icon: const Icon(Icons.remove_rounded),
                                ),
                                Expanded(
                                  child: Column(
                                    children: [
                                      Text(
                                        '${_story.chapter}',
                                        style: const TextStyle(
                                          fontSize: 44,
                                          fontWeight: FontWeight.w500,
                                          fontFeatures: [
                                            FontFeature.tabularFigures(),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        _story.chapters > 0
                                            ? 'of ${_story.chapters} chapters'
                                            : 'chapters read',
                                        style: TextStyle(
                                          color: colors.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Mark next chapter read',
                                  onPressed: _busy || _story.caughtUp
                                      ? null
                                      : () => _run(
                                          () => _update({
                                            'op': 'update',
                                            'id': _story.id,
                                            'patch': {
                                              'Chapter': _story.chapter + 1,
                                            },
                                          }),
                                        ),
                                  icon: const Icon(Icons.add_rounded),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            if (_story.progress != null)
                              LinearProgressIndicator(
                                value: _story.progress,
                                borderRadius: BorderRadius.circular(8),
                                minHeight: 4,
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            _error!,
                            style: TextStyle(color: colors.error),
                          ),
                        ),
                      ),
                    InlineScrapeProgress(task: _scrape),
                    if (_busy && !_scrape.running)
                      const Padding(
                        padding: EdgeInsets.only(top: 20),
                        child: LinearProgressIndicator(),
                      ),
                    const SizedBox(height: 28),
                    if (_story.tags.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _story.tags
                            .map((tag) => Chip(label: Text(tag)))
                            .toList(),
                      ),
                    if (_story.notes.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text(
                        'Your notes',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      SelectableText(
                        _story.notes,
                        style: const TextStyle(height: 1.7),
                      ),
                    ],
                    const Divider(),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.refresh_rounded),
                      title: const Text('Refresh website details'),
                      onTap: _busy
                          ? null
                          : () => _run(
                              () => _update({'op': 'refresh', 'id': _story.id}),
                            ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.open_in_new_rounded),
                      title: const Text('Open website'),
                      onTap: _busy ? null : () => _run(() => _open('open')),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.link_rounded),
                      title: const Text('Copy story link'),
                      onTap: () async {
                        await Clipboard.setData(
                          ClipboardData(text: _story.url),
                        );
                        if (context.mounted) {
                          showAppNotice(context, 'Story link copied');
                        }
                      },
                    ),
                    const Divider(),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.delete_outline_rounded,
                        color: colors.error,
                      ),
                      title: Text(
                        'Remove bookmark',
                        style: TextStyle(color: colors.error),
                      ),
                      onTap: _busy ? null : _delete,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailActions extends StatelessWidget {
  final List<Widget> children;
  const _DetailActions({required this.children});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 320 ||
          MediaQuery.textScalerOf(context).scale(16) > 20) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [children[0], const SizedBox(height: 12), children[1]],
        );
      }
      return Row(
        children: [
          Expanded(flex: 3, child: children[0]),
          const SizedBox(width: 12),
          Expanded(flex: 2, child: children[1]),
        ],
      );
    },
  );
}
