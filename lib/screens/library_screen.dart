import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/library.dart';
import '../widgets/app_feedback.dart';
import '../models/story.dart';
import '../widgets/story_card.dart';
import '../widgets/library_navigation.dart';
import 'add_story_sheet.dart';
import 'story_screen.dart';
import 'settings_screen.dart';
import 'collections_screen.dart';

class LibraryScreen extends StatefulWidget {
  final Library library;
  final Map<String, dynamic>? collection;
  final String theme;
  final Future<void> Function(String) onTheme;
  const LibraryScreen({
    super.key,
    required this.library,
    this.collection,
    required this.theme,
    required this.onTheme,
  });
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with WidgetsBindingObserver {
  final _addButtonKey = GlobalKey();
  bool _adding = false;
  final _search = TextEditingController();
  final _scroll = ScrollController();
  final _saving = <int>{};
  List<Story> _stories = [];
  String _collection = '', _coverMode = 'hidden';
  bool _showCollections = false;
  Map<String, dynamic>? _collectionDetails;
  String _shelf = '', _site = '', _sort = 'added';
  bool _unread = false, _loading = true, _more = false;
  String? _error;
  int _generation = 0;
  Timer? _debounce;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _collectionDetails = widget.collection;
    _collection = widget.collection?['id'] as String? ?? '';
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load({bool append = false}) async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final prefs =
          await widget.library.device('loadArtworkPreferences') as Map;
      final rows = await listStories(widget.library, {
        'Collection': _collection,
        'Query': _search.text.trim(),
        'Status': _shelf,
        'Site': _site,
        'Sort': _sort,
        'Desc': _sort != 'title',
        'Unread': _unread,
        'Limit': 40,
        'Offset': append ? _stories.length : 0,
      });
      if (!mounted || generation != _generation) return;
      setState(() {
        _coverMode = prefs['mode'] as String? ?? 'hidden';

        _stories = append ? [..._stories, ...rows] : rows;
        _more = rows.length == 40;
        _loading = false;
      });
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() {
          _error = errorMessage(e);
          _loading = false;
        });
      }
    }
  }

  void _message(String text) {
    if (mounted) {
      showAppNotice(context, text);
    }
  }

  Future<void> _progress(Story story, int chapter) async {
    await _patch(story, {'Chapter': chapter});
  }

  Future<bool> _patch(Story story, Map<String, dynamic> patch) async {
    if (_saving.contains(story.id)) return false;
    setState(() => _saving.add(story.id));
    try {
      final data = await widget.library.call({
        'op': 'update',
        'id': story.id,
        'patch': patch,
      });
      if (mounted) {
        final updated = Story(Map<String, dynamic>.from(data as Map));
        setState(
          () => _stories = _stories
              .map((s) => s.id == story.id ? updated : s)
              .where((s) => _shelf.isEmpty || s.status == _shelf)
              .toList(),
        );
      }
      if (_collection.isNotEmpty && mounted) await _load();
      return true;
    } catch (e) {
      _message(errorMessage(e));
      return false;
    } finally {
      if (mounted) setState(() => _saving.remove(story.id));
    }
  }

  Future<void> _chapterAction(Story story, bool copy) async {
    if (_saving.contains(story.id)) return;
    setState(() => _saving.add(story.id));
    try {
      final url = await widget.library.call({
        'op': 'open',
        'id': story.id,
        'chapter': story.chapter < 1 ? 1 : story.chapter,
      }) as String;
      if (!mounted) return;
      if (copy) {
        await Clipboard.setData(ClipboardData(text: url));
      } else {
        await widget.library.openLink(url);
      }
    } catch (e) {
      _message(errorMessage(e));
    } finally {
      if (mounted) setState(() => _saving.remove(story.id));
    }
  }

  Future<void> _delete(Story story) async {
    if (_saving.contains(story.id)) return;
    final confirmed = await confirmAction(
      context,
      title: 'Remove this bookmark?',
      message: story.title,
      confirm: 'Remove',
      cancel: 'Keep story',
    );
    if (confirmed != true || !mounted || _saving.contains(story.id)) return;
    setState(() => _saving.add(story.id));
    try {
      await widget.library.call({'op': 'delete', 'id': story.id});
      if (mounted) await _load();
    } catch (e) {
      _message(errorMessage(e));
    } finally {
      if (mounted) setState(() => _saving.remove(story.id));
    }
  }

  Future<void> _removeFromCollection(Story story) async {
    if (_saving.contains(story.id) || _collection.isEmpty) return;
    final confirmed = await confirmAction(
      context,
      title: 'Remove from collection?',
      message: '“${story.title}” will stay in your library.',
      confirm: 'Remove from collection',
      cancel: 'Keep story here',
    );
    if (confirmed != true || !mounted || _saving.contains(story.id)) return;
    setState(() => _saving.add(story.id));
    try {
      await organize(widget.library, {
        'action': 'membership',
        'collection_id': _collection,
        'ids': [story.id],
        'remove': true,
      });
      if (mounted) await _load();
    } catch (e) {
      _message(errorMessage(e));
    } finally {
      if (mounted) setState(() => _saving.remove(story.id));
    }
  }

  Future<void> _edit() async {
    if (_adding) return;
    _adding = true;
    final box = _addButtonKey.currentContext!.findRenderObject() as RenderBox;
    final origin = box.localToGlobal(Offset.zero) & box.size;
    final saved = await showAddStorySheet(context, widget.library, origin);
    _adding = false;
    if (!mounted) return;
    if (saved == true) {
      await _load();
      _message('Story added to your library');
    }
  }

  Future<void> _open(Story story) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StoryScreen(library: widget.library, initial: story),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _filters() async {
    var site = _site, sort = _sort;
    var unread = _unread;
    final applied = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Find your next story',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 24),
                DropdownButtonFormField<String>(
                  initialValue: site,
                  decoration: const InputDecoration(labelText: 'Website'),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('All websites')),
                    DropdownMenuItem(
                      value: 'ao3',
                      child: Text('Archive of Our Own'),
                    ),
                    DropdownMenuItem(
                      value: 'ffn',
                      child: Text('FanFiction.net'),
                    ),
                  ],
                  onChanged: (value) => update(() => site = value!),
                ),
                const SizedBox(height: 18),
                DropdownButtonFormField<String>(
                  initialValue: sort,
                  decoration: const InputDecoration(labelText: 'Sort by'),
                  items: const [
                    DropdownMenuItem(
                      value: 'added',
                      child: Text('Recently added'),
                    ),
                    DropdownMenuItem(
                      value: 'last-read',
                      child: Text('Recently read'),
                    ),
                    DropdownMenuItem(value: 'title', child: Text('Title, A–Z')),
                    DropdownMenuItem(
                      value: 'rating',
                      child: Text('Highest rated'),
                    ),
                  ],
                  onChanged: (value) => update(() => sort = value!),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Unread chapters'),
                  value: unread,
                  onChanged: (value) => update(() => unread = value),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Apply filters'),
                ),
                TextButton(
                  onPressed: () {
                    update(() {
                      site = '';
                      sort = 'added';
                      unread = false;
                    });
                  },
                  child: const Text('Reset filters'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (applied == true && mounted) {
      setState(() {
        _site = site;
        _sort = sort;
        _unread = unread;
      });
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final refined = _site.isNotEmpty || _sort != 'added' || _unread;
    if (_showCollections && widget.collection == null) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
            setState(() => _showCollections = false);
            _load();
          }
        },
        child: CollectionsScreen(
          library: widget.library,
          theme: widget.theme,
          onTheme: widget.onTheme,
          onLibrary: () {
            setState(() => _showCollections = false);
            _load();
          },
          onOpen: (collection) async {
            await Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => LibraryScreen(
                  library: widget.library,
                  theme: widget.theme,
                  onTheme: widget.onTheme,
                  collection: collection,
                ),
              ),
            );
          },
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        bottom: widget.collection == null
            ? LibraryNavigation(
                collections: false,
                onLibrary: () {},
                onCollections: () => setState(() => _showCollections = true),
              )
            : null,
        title: widget.collection != null
            ? Text(_collectionDetails?['name'] as String? ?? 'Collection')
            : Row(
                children: [
                  ClipOval(
                    child: Image.asset(
                      'assets/sailune.png',
                      width: 30,
                      height: 30,
                      excludeFromSemantics: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'sailune',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -.7,
                    ),
                  ),
                ],
              ),
        actions: [
          if (_collectionDetails?['kind'] == 'manual')
            IconButton(
              tooltip: 'Add or remove collection stories',
              icon: const Icon(Icons.playlist_add_rounded),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => CollectionEditor(
                      library: widget.library,
                      collection: _collectionDetails,
                      membersOnly: true,
                    ),
                  ),
                );
                if (mounted) _load();
              },
            ),
          if (widget.collection != null)
            IconButton(
              tooltip: 'Edit collection details',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => CollectionEditor(
                      library: widget.library,
                      collection: _collectionDetails,
                    ),
                  ),
                );
                if (!mounted) return;
                final rows = await organize(widget.library, {
                  'action': 'collections',
                }) as List;
                final found = rows.where((c) => c['id'] == _collection);
                if (!mounted) return;
                if (found.isEmpty) {
                  Navigator.pop(this.context);
                  return;
                }
                setState(
                  () => _collectionDetails = Map<String, dynamic>.from(
                    found.first as Map,
                  ),
                );
                _load();
              },
            ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.tune_rounded),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(
                    library: widget.library,
                    theme: widget.theme,
                    onTheme: widget.onTheme,
                  ),
                ),
              );
              if (mounted) await _load();
            },
          ),
          const SizedBox(width: 10),
        ],
      ),
      bottomNavigationBar: widget.collection != null
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                child: FilledButton.icon(
                  key: _addButtonKey,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                  ),
                  onPressed: _edit,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add story'),
                ),
              ),
            ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: RefreshIndicator(
              onRefresh: _load,
              child: CustomScrollView(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _collectionDetails?['name'] as String? ??
                                'Your reading room',
                            style: Theme.of(context).textTheme.headlineLarge,
                          ),
                          if (widget.collection == null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Good stories. A little space for yourself.',
                              style: TextStyle(
                                color: colors.onSurfaceVariant,
                                height: 1.5,
                              ),
                            ),
                          ],
                          const SizedBox(height: 26),
                          TextField(
                            controller: _search,
                            onChanged: (_) {
                              _debounce?.cancel();
                              _debounce = Timer(
                                const Duration(milliseconds: 300),
                                () => _load(),
                              );
                            },
                            textInputAction: TextInputAction.search,
                            onSubmitted: (_) {
                              _debounce?.cancel();
                              _load();
                            },
                            decoration: InputDecoration(
                              hintText: 'Search your stories',
                              prefixIcon: const Icon(Icons.search_rounded),
                              suffixIcon: IconButton(
                                tooltip: 'Clear search',
                                icon: const Icon(Icons.close_rounded, size: 18),
                                onPressed: () {
                                  _search.clear();
                                  _debounce?.cancel();
                                  _load();
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _shelf,
                                    isExpanded: true,
                                    borderRadius: BorderRadius.circular(18),
                                    items: shelves.entries
                                        .map(
                                          (e) => DropdownMenuItem(
                                            value: e.key,
                                            child: Text(
                                              e.value,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (value) {
                                      setState(() => _shelf = value!);
                                      _load();
                                    },
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: refined
                                    ? 'Filters applied'
                                    : 'Filter stories',
                                onPressed: _filters,
                                icon: Badge(
                                  isLabelVisible: refined,
                                  smallSize: 6,
                                  backgroundColor: colors.primary,
                                  child: const Icon(Icons.filter_list_rounded),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                  if (_error != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            const Icon(Icons.cloud_off_rounded, size: 32),
                            const SizedBox(height: 12),
                            Text(_error!, textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: () => _load(),
                              child: const Text('Try again'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_loading && _stories.isEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(60),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                  if (!_loading && _error == null && _stories.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(32, 52, 32, 60),
                        child: Column(
                          children: [
                            Icon(
                              Icons.auto_stories_outlined,
                              size: 52,
                              color: colors.onSurfaceVariant,
                            ),
                            const SizedBox(height: 24),
                            Text(
                              _search.text.isEmpty && _shelf.isEmpty && !refined
                                  ? 'A home for your stories'
                                  : 'No stories here yet',
                              style: Theme.of(context).textTheme.titleLarge,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _search.text.isEmpty && _shelf.isEmpty && !refined
                                  ? (widget.collection == null
                                        ? 'Save a story from AO3 or FanFiction.net.\nPick up right where you left off.'
                                        : 'Use the icons above to edit this collection or add stories.')
                                  : 'Try another shelf or adjust your search.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: colors.onSurfaceVariant,
                                height: 1.7,
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    sliver: SliverList.separated(
                      itemCount: _stories.length,
                      itemBuilder: (context, index) {
                        final story = _stories[index];
                        return StoryCard(
                          key: ValueKey(story.id),
                          story: story,
                          library: widget.library,
                          coverMode: _coverMode,
                          artRevision: _generation,
                          onOpen: () => _open(story),
                          onDelete: _saving.contains(story.id)
                              ? null
                              : widget.collection != null &&
                                    _collectionDetails?['kind'] == 'manual'
                              ? () => _removeFromCollection(story)
                              : () => _delete(story),
                          onChapter: _saving.contains(story.id)
                              ? null
                              : (copy) => _chapterAction(story, copy),
                          onStatus: _saving.contains(story.id)
                              ? null
                              : (status) => _patch(story, {'Status': status}),
                          onProgress: _saving.contains(story.id)
                              ? null
                              : (value) => _progress(story, value),
                        );
                      },
                      separatorBuilder: (_, index) =>
                          const SizedBox(height: 14),
                    ),
                  ),
                  if (_more)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: OutlinedButton(
                          onPressed: _loading
                              ? null
                              : () => _load(append: true),
                          child: Text(
                            _loading ? 'Loading…' : 'Load more stories',
                          ),
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
