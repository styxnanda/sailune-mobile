import 'dart:convert';

import 'package:flutter/material.dart';

import '../data/library.dart';
import '../widgets/app_feedback.dart';
import 'onboarding_screen.dart';

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
  String _coverMode = 'hidden';
  bool _detailArt = true;
  bool _busy = false;
  String? _message;
  Map<String, bool> _sessions = {};
  String? _sessionError;
  @override
  void initState() {
    super.initState();
    _theme = widget.theme;
    _loadSessions();
    _loadArtwork();
  }

  Future<void> _loadArtwork() async {
    try {
      final p = await widget.library.device('loadArtworkPreferences') as Map;
      if (mounted) {
        setState(() {
          _coverMode = p['mode'] as String? ?? 'hidden';
          _detailArt = p['details'] != false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _message = errorMessage(e));
    }
  }

  Future<String?> _saveArtwork(String mode, bool details) async {
    await widget.library.device('saveArtworkPreferences', {
      'mode': mode,
      'details': details,
    });
    if (mounted) {
      setState(() {
        _coverMode = mode;
        _detailArt = details;
      });
    }
    return null;
  }

  Future<void> _loadSessions() async {
    try {
      final state = await widget.library.websiteSessions();
      if (mounted) {
        setState(() {
          _sessions = state;
          _sessionError = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _sessionError = errorMessage(e));
    }
  }

  Future<void> _connect(String site) async {
    final name = site == 'ao3' ? 'Archive of Our Own' : 'FanFiction.net';
    final approved = await confirmAction(
      context,
      title: 'Sign in to $name',
      message: 'Allow Sailune to save this website’s session on this device?',
      confirm: 'Continue to website',
      cancel: 'Not now',
    );
    if (approved != true || !mounted) return;
    await _run(() async {
      final signedIn = await widget.library.connectWebsite(site, consent: true);
      await _loadSessions();
      return signedIn ? 'Signed in' : 'Sign-in cancelled';
    });
  }

  Future<void> _clearSessions() async {
    final approved = await confirmAction(
      context,
      title: 'Clear website sessions?',
      message: 'Sign out of all websites?',
      confirm: 'Clear sessions',
      cancel: 'Keep sessions',
    );
    if (approved != true || !mounted) return;
    await _run(() async {
      await widget.library.clearWebsiteSessions(consent: true);
      await _loadSessions();
      return 'Website sessions cleared';
    });
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
              DropdownButtonFormField<String>(
                initialValue: _coverMode,
                key: ValueKey(_coverMode),
                decoration: const InputDecoration(
                  labelText: 'Library cover appearance',
                ),
                isExpanded: true,
                items: const [
                  DropdownMenuItem(
                    value: 'hidden',
                    child: Text('Hidden · minimal cards'),
                  ),
                  DropdownMenuItem(
                    value: 'portrait',
                    child: Text('Portrait · cover on the left'),
                  ),
                  DropdownMenuItem(
                    value: 'background',
                    child: Text('Background · translucent cards'),
                  ),
                ],
                onChanged: _busy
                    ? null
                    : (v) => _run(() => _saveArtwork(v!, _detailArt)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show artwork in story details'),
                subtitle: const Text(
                  'Hidden artwork stays saved on your stories.',
                ),
                value: _detailArt,
                onChanged: _busy
                    ? null
                    : (v) => _run(() => _saveArtwork(_coverMode, v)),
              ),
              const SizedBox(height: 24),
              Text(
                'Website sessions',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Card(
                child: Column(
                  children: [
                    for (final site in {
                      'ao3': 'Archive of Our Own',
                      'ffn': 'FanFiction.net',
                    }.entries)
                      ListTile(
                        leading: const Icon(Icons.lock_outline),
                        title: Text(site.value),
                        subtitle: Text(
                          _sessions[site.key] == true ? 'Signed in' : 'Sign in',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _busy ? null : () => _connect(site.key),
                      ),
                    ListTile(
                      leading: const Icon(Icons.logout),
                      title: const Text('Clear website sessions'),
                      onTap: _busy ? null : _clearSessions,
                    ),
                  ],
                ),
              ),
              if (_sessionError != null) Text(_sessionError!),
              const SizedBox(height: 32),
              Text(
                'Your collection',
                style: Theme.of(context).textTheme.titleLarge,
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
                        'Stories, collections, and artwork in one ZIP.',
                      ),
                      onTap: _busy
                          ? null
                          : () => _run(() async {
                              return await widget.library.device(
                                        'exportArchive',
                                      ) ==
                                      true
                                  ? 'Backup saved'
                                  : null;
                            }),
                    ),
                    const Divider(height: 1, indent: 56),
                    ListTile(
                      minVerticalPadding: 18,
                      leading: const Icon(Icons.file_download_outlined),
                      title: const Text('Import a backup'),
                      subtitle: const Text(
                        'Existing notes, artwork, and rules are kept. Missing artwork and memberships are added.',
                      ),
                      onTap: _busy
                          ? null
                          : () => _run(() async {
                              final data = await widget.library.device(
                                'importArchive',
                              ) as String?;
                              if (data == null) return null;
                              final result = jsonDecode(data) as Map;
                              return '${result['imported']} stories added · ${result['skipped']} existing · ${result['collections'] ?? 0} collections · ${result['artwork'] ?? 0} artworks · ${result['conflicts'] ?? 0} conflicts retained';
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
              const SizedBox(height: 32),
              ListTile(
                leading: const Icon(Icons.auto_stories_outlined),
                title: const Text('Replay welcome tour'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (tourContext) => OnboardingScreen(
                      onDone: () async => Navigator.of(tourContext).pop(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'SAILUNE  /  0.9.0',
                style: TextStyle(fontSize: 11, letterSpacing: 1.4),
              ),
              TextButton(
                onPressed: () => showLicensePage(
                  context: context,
                  applicationName: 'Sailune',
                  applicationVersion: '0.9.0',
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
