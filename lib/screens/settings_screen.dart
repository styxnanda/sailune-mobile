import 'package:flutter/material.dart';

import '../data/library.dart';

class SettingsScreen extends StatefulWidget {
  final Library library;
  final String theme;
  final Future<void> Function(String) onTheme;
  const SettingsScreen({
    super.key,
    required this.library,
    required this.theme,
    required this.onTheme,
  });
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late String _theme;
  bool _busy = false;
  String? _message;
  @override
  void initState() {
    super.initState();
    _theme = widget.theme;
  }

  Future<void> _run(Future<String?> Function() action) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final message = await action();
      if (mounted) setState(() => _message = message);
    } catch (e) {
      if (mounted) setState(() => _message = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Make yourself at home')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text('Appearance', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 18),
              Card(
                child: Column(
                  children: [
                    for (final option in {
                      'system': 'Follow device',
                      'light': 'Light',
                      'dark': 'Dark',
                    }.entries)
                      ListTile(
                        leading: Icon(switch (option.key) {
                          'light' => Icons.light_mode_outlined,
                          'dark' => Icons.dark_mode_outlined,
                          _ => Icons.brightness_auto_outlined,
                        }),
                        title: Text(option.value),
                        trailing: _theme == option.key
                            ? const Icon(Icons.check_rounded)
                            : null,
                        onTap: _busy
                            ? null
                            : () => _run(() async {
                                await widget.onTheme(option.key);
                                if (mounted) {
                                  setState(() => _theme = option.key);
                                }
                                return null;
                              }),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Your collection',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Take your stories between Sailune on desktop and mobile with a library backup.',
                style: TextStyle(height: 1.6),
              ),
              const SizedBox(height: 16),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      minVerticalPadding: 18,
                      leading: const Icon(Icons.file_upload_outlined),
                      title: const Text('Save a backup'),
                      subtitle: const Text(
                        'Choose where to save your JSON file',
                      ),
                      onTap: _busy
                          ? null
                          : () => _run(() async {
                              final data = await widget.library.call({
                                'op': 'export',
                              }) as String;
                              return await widget.library.saveBackup(data)
                                  ? 'Backup saved'
                                  : null;
                            }),
                    ),
                    const Divider(height: 1, indent: 56),
                    ListTile(
                      minVerticalPadding: 18,
                      leading: const Icon(Icons.file_download_outlined),
                      title: const Text('Import a collection'),
                      subtitle: const Text(
                        'Merge stories; existing bookmarks stay intact',
                      ),
                      onTap: _busy
                          ? null
                          : () => _run(() async {
                              final data = await widget.library.pickBackup();
                              if (data == null) return null;
                              final result = await widget.library.call({
                                'op': 'import',
                                'snapshot': data,
                              }) as Map;
                              return '${result['imported']} imported · ${result['skipped']} already in your library';
                            }),
                    ),
                  ],
                ),
              ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: LinearProgressIndicator(),
                ),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Semantics(liveRegion: true, child: Text(_message!)),
                ),
              const SizedBox(height: 16),
              const Text(
                'Backups include your notes and reading history. Store them somewhere you trust. Transfers are snapshots, not automatic sync.',
                style: TextStyle(fontSize: 12, height: 1.7),
              ),
              const SizedBox(height: 32),
              Text(
                'A quieter way to keep stories',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              const Text(
                'Sailune keeps your library on this device. Read on the original website, and keep your place here.\n\nPublic story details can be fetched from AO3 and FanFiction.net. Mobile sign-in and full-story downloads are not available in this version.',
                style: TextStyle(height: 1.7),
              ),
              const SizedBox(height: 24),
              const Text(
                'SAILUNE  /  0.1.0',
                style: TextStyle(fontSize: 11, letterSpacing: 1.4),
              ),
              TextButton(
                onPressed: () => showLicensePage(
                  context: context,
                  applicationName: 'Sailune',
                  applicationVersion: '0.1.0',
                  applicationLegalese: 'GPL-3.0 · Shared Sailune-Go core',
                ),
                child: const Text('Open-source licenses'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
