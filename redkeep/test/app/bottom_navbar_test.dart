import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/app/bottom_navbar.dart';
import 'package:redkeep/core/presentation/redkeep_theme.dart';
import 'package:redkeep/core/presentation/rendering_policy.dart';
import 'package:redkeep/features/appearance/domain/appearance_preferences.dart';
import 'package:redkeep/features/assets/presentation/local_artwork.dart';

void main() {
  Future<void> pumpBar(
    WidgetTester tester, {
    required ValueNotifier<int> selected,
    double width = 400,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Artwork stays loading; layout does not depend on it.
          localArtworkFileProvider.overrideWith(
            (ref, _) => Completer<Uri>().future,
          ),
        ],
        child: MaterialApp(
          theme: RedkeepTheme.light,
          home: MediaQuery.withClampedTextScaling(
            minScaleFactor: textScale,
            maxScaleFactor: textScale,
            child: RenderingPolicyScope(
              policy: RenderingPolicy(
                osReducedMotion: false,
                preferences: const AppearancePreferences(),
              ),
              child: Scaffold(
                bottomNavigationBar: ValueListenableBuilder(
                  valueListenable: selected,
                  builder: (context, index, _) => RedkeepBottomNavbar(
                    selectedIndex: index,
                    onSelected: (next) => selected.value = next,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final slots = find.descendant(
    of: find.byType(RedkeepBottomNavbar),
    matching: find.byType(CustomMultiChildLayout),
  );

  Rect tab(WidgetTester tester, String label) =>
      tester.getRect(find.bySemanticsLabel('$label tab'));

  testWidgets('the active tab opens into a chip and the bar stays compact', (
    tester,
  ) async {
    final selected = ValueNotifier(0);
    await pumpBar(tester, selected: selected);
    final bar = tester.getRect(slots);
    expect(bar.width, lessThan(400 * .8));
    expect(bar.center.dx, closeTo(200, 1));
    expect(tab(tester, 'Diary').width, greaterThan(tab(tester, 'Notes').width));
    expect(tab(tester, 'Notes').width, tab(tester, 'More').width);

    await tester.tap(find.bySemanticsLabel('More tab'));
    await tester.pumpAndSettle();
    expect(selected.value, 2);
    expect(tab(tester, 'More').width, greaterThan(tab(tester, 'Diary').width));
    // The bar keeps one width whichever tab is open.
    expect(tester.getRect(slots), bar);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a narrow screen with large text keeps the bar on screen', (
    tester,
  ) async {
    await pumpBar(tester, selected: ValueNotifier(1), width: 320, textScale: 3);
    final bar = tester.getRect(slots);
    expect(bar.left, greaterThanOrEqualTo(0));
    expect(bar.right, lessThanOrEqualTo(320));
    expect(tab(tester, 'Notes').height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
  });
}
