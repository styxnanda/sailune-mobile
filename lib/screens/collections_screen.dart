import 'package:flutter/material.dart';

import '../data/library.dart';
import '../models/story.dart';
import '../widgets/app_feedback.dart';

class CollectionsScreen extends StatefulWidget {
  final Library library;
  const CollectionsScreen({super.key, required this.library});
  @override
  State<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends State<CollectionsScreen> {
  List<Map<String, dynamic>> _collections = [];
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows =
          await organize(widget.library, {'action': 'collections'}) as List;
      if (mounted) {
        setState(() {
          _collections = rows
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    }
  }

  Future<void> _edit(Map<String, dynamic>? c) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            CollectionEditor(library: widget.library, collection: c),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Manage collections')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _edit(null),
      icon: const Icon(Icons.add),
      label: const Text('New collection'),
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
      children: [
        if (_error != null) ...[
          Text(_error!),
          TextButton(onPressed: _load, child: const Text('Try again')),
        ],
        if (_collections.isEmpty && _error == null)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Make a home for stories that belong together.'),
          ),
        for (final c in _collections)
          ListTile(
            title: Text(c['name'] as String),
            subtitle: Text(
              '${c['count']} stories · ${c['kind'] == 'smart' ? 'Automatic' : 'Manual'}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _edit(c),
          ),
      ],
    ),
  );
}

class CollectionEditor extends StatefulWidget {
  final Library library;
  final Map<String, dynamic>? collection;
  const CollectionEditor({super.key, required this.library, this.collection});
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
      final r = c['rules'] as Map;
      final p = r['personal'] as Map;
      final s = r['source'] as Map;
      _personal.text = (p['tags'] as List? ?? []).join('\n');
      _source.text = (s['tags'] as List? ?? []).join('\n');
      _allPersonal = p['all'] == true;
      _allSource = s['all'] == true;
      _site = r['site'] as String? ?? '';
      _status = r['status'] as String? ?? '';
      _fandom.text = r['fandom'] as String? ?? '';
    }
    _tags();
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
      title: Text(_id == null ? 'New collection' : 'Collection details'),
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(
            controller: _name,
            maxLength: 200,
            decoration: const InputDecoration(labelText: 'Collection name'),
          ),
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
          const SizedBox(height: 16),
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
              _suggestions(
                'Personal tag suggestions',
                _personalTags,
                _personal,
              ),
              SwitchListTile(
                title: const Text('Match all personal tags'),
                subtitle: const Text('Off matches any selected tag'),
                value: _allPersonal,
                onChanged: (v) => setState(() => _allPersonal = v),
              ),
              TextField(
                controller: _source,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Website tags · one per line',
                ),
              ),
              _suggestions('Website tag suggestions', _sourceTags, _source),
              SwitchListTile(
                title: const Text('Match all website tags'),
                subtitle: const Text('Off matches any selected tag'),
                value: _allSource,
                onChanged: (v) => setState(() => _allSource = v),
              ),
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
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Reading status'),
                items: [
                  for (final s in shelves.entries)
                    DropdownMenuItem(value: s.key, child: Text(s.value)),
                ],
                onChanged: (v) => setState(() => _status = v!),
              ),
              TextField(
                controller: _fandom,
                decoration: const InputDecoration(labelText: 'Fandom'),
              ),
              _suggestions('Fandom suggestions', _fandoms, _fandom),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy
                ? null
                : () => _run(() async {
                    final c = await organize(widget.library, {
                      'action': 'collection-save',
                      'collection': {
                        'id': _id ?? '',
                        'name': _name.text,
                        'kind': _kind,
                        'rules': _rules,
                      },
                    }) as Map;
                    if (mounted) {
                      setState(() => _id = c['id'] as String);
                      showAppNotice(this.context, 'Collection saved');
                    }
                  }),
            child: const Text('Save collection'),
          ),
          if (_error != null) Text(_error!),
          if (_busy) const LinearProgressIndicator(),
          const SizedBox(height: 24),
          TextField(
            controller: _query,
            decoration: const InputDecoration(labelText: 'Search stories'),
          ),
          Wrap(
            spacing: 8,
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
          Text('$_total matching stories'),
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
            Row(
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
          if (_id != null && _kind == 'manual') ...[
            TextButton(
              onPressed: _busy || _rows.isEmpty
                  ? null
                  : () =>
                        setState(() => _chosen.addAll(_rows.map((s) => s.id))),
              child: const Text('Select page'),
            ),
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
          if (_id != null) ...[
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
    final rows = (await organize(library, {'action': 'collections'}) as List)
        .where((c) => c['kind'] == 'manual')
        .toList();
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Add to collection',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (rows.isEmpty)
              const Text(
                'Create a manual collection from Manage collections in the library.',
              ),
            for (final c in rows)
              ListTile(
                title: Text(c['name'] as String),
                trailing: const Icon(Icons.add),
                onTap: () async {
                  try {
                    await organize(library, {
                      'action': 'membership',
                      'collection_id': c['id'],
                      'ids': [id],
                      'remove': false,
                    });
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) {
                      showAppNotice(context, 'Added to collection');
                    }
                  } catch (e) {
                    if (context.mounted) {
                      showAppNotice(context, errorMessage(e));
                    }
                  }
                },
              ),
          ],
        ),
      ),
    );
  } catch (e) {
    if (context.mounted) showAppNotice(context, errorMessage(e));
  }
}
