import 'package:flutter/material.dart';

import 'data/library.dart';
import 'screens/library_screen.dart';
import 'screens/onboarding_screen.dart';
import 'theme.dart';
import 'widgets/launch_reveal.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(SailuneApp(library: AndroidLibrary()));
}

class SailuneApp extends StatefulWidget {
  final Library library;
  const SailuneApp({super.key, required this.library});
  @override
  State<SailuneApp> createState() => _SailuneAppState();
}

class _SailuneAppState extends State<SailuneApp> {
  String _theme = 'system';
  final _logoKey = GlobalKey();
  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  bool? _onboarded;
  Future<void> _loadPreferences() async {
    try {
      final values = await Future.wait<dynamic>([
        widget.library.loadTheme(),
        widget.library.loadOnboarding(),
      ]);
      if (mounted) {
        setState(() {
          _theme = values[0] as String;
          _onboarded = values[1] as bool;
        });
      }
    } catch (_) {
      // Keep the library and its bridge recovery available if preferences fail.
      if (mounted) setState(() => _onboarded = true);
    }
  }

  Future<void> _setTheme(String value) async {
    await widget.library.saveTheme(value);
    if (mounted) setState(() => _theme = value);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Sailune',
    debugShowCheckedModeBanner: false,
    theme: sailuneTheme(Brightness.light),
    darkTheme: sailuneTheme(Brightness.dark),
    themeMode: switch (_theme) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    },
    builder: (context, child) => LaunchReveal(
      ready: _onboarded != null,
      logoKey: _logoKey,
      child: child!,
    ),
    home: _onboarded == null
        ? const Scaffold(body: Center(child: CircularProgressIndicator()))
        : _onboarded == false
        ? OnboardingScreen(
            onDone: () async {
              await widget.library.completeOnboarding();
              if (mounted) setState(() => _onboarded = true);
            },
          )
        : LibraryScreen(
            logoKey: _logoKey,
            library: widget.library,
            theme: _theme,
            onTheme: _setTheme,
          ),
  );
}
