import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/story.dart';

abstract class Library {
  Future<dynamic> call(Map<String, dynamic> request);
  Future<void> openLink(String url);
  Future<String?> pickBackup();
  Future<bool> saveBackup(String snapshot);
  Future<String> loadTheme();
  Future<void> saveTheme(String theme);
}

class AndroidLibrary implements Library {
  static const channel = MethodChannel('org.sailune.mobile/library');
  int _sequence = 0;
  @override
  Future<dynamic> call(Map<String, dynamic> request) async {
    final response = await channel.invokeMethod<String>('call', {
      'id': '${DateTime.now().microsecondsSinceEpoch}-${_sequence++}',
      'payload': jsonEncode(request),
    });
    if (response == null) throw StateError('The library returned no response.');
    return jsonDecode(response);
  }

  @override
  Future<void> openLink(String url) => channel.invokeMethod('openLink', url);
  @override
  Future<String?> pickBackup() => channel.invokeMethod<String>('pickBackup');
  @override
  Future<bool> saveBackup(String snapshot) async =>
      await channel.invokeMethod<bool>('saveBackup', snapshot) ?? false;
  @override
  Future<String> loadTheme() async =>
      await channel.invokeMethod<String>('loadTheme') ?? 'system';
  @override
  Future<void> saveTheme(String theme) =>
      channel.invokeMethod('saveTheme', theme);
}

String errorMessage(Object error) => switch (error) {
  PlatformException(:final message) =>
    message ?? 'Something went wrong. Please try again.',
  MissingPluginException() =>
    'The Android library is unavailable. Please restart the app.',
  _ => error.toString().replaceFirst('Exception: ', ''),
};

Future<List<Story>> listStories(
  Library library,
  Map<String, dynamic> filter,
) async => (await library.call({'op': 'list', 'filter': filter}) as List)
    .map((e) => Story(Map<String, dynamic>.from(e as Map)))
    .toList();
