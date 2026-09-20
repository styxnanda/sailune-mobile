import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sailune_mobile/screens/collections_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sailune_mobile/main.dart';
import 'package:sailune_mobile/models/story.dart';
import 'package:sailune_mobile/screens/story_screen.dart';
import 'package:sailune_mobile/theme.dart';
import 'package:sailune_mobile/widgets/story_card.dart';

import 'support/fake_library.dart';

class OrganizedFake extends FakeLibrary {
  String mode = 'hidden';
  bool details = true;
  final collections = <Map<String, dynamic>>[];
  @override
  Future<dynamic> device(String method, [dynamic arguments]) async {
    if (method == 'loadArtworkPreferences') {
      return {'mode': mode, 'details': details};
    }
    if (method == 'saveArtworkPreferences') {
      mode = arguments['mode'] as String;
      details = arguments['details'] as bool;
      return null;
    }
    return super.device(method, arguments);
  }

  @override
  Future<dynamic> call(
    Map<String, dynamic> request, {
    String? requestId,
  }) async {
    if (request['op'] == 'organize') {
      final f = request['feature'] as Map;
      switch (f['action']) {
        case 'collections':
          return collections;
        case 'collection-save':
          final c = Map<String, dynamic>.from(f['collection'] as Map);
          c['id'] = 'test-collection';
          c['count'] = 0;
          collections.add(c);
          return c;
        case 'collection-delete':
          collections.clear();
          return null;
        case 'count':
          return rows.length;
        default:
          return <dynamic>[];
      }
    }
    return super.call(request, requestId: requestId);
  }
}

void main() {
  setUpAll(() async {
    final text = FontLoader('Sailune');
    for (final weight in ['Regular', 'Medium', 'Bold']) {
      text.addFont(rootBundle.load('assets/fonts/Roboto-$weight.ttf'));
    }
    await text.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  testWidgets('create and delete a collection leaves stories intact', (
    tester,
  ) async {
    final library = OrganizedFake();
    await tester.pumpWidget(SailuneApp(library: library));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Manage collections'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New collection'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Collection name'),
      'trauma-inducing',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save collection'));
    await tester.tap(find.text('Save collection'));
    await tester.pumpAndSettle();
    expect(library.collections.single['name'], 'trauma-inducing');
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Delete collection'),
      300,
      scrollable: find
          .descendant(
            of: find.byType(CollectionEditor),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('Delete collection'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete collection'));
    await tester.pumpAndSettle();
    expect(library.collections, isEmpty);
    expect(library.rows, hasLength(2));
    expect(tester.takeException(), isNull);
  });
  for (final dark in [false, true]) {
    for (final mode in ['portrait', 'background']) {
      testWidgets('$mode artwork layout ${dark ? 'dark' : 'light'}', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final library = OrganizedFake()
          ..mode = mode
          ..theme = dark ? 'dark' : 'light';
        await tester.pumpWidget(SailuneApp(library: library));
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => precacheImage(
            const AssetImage('assets/sailune.png'),
            tester.element(find.byType(SailuneApp)),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(SailuneApp),
          matchesGoldenFile(
            'goldens/v090_${mode}_${dark ? 'dark' : 'light'}.png',
          ),
        );
      });
    }
    testWidgets('overlapping detail header ${dark ? 'dark' : 'light'}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final library = OrganizedFake();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: sailuneTheme(dark ? Brightness.dark : Brightness.light),
          home: StoryScreen(library: library, initial: Story(sample())),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/v090_detail_${dark ? 'dark' : 'light'}.png'),
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('portrait cards adapt to large text on narrow screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final library = OrganizedFake();
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: StoryCard(
                story: Story(sample()),
                library: library,
                coverMode: 'portrait',
                onOpen: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
