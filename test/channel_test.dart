import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sailune_mobile/data/library.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Android protocol retains explicit zero values and surfaces errors',
    () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final requests = <MethodCall>[];
      messenger.setMockMethodCallHandler(AndroidLibrary.channel, (call) async {
        requests.add(call);
        return 'true';
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(AndroidLibrary.channel, null),
      );
      final library = AndroidLibrary();
      await library.call({
        'op': 'update',
        'id': 1,
        'patch': {'Chapter': 0, 'Rating': 0, 'Notes': ''},
      });
      final data = jsonDecode(
        (requests.single.arguments as Map)['payload'] as String,
      ) as Map;
      expect(data['patch'], {'Chapter': 0, 'Rating': 0, 'Notes': ''});
      messenger.setMockMethodCallHandler(AndroidLibrary.channel, (_) async {
        throw PlatformException(code: 'library', message: 'Duplicate story');
      });
      await expectLater(
        library.call({'op': 'add'}),
        throwsA(isA<PlatformException>()),
      );
    },
  );
}
