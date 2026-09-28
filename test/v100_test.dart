import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sailune_mobile/screens/settings_screen.dart';
import 'package:sailune_mobile/theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sailune_mobile/main.dart';
import 'package:sailune_mobile/screens/collections_screen.dart';
import 'package:sailune_mobile/screens/editor_screen.dart';
import 'package:sailune_mobile/widgets/story_card.dart';

import 'support/fake_library.dart';

class MembershipLibrary extends FakeLibrary {
  final members = <int>{1};
  @override
  Future<dynamic> call(
    Map<String, dynamic> request, {
    String? requestId,
  }) async {
    if (request['op'] == 'list' && request['filter']['Collection'] == 'shelf') {
      return rows.where((s) => members.contains(s['id'])).toList();
    }
    if (request['op'] == 'organize' &&
        request['feature']['action'] == 'membership') {
      requests.add(request);
      members.addAll((request['feature']['ids'] as List).cast<int>());
      return null;
    }
    return super.call(request, requestId: requestId);
  }
}

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
  for (final dark in [false, true]) {
    testWidgets('settings footer and compact filters visual $dark', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final library = MembershipLibrary();
      final theme = sailuneTheme(dark ? Brightness.dark : Brightness.light);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme,
          home: SettingsScreen(
            library: library,
            theme: 'light',
            onTheme: (_) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => precacheImage(
          const AssetImage('assets/sailune.png'),
          tester.element(find.byType(SettingsScreen)),
        ),
      );
      await tester.scrollUntilVisible(find.text('1.0.0'), 400);
      await tester.pumpAndSettle();
      expect(find.text('Version 1.0.0'), findsNothing);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/v100_settings_$dark.png'),
      );
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme,
          home: CollectionEditor(
            library: library,
            membersOnly: true,
            collection: const {
              'id': 'shelf',
              'name': 'Shelf',
              'kind': 'manual',
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Find stories by tags'));
      await tester.pumpAndSettle();
      expect(
        tester
            .getSize(
              find.widgetWithText(TextField, 'Personal tags · one per line'),
            )
            .height,
        lessThan(80),
      );
      await tester.scrollUntilVisible(
        find.text('Fandom suggestions'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/v100_filters_$dark.png'),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('swipes switch main tabs in both directions', (tester) async {
    await tester.pumpWidget(SailuneApp(library: FakeLibrary()));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(StoryCard).first, const Offset(-200, 0));
    await tester.pumpAndSettle();
    expect(find.byType(CollectionsScreen), findsOneWidget);
    await tester.drag(find.byType(CollectionsScreen), const Offset(200, 0));
    await tester.pumpAndSettle();
    expect(find.byType(CollectionsScreen), findsNothing);
    expect(find.byType(StoryCard), findsWidgets);
  });

  for (final signedIn in [false, true]) {
    testWidgets('FFN fetching and manual fields follow session $signedIn', (
      tester,
    ) async {
      final library = FakeLibrary()..sessions['ffn'] = signedIn;
      await tester.pumpWidget(
        MaterialApp(home: EditorScreen(library: library)),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Story URL'),
        'https://www.fanfiction.net/s/1/1',
      );
      await tester.pumpAndSettle();
      final toggle = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
      expect(toggle.value, signedIn);
      expect(toggle.onChanged == null, !signedIn);
      expect(
        tester
            .widget<TextFormField>(find.widgetWithText(TextFormField, 'Title'))
            .enabled,
        !signedIn,
      );
      expect(
        tester
            .widget<TextFormField>(find.widgetWithText(TextFormField, 'Author'))
            .enabled,
        !signedIn,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Story URL'),
        'https://archiveofourown.org/works/1',
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        true,
      );
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.widgetWithText(TextFormField, 'Title'))
            .enabled,
        true,
      );
    });
  }

  testWidgets(
    'existing members stay checked and only new selections are added',
    (tester) async {
      final library = MembershipLibrary();
      await tester.pumpWidget(
        MaterialApp(
          home: CollectionEditor(
            library: library,
            membersOnly: true,
            collection: const {
              'id': 'shelf',
              'name': 'Shelf',
              'kind': 'manual',
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final first = tester.widget<CheckboxListTile>(
        find.byType(CheckboxListTile).first,
      );
      expect(first.value, true);
      expect(first.onChanged, isNull);
      expect(
        tester
            .widget<CheckboxListTile>(find.byType(CheckboxListTile).last)
            .value,
        false,
      );
      await tester.ensureVisible(find.text('Select page'));
      await tester.tap(find.text('Select page'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Add selected to collection'));
      await tester.tap(find.text('Add selected to collection'));
      await tester.pumpAndSettle();
      expect(
        library.requests.lastWhere(
          (r) =>
              r['op'] == 'organize' && r['feature']['action'] == 'membership',
        )['feature']['ids'],
        [2],
      );
      expect(
        tester
            .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
            .every((tile) => tile.value == true && tile.onChanged == null),
        true,
      );
    },
  );
}
