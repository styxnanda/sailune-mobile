import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sailune_mobile/data/library.dart';

// Run only on a disposable emulator: this test creates and removes its own story.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('real Android bridge persists, exports, and resolves chapters', (
    tester,
  ) async {
    final library = AndroidLibrary();
    final identity = DateTime.now().microsecondsSinceEpoch;
    final story = await library.call({
      'op': 'add',
      'bookmark': {
        'url': 'https://www.fanfiction.net/s/$identity/1',
        'title': 'Android integration fixture',
        'status': 'reading',
        'chapter': 0,
      },
    }) as Map;
    final id = story['id'];
    try {
      await library.call({
        'op': 'update',
        'id': id,
        'patch': {'Chapter': 3, 'Notes': 'Persisted in SQLite', 'Rating': 4},
      });
      final reopened = AndroidLibrary();
      final saved = await reopened.call({'op': 'get', 'id': id}) as Map;
      expect(saved['chapter'], 3);
      expect(saved['notes'], 'Persisted in SQLite');
      expect(
        await reopened.call({'op': 'resume', 'id': id}),
        'https://www.fanfiction.net/s/$identity/4',
      );
      final snapshot = await reopened.call({'op': 'export'}) as String;
      expect((jsonDecode(snapshot) as Map)['format'], 'sailune-library');
      final merged =
          await reopened.call({'op': 'import', 'snapshot': snapshot}) as Map;
      expect(merged['imported'], 0);
      expect(merged['skipped'], greaterThanOrEqualTo(1));
      await expectLater(
        reopened.call({
          'op': 'add',
          'bookmark': {'url': 'https://fanfiction.net/s/$identity/2'},
        }),
        throwsException,
      );
      await reopened.saveTheme('dark');
      expect(await reopened.loadTheme(), 'dark');
      await reopened.saveTheme('system');
    } finally {
      await library.call({'op': 'delete', 'id': id});
    }
  });
}
