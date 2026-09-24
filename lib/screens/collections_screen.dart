import 'package:flutter/material.dart';

import '../data/library.dart';
import '../models/story.dart';
import '../widgets/app_feedback.dart';
import '../widgets/collection_card.dart';
import '../widgets/library_navigation.dart';
import 'settings_screen.dart';

class CollectionsScreen extends StatefulWidget {
  final Library library;
  final String theme;
  final Future<void> Function(String) onTheme;
  final VoidCallback onLibrary;
  final Future<void> Function(Map<String, dynamic>) onOpen;
  const CollectionsScreen({
    super.key,
    required this.library,
    required this.theme,
    required this.onTheme,
    required this.onLibrary,
    required this.onOpen,
  });
  @override
  State<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends State<CollectionsScreen> {
  List<Map<String, dynamic>> _rows = [];
  String _mode = 'hidden', _query = '';
  String? _error;
  bool _loading = true;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    try {
      final prefs =
          await widget.library.device('loadArtworkPreferences') as Map;
      final rows =
          await widget.library.call({'op': 'collection-overviews'}) as List;
      if (mounted && generation == _generation) {
        setState(() {
          _rows = rows.map((c) => Map<String, dynamic>.from(c as Map)).toList();
          _mode = prefs['mode'] as String? ?? 'hidden';
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() {
          _error = errorMessage(e);
          _loading = false;
        });
      }
    }
  }

  Future<void> _edit() async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => CollectionEditor(library: widget.library),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _delete(Map<String, dynamic> c) async {
    final yes = await confirmAction(
      context,
      title: 'Delete collection?',
      message:
          '“${c['name']}” will be removed. Its stories will remain in your library.',
      confirm: 'Delete collection',
      cancel: 'Keep collection',
    );
    if (yes != true || !mounted) return;
    try {
      await organize(widget.library, {
        'action': 'collection-delete',
        'collection_id': c['id'],
      });
      if (mounted) await _load();
    } catch (e) {
      if (mounted) showAppNotice(context, errorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Row(
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
        IconButton(
          tooltip: 'Settings',
          icon: const Icon(Icons.tune_rounded),
          onPressed: () async {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
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
      bottom: LibraryNavigation(
        collections: true,
        onLibrary: widget.onLibrary,
        onCollections: () {},
      ),
    ),
    bottomNavigationBar: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
          ),
          onPressed: _edit,
          icon: const Icon(Icons.add_rounded),
          label: const Text('New collection'),
        ),
      ),
    ),
    body: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        children: [
          Text(
            'Your collections',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 8),
          const Text('A home for stories that belong together.'),
          const SizedBox(height: 26),
          TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: const InputDecoration(
              hintText: 'Search your collections',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 24),
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (_error != null) ...[
            Text(_error!),
            TextButton(onPressed: _load, child: const Text('Try again')),
          ],
          if (!_loading && _error == null && _rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Text(
                'Create your first collection. Your stories can belong to more than one.',
              ),
            ),
          for (final row in _rows.where(
            (r) => (r['collection']['name'] as String).toLowerCase().contains(
              _query.toLowerCase(),
            ),
          ))
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: CollectionCard(
                library: widget.library,
                overview: row,
                mode: _mode,
                revision: _generation,
                onTap: () async {
                  await widget.onOpen(
                    Map<String, dynamic>.from(row['collection'] as Map),
                  );
                  if (mounted) await _load();
                },
                onLongPress: () => _delete(
                  Map<String, dynamic>.from(row['collection'] as Map),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class CollectionEditor extends StatefulWidget {
  final Library library;
  final Map<String, dynamic>? collection;
  final bool membersOnly;
  const CollectionEditor({
    super.key,
    required this.library,
    this.collection,
    this.membersOnly = false,
  });
  @override
  State<CollectionEditor> createState() => _CollectionEditorState();
}

class _CollectionEditorState extends State<CollectionEditor> {
  final _name = TextEditingController(),
      _personal = TextEditingController(),
      _source = TextEditingController(),
      _fandom = TextEditingController(),
      _query = TextEditingController();
  String? _id, _error;
  String _kind = 'manual', _site = '', _status = '';
  bool _allPersonal = false,
      _allSource = false,
      _busy = false,
      _members = false;
  int _offset = 0, _total = 0;
  List<Story> _rows = [];
  final _chosen = <int>{};
  List<String> _personalTags = [], _sourceTags = [], _fandoms = [];
  @override
  void initState() {
    super.initState();
    final c = widget.collection;
    if (c != null) {
      _id = c['id'] as String;
      _name.text = c['name'] as String;
      _kind = c['kind'] as String;
      final r = c['rules'] as Map? ?? {};
      final p = r['personal'] as Map? ?? {};
      final s = r['source'] as Map? ?? {};
      _personal.text = (p['tags'] as List? ?? []).join('\n');
      _source.text = (s['tags'] as List? ?? []).join('\n');
      _allPersonal = p['all'] == true;
      _allSource = s['all'] == true;
      _site = r['site'] as String? ?? '';
      _status = r['status'] as String? ?? '';
      _fandom.text = r['fandom'] as String? ?? '';
    }
    _tags();
    if (widget.membersOnly) _run(() => _preview());
  }

  @override
  void dispose() {
    for (final c in [_name, _personal, _source, _fandom, _query]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _tags() async {
    try {
      final p = await organize(widget.library, {
        'action': 'tags',
        'kind': 'tag',
      }) as List;
      final s = await organize(widget.library, {
        'action': 'tags',
        'kind': 'source-tag',
      }) as List;
      final f = await organize(widget.library, {
        'action': 'tags',
        'kind': 'fandom',
      }) as List;
      if (mounted) {
        setState(() {
          _personalTags = p.cast<String>();
          _sourceTags = s.cast<String>();
          _fandoms = f.cast<String>();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    }
  }

  Map<String, dynamic> get _rules => {
    'personal': {
      'tags': _personal.text
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(),
      'all': _allPersonal,
    },
    'source': {
      'tags': _source.text
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(),
      'all': _allSource,
    },
    'site': _site,
    'status': _status,
    'fandom': _fandom.text.trim(),
  };
  Future<void> _run(Future<void> Function() fn) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await fn();
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _preview({bool reset = true}) async {
    if (reset) {
      _offset = 0;
      _chosen.clear();
    }
    final f = <String, dynamic>{
      'Query': _query.text,
      'Limit': 20,
      'Offset': _offset,
      'Sort': 'title',
      if (_members && _id != null) 'Collection': _id else 'Rules': _rules,
    };
    final rows = await listStories(widget.library, f);
    final total =
        await organize(widget.library, {'action': 'count', 'filter': f}) as int;
    if (mounted) {
      setState(() {
        _rows = rows;
        _total = total;
      });
    }
  }

  Widget _suggestions(
    String label,
    List<String> tags,
    TextEditingController controller,
  ) => DropdownButtonFormField<String>(
    initialValue: '',
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: [
      const DropdownMenuItem(value: '', child: Text('Choose tag…')),
      for (final t in tags)
        DropdownMenuItem(
          value: t,
          child: Text(t, overflow: TextOverflow.ellipsis),
        ),
    ],
    onChanged: (v) {
      if (v != null && v.isNotEmpty) {
        setState(
          () => controller.text = controller == _fandom
              ? v
              : '${controller.text}${controller.text.isEmpty ? '' : '\n'}$v',
        );
      }
    },
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.membersOnly
            ? 'Collection stories'
            : _id == null
            ? 'New collection'
            : 'Collection details',
      ),
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (!widget.membersOnly) ...[
            TextField(
              controller: _name,
              maxLength: 200,
              decoration: const InputDecoration(labelText: 'Collection name'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _kind,
              decoration: const InputDecoration(labelText: 'Type'),
              items: const [
                DropdownMenuItem(value: 'manual', child: Text('Manual')),
                DropdownMenuItem(
                  value: 'smart',
                  child: Text('Automatic · saved rules'),
                ),
              ],
              onChanged: _id != null || _busy
                  ? null
                  : (v) => setState(() => _kind = v!),
            ),
          ],
          const SizedBox(height: 16),
          if (widget.membersOnly || _kind == 'smart')
            ExpansionTile(
              initiallyExpanded: _kind == 'smart',
              tilePadding: EdgeInsets.zero,
              title: Text(
                _kind == 'smart' ? 'Matching rules' : 'Find stories by tags',
              ),
              children: [
                const Text(
                  'Exact matches. Conditions combine with AND. Automatic membership follows changes to local story details.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _personal,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Personal tags · one per line',
                  ),
                ),
                const SizedBox(height: 12),
                _suggestions(
                  'Personal tag suggestions',
                  _personalTags,
                  _personal,
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Match all personal tags'),
                  subtitle: const Text('Off matches any selected tag'),
                  value: _allPersonal,
                  onChanged: (v) => setState(() => _allPersonal = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _source,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Website tags · one per line',
                  ),
                ),
                const SizedBox(height: 12),
                _suggestions('Website tag suggestions', _sourceTags, _source),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Match all website tags'),
                  subtitle: const Text('Off matches any selected tag'),
                  value: _allSource,
                  onChanged: (v) => setState(() => _allSource = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _site,
                  decoration: const InputDecoration(labelText: 'Website'),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('All websites')),
                    DropdownMenuItem(value: 'ao3', child: Text('AO3')),
                    DropdownMenuItem(value: 'ffn', child: Text('FFN')),
                  ],
                  onChanged: (v) => setState(() => _site = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(
                    labelText: 'Reading status',
                  ),
                  items: [
                    for (final s in shelves.entries)
                      DropdownMenuItem(value: s.key, child: Text(s.value)),
                  ],
                  onChanged: (v) => setState(() => _status = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _fandom,
                  decoration: const InputDecoration(labelText: 'Fandom'),
                ),
                const SizedBox(height: 12),
                _suggestions('Fandom suggestions', _fandoms, _fandom),
              ],
            ),
          const SizedBox(height: 16),
          if (!widget.membersOnly)
            FilledButton(
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                      await organize(widget.library, {
                        'action': 'collection-save',
                        'collection': {
                          'id': _id ?? '',
                          'name': _name.text,
                          'kind': _kind,
                          'rules': _rules,
                        },
                      });
                      if (mounted) {
                        Navigator.pop(this.context);
                        showAppNotice(this.context, 'Collection saved');
                      }
                    }),
              child: const Text('Save collection'),
            ),
          if (_error != null) Text(_error!),
          if (_busy) const LinearProgressIndicator(),
          const SizedBox(height: 24),
          if (widget.membersOnly || _kind == 'smart') ...[
            TextField(
              controller: _query,
              decoration: const InputDecoration(labelText: 'Search stories'),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 12,
              children: [
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => _run(() async {
                          _members = false;
                          await _preview();
                        }),
                  child: const Text('Preview matching stories'),
                ),
                if (_id != null)
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _run(() async {
                            _members = true;
                            await _preview();
                          }),
                    child: const Text('View collection'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text('$_total matching stories'),
            const SizedBox(height: 8),
            for (final s in _rows)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(s.title),
                subtitle: Text(s.author),
                value: _chosen.contains(s.id),
                onChanged: _kind == 'smart' || _busy
                    ? null
                    : (v) => setState(() {
                        if (v == true) {
                          _chosen.add(s.id);
                        } else {
                          _chosen.remove(s.id);
                        }
                      }),
              ),
            if (_rows.isNotEmpty || _offset > 0)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: _busy || _offset == 0
                          ? null
                          : () => _run(() async {
                              _offset = (_offset - 20).clamp(0, _total);
                              await _preview(reset: false);
                            }),
                      child: const Text('Previous'),
                    ),
                    TextButton(
                      onPressed: _busy || _offset + 20 >= _total
                          ? null
                          : () => _run(() async {
                              _offset += 20;
                              await _preview(reset: false);
                            }),
                      child: const Text('Next'),
                    ),
                  ],
                ),
              ),
            if (_id != null && _kind == 'manual') ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: _busy || _rows.isEmpty
                    ? null
                    : () => setState(
                        () => _chosen.addAll(_rows.map((s) => s.id)),
                      ),
                child: const Text('Select page'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _busy || _chosen.isEmpty
                    ? null
                    : () => _run(() async {
                        await organize(widget.library, {
                          'action': 'membership',
                          'collection_id': _id,
                          'ids': _chosen.toList(),
                          'remove': _members,
                        });
                        _chosen.clear();
                        await _preview(reset: false);
                      }),
                child: Text(
                  _members
                      ? 'Remove selected from collection'
                      : 'Add selected to collection',
                ),
              ),
            ],
          ],
          if (_id != null && !widget.membersOnly) ...[
            const SizedBox(height: 32),
            TextButton(
              onPressed: _busy
                  ? null
                  : () async {
                      final yes = await confirmAction(
                        context,
                        title: 'Delete collection?',
                        message: 'Stories will remain in your library.',
                        confirm: 'Delete collection',
                        cancel: 'Keep collection',
                      );
                      if (yes != true || !mounted) return;
                      await _run(() async {
                        await organize(widget.library, {
                          'action': 'collection-delete',
                          'collection_id': _id,
                        });
                        if (mounted) Navigator.pop(this.context);
                      });
                    },
              child: const Text('Delete collection'),
            ),
          ],
        ],
      ),
    ),
  );
}

Future<void> assignCollection(
  BuildContext context,
  Library library,
  int id,
) async {
  try {
    final rows =
        await library.call({'op': 'collection-overviews', 'id': id}) as List;
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Add to collection',
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              if (rows.isEmpty)
                const Text('Create a collection from the Collections tab.'),
              for (final row in rows)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(row['collection']['name'] as String),
                  subtitle: Text(
                    row['contains'] == true
                        ? (row['collection']['kind'] == 'smart'
                              ? 'Included automatically'
                              : 'Tap to remove from this collection')
                        : (row['collection']['kind'] == 'smart'
                              ? 'Does not match its rules'
                              : 'Add this story'),
                  ),
                  trailing: Icon(
                    row['contains'] == true
                        ? (row['collection']['kind'] == 'smart'
                              ? Icons.check_circle_rounded
                              : Icons.remove_circle_outline_rounded)
                        : row['collection']['kind'] == 'smart'
                        ? Icons.auto_awesome_outlined
                        : Icons.add_rounded,
                  ),
                  enabled:
                      row['collection']['kind'] == 'manual' &&
                      row['saving'] != true,
                  onTap: () async {
                    update(() => row['saving'] = true);
                    try {
                      await organize(library, {
                        'action': 'membership',
                        'collection_id': row['collection']['id'],
                        'ids': [id],
                        'remove': row['contains'] == true,
                      });
                      if (ctx.mounted) {
                        update(() {
                          row['contains'] = row['contains'] != true;
                          row['saving'] = false;
                        });
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                        update(() => row['saving'] = false);
                        showAppNotice(ctx, errorMessage(e));
                      }
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  } catch (e) {
    if (context.mounted) showAppNotice(context, errorMessage(e));
  }
}
