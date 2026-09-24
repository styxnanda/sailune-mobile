import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/story.dart';

abstract class Library {
  Future<dynamic> device(String method, [dynamic arguments]);
  Future<dynamic> call(Map<String, dynamic> request, {String? requestId});
  Future<void> cancel(String requestId);
  Future<void> openLink(String url);
  Future<void> openExternalLink(String url);
  Future<Map<String, bool>> websiteSessions();
  Future<bool> connectWebsite(String site, {required bool consent});
  Future<void> clearWebsiteSessions({required bool consent});
  Future<String?> pickBackup();
  Future<bool> saveBackup(String snapshot);
  Future<bool> loadOnboarding();
  Future<void> completeOnboarding();
  Future<String> loadTheme();
  Future<void> saveTheme(String theme);
}

class AndroidLibrary implements Library {
  @override
  Future<dynamic> device(String method, [dynamic arguments]) =>
      channel.invokeMethod(method, arguments);
  static const channel = MethodChannel('org.sailune.mobile/library');
  int _sequence = 0;
  @override
  Future<dynamic> call(
    Map<String, dynamic> request, {
    String? requestId,
  }) async {
    final response = await channel.invokeMethod<String>('call', {
      'id':
          requestId ??
          '${DateTime.now().microsecondsSinceEpoch}-${_sequence++}',
      'payload': jsonEncode(request),
    });
    if (response == null) throw StateError('The library returned no response.');
    return jsonDecode(response);
  }

  @override
  Future<void> cancel(String requestId) =>
      channel.invokeMethod('cancel', requestId);

  @override
  Future<Map<String, bool>> websiteSessions() async => Map<String, bool>.from(
    await channel.invokeMethod('websiteSessions') as Map,
  );
  @override
  Future<bool> connectWebsite(String site, {required bool consent}) async =>
      await channel.invokeMethod<bool>('connectWebsite', {
        'site': site,
        'consent': consent,
      }) ??
      false;
  @override
  Future<void> clearWebsiteSessions({required bool consent}) =>
      channel.invokeMethod('clearWebsiteSessions', {'consent': consent});

  @override
  Future<void> openLink(String url) => channel.invokeMethod('openLink', url);
  @override
  Future<void> openExternalLink(String url) =>
      channel.invokeMethod('openExternalLink', url);
  @override
  Future<String?> pickBackup() => channel.invokeMethod<String>('pickBackup');
  @override
  Future<bool> saveBackup(String snapshot) async =>
      await channel.invokeMethod<bool>('saveBackup', snapshot) ?? false;
  @override
  Future<bool> loadOnboarding() async =>
      await channel.invokeMethod<bool>('loadOnboarding') ?? false;
  @override
  Future<void> completeOnboarding() =>
      channel.invokeMethod('completeOnboarding');
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

Future<dynamic> organize(Library library, Map<String, dynamic> feature) =>
    library.call({'op': 'organize', 'feature': feature});
