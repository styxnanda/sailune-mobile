import 'dart:convert';
import 'dart:io';

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
    expect((await library.websiteSessions()).keys, containsAll(['ao3', 'ffn']));
    await expectLater(
      library.connectWebsite('ao3', consent: false),
      throwsException,
    );
    await expectLater(
      library.clearWebsiteSessions(consent: false),
      throwsException,
    );
    await library.completeOnboarding();
    expect(await AndroidLibrary().loadOnboarding(), isTrue);
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
      final collection = await organize(reopened, {
        'action': 'collection-save',
        'collection': {
          'name': 'Integration $identity',
          'kind': 'manual',
          'rules': {},
        },
      }) as Map;
      final temp = await Directory.systemTemp.createTemp('sailune-v090-test-');
      try {
        await organize(reopened, {
          'action': 'membership',
          'collection_id': collection['id'],
          'ids': [id],
          'remove': false,
        });
        expect(
          await organize(reopened, {
            'action': 'count',
            'filter': {'Collection': collection['id']},
          }),
          1,
        );
        final overviews = await reopened.call({
          'op': 'collection-overviews',
          'id': id,
        }) as List;
        final overview = overviews.singleWhere(
          (r) => r['collection']['id'] == collection['id'],
        ) as Map;
        expect(overview['count'], 1);
        expect(overview['average'], 4);
        expect(overview['contains'], true);
        expect((overview['preview'] as List).single['id'], id);
        // A real PNG fixture avoids requiring a GPU just to test native storage.
        final imageFile = File('${temp.path}/cover.png');
        await imageFile.writeAsBytes(
          base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAHgAAAC0CAIAAADQLH9KAAABUUlEQVR4nO3QAQkAIADAMKMawQhGt4XCHTzA2Zhr60Lj+cEngQbdCjToVqBBtwINuhVo0K1Ag24FGnQr0KBbgQbdCjToVqBBtwINuhVo0K1Ag24FGnQr0KBbgQbdCjToVqBBtwINuhVo0K1Ag24FGnQr0KBbgQbdCjToVqBBtwINuhVo0K1Ag24FGnQr0KBbgQbdCjToVqBBtwINuhVo0K1Ag24FGnQr0KBbgQbdCjToVqBBtwINuhVo0K1Ag24FGnQr0KBbgQbdCjToVqBBtwINuhVo0K1Ag24FGnQr0KBbgQbdCjToVqBBtwINuhVo0K1Ag24FGnQr0KBbgQbdCjToVqBBtwINuhVo0K1Ag24FGnQr0KBbgQbdCjToVqBBtwINuhVo0K1Ag24FGnQr0KBbgQbdCjToVqBBtwINuhVo0K1Ag24FGnQr0KBbgQbd6gDSmcRzE58LsAAAAABJRU5ErkJggg==',
          ),
        );
        final art = await organize(reopened, {
          'action': 'artwork-set',
          'id': id,
          'role': 'cover',
          'path': imageFile.path,
          'x': 0.5,
          'y': 0.5,
        }) as Map;
        final bytes = await reopened.device('artworkData', {
          'asset': art['asset_id'],
          'small': true,
        });
        expect(bytes, isNotEmpty);
        final backup = '${temp.path}/library.zip';
        await organize(reopened, {'action': 'backup-export', 'path': backup});
        expect(await File(backup).length(), greaterThan(100));
        final imported = await organize(reopened, {
          'action': 'backup-import',
          'path': backup,
          'merge': true,
        }) as Map;
        expect(imported['imported'], 0);
        await reopened.device('saveArtworkPreferences', {
          'mode': 'portrait',
          'details': false,
        });
        final prefs = await reopened.device('loadArtworkPreferences') as Map;
        expect(prefs['mode'], 'portrait');
        expect(prefs['details'], false);
        await reopened.device('saveArtworkPreferences', {
          'mode': 'hidden',
          'details': true,
        });
      } finally {
        await organize(reopened, {
          'action': 'collection-delete',
          'collection_id': collection['id'],
        });
        await temp.delete(recursive: true);
      }
      await reopened.saveTheme('dark');
      expect(await reopened.loadTheme(), 'dark');
      await reopened.saveTheme('system');
    } finally {
      await library.call({'op': 'delete', 'id': id});
    }
  });
}
