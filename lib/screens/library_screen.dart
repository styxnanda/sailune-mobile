import 'dart:async';

import 'package:flutter/material.dart';

import '../data/library.dart';
import '../models/story.dart';
import '../widgets/story_card.dart';
import 'add_story_sheet.dart';
import 'story_screen.dart';
import 'settings_screen.dart';

class LibraryScreen extends StatefulWidget {
  final Library library;
  final String theme;
  final Future<void> Function(String) onTheme;
  const LibraryScreen({
    super.key,
    required this.library,
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
  String _shelf = '', _site = '', _sort = 'added';
  bool _unread = false, _loading = true, _more = false;
  String? _error;
  int _generation = 0;
  Timer? _debounce;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
      final rows = await listStories(widget.library, {
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _progress(Story story, int chapter) async {
    setState(() => _saving.add(story.id));
    try {
      final data = await widget.library.call({
        'op': 'update',
        'id': story.id,
        'patch': {'Chapter': chapter},
      });
      if (mounted) {
        setState(
          () => _stories = _stories
              .map(
                (s) => s.id == story.id
                    ? Story(Map<String, dynamic>.from(data as Map))
                    : s,
              )
              .toList(),
        );
      }
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
                  subtitle: const Text('Based on saved website details'),
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
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/sailune.png',
              width: 30,
              height: 30,
              excludeFromSemantics: true,
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
      bottomNavigationBar: SafeArea(
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
                            'Your reading room',
                            style: Theme.of(context).textTheme.headlineLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Good stories. A little space for yourself.',
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              height: 1.5,
                            ),
                          ),
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
                                  ? 'Save a story from AO3 or FanFiction.net.\nPick up right where you left off.'
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
                          onOpen: () => _open(story),
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
