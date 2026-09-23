import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../data/library.dart';
import '../models/story.dart';
import '../widgets/artwork.dart';

class ArtworkScreen extends StatefulWidget {
  final Library library;
  final Story story;
  const ArtworkScreen({super.key, required this.library, required this.story});
  @override
  State<ArtworkScreen> createState() => _ArtworkScreenState();
}

class _ArtworkScreenState extends State<ArtworkScreen> {
  String _role = 'cover';
  String? _path, _error;
  Uint8List? _preview;
  double _x = .5, _y = .5;
  bool _busy = false;
  int _revision = 0;
  Future<void> _discard() async {
    final p = _path;
    _path = null;
    if (p != null) await widget.library.device('discardImage', p);
  }

  @override
  void dispose() {
    final p = _path;
    if (p != null) {
      widget.library.device('discardImage', p).catchError((_) {
        return null;
      });
    }
    super.dispose();
  }

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

  Future<void> _frame() async {
    final bytes = await widget.library.device('previewArtwork', {
      'path': _path,
      'role': _role,
      'x': _x,
      'y': _y,
    });
    if (mounted) setState(() => _preview = bytes as Uint8List);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Story artwork')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'A portrait cover and a separate horizontal background. Sailune saves optimized copies. Transparent areas become white.',
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            initialValue: _role,
            decoration: const InputDecoration(labelText: 'Artwork slot'),
            items: const [
              DropdownMenuItem(
                value: 'cover',
                child: Text('Portrait cover · 2:3'),
              ),
              DropdownMenuItem(
                value: 'background',
                child: Text('Horizontal background'),
              ),
            ],
            onChanged: _busy
                ? null
                : (v) => _run(() async {
                    await _discard();
                    setState(() {
                      _role = v!;
                      _preview = null;
                      _x = .5;
                      _y = .5;
                    });
                  }),
          ),
          const SizedBox(height: 20),
          Center(
            child: SizedBox(
              width: _role == 'cover' ? 160 : double.infinity,
              height: 240,
              child: _preview == null
                  ? StoryArtwork(
                      library: widget.library,
                      id: widget.story.id,
                      site: widget.story.site,
                      role: _role,
                      small: false,
                      revision: _revision,
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: Image.memory(
                        _preview!,
                        fit: BoxFit.cover,
                        alignment: Alignment(_x * 2 - 1, _y * 2 - 1),
                      ),
                    ),
            ),
          ),
          if (_path != null) ...[
            const SizedBox(height: 16),
            const Text('Horizontal focal point'),
            Slider(
              value: _x,
              onChanged: _busy ? null : (v) => setState(() => _x = v),
            ),
            const Text('Vertical focal point'),
            Slider(
              value: _y,
              onChanged: _busy ? null : (v) => setState(() => _y = v),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _busy ? null : () => _run(_frame),
              child: const Text('Preview framing'),
            ),
          ],
          if (_error != null) Text(_error!, semanticsLabel: _error),
          if (_busy) const LinearProgressIndicator(),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () => _run(() async {
                    final p =
                        await widget.library.device('pickImage') as String?;
                    if (p == null) return;
                    await _discard();
                    _path = p;
                    _x = .5;
                    _y = .5;
                    await _frame();
                  }),
            icon: const Icon(Icons.image_outlined),
            label: const Text('Choose image'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy || _path == null
                ? null
                : () => _run(() async {
                    await organize(widget.library, {
                      'action': 'artwork-set',
                      'id': widget.story.id,
                      'role': _role,
                      'path': _path,
                      'x': _x,
                      'y': _y,
                    });
                    await _discard();
                    if (mounted) {
                      setState(() {
                        _preview = null;
                        _revision++;
                      });
                    }
                  }),
            child: const Text('Save artwork'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _busy
                ? null
                : () => _run(() async {
                    await organize(widget.library, {
                      'action': 'artwork-remove',
                      'id': widget.story.id,
                      'role': _role,
                    });
                    await _discard();
                    if (mounted) {
                      setState(() {
                        _preview = null;
                        _revision++;
                      });
                    }
                  }),
            child: const Text('Remove artwork'),
          ),
        ],
      ),
    ),
  );
}
