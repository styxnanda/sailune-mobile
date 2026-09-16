import 'package:flutter/material.dart';

import 'data/library.dart';
import 'screens/library_screen.dart';
import 'theme.dart';

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
  @override
  void initState() {
    super.initState();
    widget.library
        .loadTheme()
        .then((value) {
          if (mounted) setState(() => _theme = value);
        })
        .catchError((Object _) {
          /* Library screen reports bridge failures. */
        });
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
    home: LibraryScreen(
      library: widget.library,
      theme: _theme,
      onTheme: _setTheme,
    ),
  );
}
