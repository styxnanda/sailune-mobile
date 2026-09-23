import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sailune_mobile/main.dart';
import 'package:sailune_mobile/models/story.dart';
import 'package:sailune_mobile/screens/collections_screen.dart';
import 'package:sailune_mobile/screens/story_screen.dart';
import 'package:sailune_mobile/theme.dart';
import 'package:sailune_mobile/widgets/artwork.dart';
import 'package:sailune_mobile/widgets/collection_card.dart';
import 'package:sailune_mobile/widgets/story_card.dart';

import 'organization_test.dart' show OrganizedFake;
import 'support/fake_library.dart';

Map<String, dynamic> collection(String id, String name) => {
  'id': id,
  'name': name,
  'kind': 'manual',
  'rules': {},
  'count': 2,
};

void main() {
  setUpAll(() async {
    final fonts = FontLoader('Sailune');
    for (final weight in ['Regular', 'Medium', 'Bold']) {
      fonts.addFont(rootBundle.load('assets/fonts/Roboto-$weight.ttf'));
    }
    await fonts.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  testWidgets(
    'collection opens a story wall with filters and separate editors',
    (tester) async {
      final library = OrganizedFake()
        ..collections.add(collection('shelf', 'Quiet nights'));
      await tester.pumpWidget(SailuneApp(library: library));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Collections'));
      await tester.pumpAndSettle();
      expect(find.byType(CollectionCard), findsOneWidget);
      expect(find.text('2 stories'), findsOneWidget);
      await tester.tap(find.byType(CollectionCard));
      await tester.pumpAndSettle();
      expect(find.byType(StoryCard), findsNWidgets(2));
      expect(
        library.requests
            .where((r) => r['op'] == 'list')
            .last['filter']['Collection'],
        'shelf',
      );
      expect(find.byTooltip('Filter stories'), findsOneWidget);
      await tester.tap(find.byTooltip('Edit collection details'));
      await tester.pumpAndSettle();
      expect(find.byType(CollectionEditor), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Search stories'), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Add or remove collection stories'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Collection name'), findsNothing);
      await tester.drag(find.byType(ListView).last, const Offset(0, -900));
      await tester.pumpAndSettle();
      expect(find.text('Add selected to collection'), findsOneWidget);
    },
  );
  testWidgets('membership picker marks existing and newly added collections', (
    tester,
  ) async {
    final library = OrganizedFake()
      ..collections.addAll([
        collection('one', 'Already shelved'),
        collection('two', 'New shelf'),
      ])
      ..membership.add('one');
    await tester.pumpWidget(
      MaterialApp(
        theme: sailuneTheme(Brightness.light),
        home: Builder(
          builder: (ctx) => Scaffold(
            body: TextButton(
              onPressed: () => assignCollection(ctx, library, 1),
              child: const Text('Choose'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Choose'));
    await tester.pumpAndSettle();
    expect(find.text('Already in this collection'), findsOneWidget);
    final already = tester.widget<ListTile>(
      find.widgetWithText(ListTile, 'Already shelved'),
    );
    expect(already.enabled, isFalse);
    await tester.tap(find.text('New shelf'));
    await tester.pumpAndSettle();
    expect(find.text('Already in this collection'), findsNWidgets(2));
    expect(library.membership, contains('two'));
  });
  testWidgets(
    'detail banner fills viewport and action row matches primary width',
    (tester) async {
      tester.view.physicalSize = const Size(430, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: sailuneTheme(Brightness.light),
          home: StoryScreen(library: OrganizedFake(), initial: Story(sample())),
        ),
      );
      await tester.pumpAndSettle();
      final banner = tester.getRect(find.byType(StoryArtHeader));
      expect(banner.left, 0);
      expect(banner.width, 430);
      expect(banner.height, greaterThan(450));
      await tester.ensureVisible(find.text('Add to collection'));
      await tester.pumpAndSettle();
      final first = tester.getRect(
        find.widgetWithText(OutlinedButton, 'Add to collection'),
      );
      final second = tester.getRect(
        find.widgetWithText(OutlinedButton, 'Artwork'),
      );
      final primary = tester.getRect(
        find.widgetWithText(FilledButton, 'Read next chapter'),
      );
      expect(first.left, primary.left);
      expect(second.right, primary.right);
      expect(second.left - first.right, 12);
      expect(first.top, second.top);
    },
  );
  for (final dark in [false, true]) {
    for (final mode in ['hidden', 'portrait', 'background']) {
      testWidgets('collection cards $mode ${dark ? 'dark' : 'light'}', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final library = OrganizedFake()
          ..mode = mode
          ..theme = dark ? 'dark' : 'light'
          ..collections.add(collection('shelf', 'Trauma-inducing'));
        library.rows = [for (var i = 1; i <= 5; i++) sample(id: i)];
        await tester.pumpWidget(SailuneApp(library: library));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Collections'));
        await tester.pumpAndSettle();
        final slices = tester
            .widgetList<Expanded>(
              find.descendant(
                of: find.byType(CollectionCard),
                matching: find.byType(Expanded),
              ),
            )
            .map((w) => w.flex)
            .toList();
        expect(slices, [40, 15, 15, 15, 15]);
        final images = tester.widgetList<StoryArtwork>(
          find.descendant(
            of: find.byType(CollectionCard),
            matching: find.byType(StoryArtwork),
          ),
        );
        if (mode == 'hidden') {
          expect(images, isEmpty);
        } else {
          expect(images.length, 5);
          expect(
            images.every(
              (w) => w.role == (mode == 'portrait' ? 'cover' : 'background'),
            ),
            isTrue,
          );
        }
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(SailuneApp),
          matchesGoldenFile(
            'goldens/v095_collections_${mode}_${dark ? 'dark' : 'light'}.png',
          ),
        );
      });
    }
  }
}
