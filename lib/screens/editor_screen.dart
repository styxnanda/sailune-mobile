import 'package:flutter/material.dart';

import '../data/library.dart';
import '../models/story.dart';
import '../widgets/scrape_task.dart';

class EditorScreen extends StatefulWidget {
  final Library library;
  final Story? story;
  final bool asSheet;
  const EditorScreen({
    super.key,
    required this.library,
    this.story,
    this.asSheet = false,
  });
  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _url,
      _title,
      _author,
      _chapter,
      _tags,
      _notes;
  late String _status;
  late int _rating;
  bool _fetch = true, _busy = false;
  String? _error;
  late final ScrapeTask _scrape;
  @override
  void initState() {
    super.initState();
    _scrape = ScrapeTask(widget.library);
    final s = widget.story;
    _url = TextEditingController(text: s?.url);
    _title = TextEditingController(text: s?.json['title'] as String?);
    _author = TextEditingController(text: s?.author);
    _chapter = TextEditingController(text: '${s?.chapter ?? 0}');
    _tags = TextEditingController(text: s?.tags.join(', '));
    _notes = TextEditingController(text: s?.notes);
    _status = s?.status ?? 'planned';
    _rating = s?.rating ?? 0;
  }

  @override
  void dispose() {
    _scrape.dispose();
    for (final c in [_url, _title, _author, _chapter, _tags, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final fields = <String, dynamic>{
      'Title': _title.text,
      'Author': _author.text,
      'Status': _status,
      'Chapter': int.parse(_chapter.text),
      'Tags': _tags.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(),
      'Notes': _notes.text,
      'Rating': _rating,
    };
    try {
      if (widget.story == null) {
        final request = <String, dynamic>{
          'op': 'add',
          'fetch': _fetch,
          'bookmark': {
            'url': _url.text.trim(),
            for (final e in fields.entries) e.key.toLowerCase(): e.value,
          },
        };
        if (_fetch) {
          await _scrape.run(request);
        } else {
          await widget.library.call(request);
        }
      } else {
        // Only send changed fields; progress and timestamps survive unrelated edits.
        final original = widget.story!;
        final patch = <String, dynamic>{};
        for (final e in fields.entries) {
          final old = original.json[e.key.toLowerCase()];
          if (e.key == 'Tags'
              ? (old as List? ?? []).join('\u0000') !=
                    (e.value as List).join('\u0000')
              : old != e.value) {
            patch[e.key] = e.value;
          }
        }
        await widget.library.call({
          'op': 'update',
          'id': original.id,
          'patch': patch,
        });
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: widget.asSheet ? 'Close' : 'Back',
          onPressed: _busy ? null : () => Navigator.maybePop(context),
          icon: Icon(
            widget.asSheet ? Icons.close_rounded : Icons.arrow_back_rounded,
          ),
        ),
        title: Text(widget.story == null ? 'Add a story' : 'Edit bookmark'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(24),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  Text(
                    widget.story == null
                        ? 'Something worth coming back to.'
                        : 'Make a little room for your notes.',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 24),
                  if (widget.story == null) ...[
                    TextFormField(
                      controller: _url,
                      enabled: !_busy,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Story URL',
                        hintText: 'https://archiveofourown.org/works/…',
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Paste a story link to continue'
                          : null,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Fetch website details'),
                      subtitle: const Text(
                        'Turn off to save offline. Manage website sign-in in Settings.',
                      ),
                      value: _fetch,
                      onChanged: _busy
                          ? null
                          : (v) => setState(() => _fetch = v),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: _title,
                    enabled: !_busy,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      hintText: 'Optional when fetching details',
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _author,
                    enabled: !_busy,
                    decoration: const InputDecoration(labelText: 'Author'),
                  ),
                  const SizedBox(height: 18),
                  DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: const InputDecoration(labelText: 'Shelf'),
                    items: shelves.entries
                        .where((e) => e.key.isNotEmpty)
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _status = v!),
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _chapter,
                    enabled: !_busy,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Last chapter read',
                    ),
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      return n == null || n < 0 || n > 2147483647
                          ? 'Enter a chapter number from 0 to 2147483647'
                          : null;
                    },
                  ),
                  const SizedBox(height: 24),
                  const Text('Your rating'),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (var i = 1; i <= 5; i++)
                        IconButton(
                          tooltip: '$i ${i == 1 ? 'star' : 'stars'}',
                          onPressed: _busy
                              ? null
                              : () => setState(
                                  () => _rating = _rating == i ? 0 : i,
                                ),
                          icon: Icon(
                            i <= _rating
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                          ),
                        ),
                      if (_rating == 0)
                        const Text('Unrated', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _tags,
                    enabled: !_busy,
                    decoration: const InputDecoration(
                      labelText: 'Personal tags',
                      hintText: 'Comfort read, favorites',
                      helperText: 'Separate tags with commas',
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _notes,
                    enabled: !_busy,
                    minLines: 4,
                    maxLines: 10,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Notes',
                      alignLabelWithHint: true,
                      hintText: 'A favorite moment, a thought for later…',
                    ),
                  ),
                  InlineScrapeProgress(task: _scrape),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: _busy ? null : _save,
                    child: _busy && !(widget.story == null && _fetch)
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            widget.story == null
                                ? 'Save to library'
                                : 'Save changes',
                          ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
