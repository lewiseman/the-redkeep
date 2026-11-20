import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/core/presentation/emoji_sphere/emoji_catalog.dart';
import 'package:redkeep/core/presentation/emoji_sphere/emoji_sphere.dart';
import 'package:redkeep/core/presentation/emoji_sphere/sphere_feel.dart';
import 'package:redkeep/core/presentation/emoji_sphere/sphere_geometry.dart';
import 'package:redkeep/core/presentation/rendering_policy.dart';
import 'package:redkeep/features/appearance/domain/appearance_preferences.dart';

void main() {
  group('catalog', () {
    final catalog = EmojiCatalog.bundled();

    test('browsing puts favourites first, then faces', () {
      final order = catalog.browseOrder(['☕', '💡']);
      expect(order.take(3).map((e) => e.emoji), ['☕', '💡', '😀']);
      expect(order.toSet().length, order.length);
      expect(order.length, catalog.entries.length);
    });

    test('search reads names, feelings and the emoji itself', () {
      expect(catalog.search('coffee').map((e) => e.emoji), contains('☕'));
      expect(catalog.search('happy').map((e) => e.emoji), contains('😊'));
      expect(catalog.search('relieved').first.emoji, '😌');
      expect(catalog.search('😌').single.emoji, '😌');
      expect(catalog.search('  '), isEmpty);
      // Variation selectors don't matter.
      expect(catalog.find('☺'), catalog.find('☺️'));
    });
  });

  group('geometry', () {
    test('a turn between two points carries one onto the other', () {
      const from = Vec3(.6, .8, 0);
      final turned = SphereRotation.between(from, Vec3.front).rotate(from);
      expect(turned.x, closeTo(0, 1e-9));
      expect(turned.y, closeTo(0, 1e-9));
      expect(turned.z, closeTo(1, 1e-9));
    });

    test('cells sit in latitude rings, fewer toward the poles', () {
      final cells = latitudeRings(300);
      expect(cells.length, closeTo(300, 30));
      final rings = <double, int>{};
      for (final cell in cells) {
        rings.update(cell.latitude, (n) => n + 1, ifAbsent: () => 1);
        expect((cell.normal.length - 1).abs(), lessThan(1e-9));
        // East, north and out make a right-handed frame.
        final out = cell.east.cross(cell.north);
        expect(out.dot(cell.normal), closeTo(1, 1e-9));
      }
      final latitudes = rings.keys.toList()..sort();
      expect(
        rings[latitudes.first],
        lessThan(rings[latitudes[latitudes.length ~/ 2]]!),
      );
    });

    test('facing a cell brings it to the front, upright', () {
      for (final cell in [
        SphereCell.at(.3, 2.1),
        SphereCell.at(-1.2, -2.9),
        SphereCell.at(.01, math.pi),
      ]) {
        final turn = SphereRotation.facing(cell);
        final out = turn.rotate(cell.normal);
        final up = turn.rotate(cell.north);
        expect(out.z, closeTo(1, 1e-9));
        expect(up.y, closeTo(1, 1e-9));
      }
    });

    test('emoji stay upright on screen however the sphere is rolled', () {
      final rolled = SphereRotation.axisAngle(const Vec3(.3, -.7, .6), 2.4);
      for (final cell in latitudeRings(200)) {
        final out = rolled.rotate(cell.normal);
        if (out.z < .05) continue;
        final (east, north) = uprightFrame(out);
        // Up the patch is straight up the screen, and the frame stays a
        // right-handed one lying on the surface.
        expect(north.x, closeTo(0, 1e-9));
        expect(north.y, greaterThan(0));
        expect(north.dot(out), closeTo(0, 1e-9));
        expect(east.cross(north).dot(out), closeTo(1, 1e-9));
        expect(east.x, greaterThan(0));
      }
    });
  });

  group('sphere', () {
    setUp(SphereFeel.reset);

    Future<({List<String> changes, List<String> confirms})> pump(
      WidgetTester tester, {
      String? selected,
      List<String> favorites = const ['😊', '😌', '🤩'],
      bool reducedMotion = true,
      bool scrolling = false,
      ScrollController? scroll,
      EmojiSphereAction? action,
    }) async {
      final changes = <String>[];
      final confirms = <String>[];
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final sphere = EmojiSphere(
        selected: selected,
        favorites: favorites,
        onChanged: (entry) => changes.add(entry.emoji),
        onConfirm: (entry) => confirms.add(entry.emoji),
        action: action,
      );
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => RenderingPolicyScope(
            policy: RenderingPolicy(
              osReducedMotion: reducedMotion,
              preferences: const AppearancePreferences(),
            ),
            child: child!,
          ),
          home: Scaffold(
            body: scrolling
                ? ListView(
                    controller: scroll,
                    children: [sphere, const SizedBox(height: 2000)],
                  )
                : Center(child: sphere),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return (changes: changes, confirms: confirms);
    }

    String name(WidgetTester tester) => tester
        .widget<Text>(find.byKey(const ValueKey('emoji-sphere-name')))
        .data!;

    Offset centre(WidgetTester tester) =>
        tester.getCenter(find.byKey(const ValueKey('emoji-sphere')));

    testWidgets('opens on the chosen emoji without reporting it', (
      tester,
    ) async {
      final result = await pump(tester, selected: '🤩');
      expect(name(tester), 'Star-Struck');
      expect(result.changes, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('with nothing chosen it opens on a favourite, unreported', (
      tester,
    ) async {
      final result = await pump(tester);
      expect(name(tester), 'Smiling Face With Smiling Eyes');
      expect(result.changes, isEmpty);
    });

    testWidgets('search turns the best match to the centre; Search steps on', (
      tester,
    ) async {
      final result = await pump(tester, selected: '🤩');
      await tester.enterText(
        find.byKey(const ValueKey('emoji-sphere-search')),
        'calm',
      );
      await tester.pumpAndSettle();
      // The favourite leads its matches.
      expect(result.changes.last, '😌');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(result.changes.last, isNot('😌'));
      expect(
        EmojiCatalog.bundled().search('calm').map((e) => e.emoji),
        contains(result.changes.last),
      );
      // The search's ✕ clears it and keeps the emoji in the centre.
      final kept = result.changes.last;
      await tester.tap(find.byKey(const ValueKey('emoji-sphere-search-clear')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('emoji-sphere-search')),
            )
            .controller!
            .text,
        isEmpty,
      );
      expect(
        find.byKey(const ValueKey('emoji-sphere-search-clear')),
        findsNothing,
      );
      expect(result.changes.last, kept);
    });

    testWidgets('dragging any way turns the sphere to a new pick', (
      tester,
    ) async {
      final result = await pump(tester, selected: '😊', reducedMotion: false);
      // Diagonal: the sphere has no axis lock.
      await tester.dragFrom(centre(tester), const Offset(-70, 55));
      await tester.pumpAndSettle();
      expect(result.changes, hasLength(1));
      expect(result.changes.single, isNot('😊'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('turning is felt: detents as emoji pass, a click to seat, '
        'a thud to choose', (tester) async {
      // No vibration plugin in tests, so the system haptics stand in.
      final felt = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            felt.add(call.arguments as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final result = await pump(tester, selected: '😊', reducedMotion: false);
      await tester.dragFrom(centre(tester), const Offset(-70, 55));
      await tester.pumpAndSettle();
      expect(felt, contains('HapticFeedbackType.selectionClick'));
      expect(felt.last, 'HapticFeedbackType.lightImpact');
      await tester.tapAt(centre(tester));
      await tester.pumpAndSettle();
      expect(result.confirms, hasLength(1));
      expect(felt.last, 'HapticFeedbackType.mediumImpact');
    });

    testWidgets('tapping a neighbour turns to it; tapping the centre picks', (
      tester,
    ) async {
      final result = await pump(tester, selected: '😊');
      await tester.tapAt(centre(tester) + const Offset(0, 40));
      await tester.pumpAndSettle();
      expect(result.changes, hasLength(1));
      expect(result.confirms, isEmpty);
      await tester.tapAt(centre(tester));
      await tester.pumpAndSettle();
      expect(result.confirms, [result.changes.single]);
    });

    testWidgets('a drag on the sphere turns it instead of scrolling the page', (
      tester,
    ) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      final result = await pump(
        tester,
        selected: '😊',
        scrolling: true,
        scroll: scroll,
      );
      await tester.dragFrom(centre(tester), const Offset(0, -90));
      await tester.pumpAndSettle();
      expect(scroll.offset, 0);
      expect(result.changes, hasLength(1));
    });

    testWidgets('an action curves over the sphere, search under it', (
      tester,
    ) async {
      var pressed = 0;
      final result = await pump(
        tester,
        selected: '😊',
        action: EmojiSphereAction(
          key: const ValueKey('sphere-action'),
          label: 'Clear',
          icon: Icons.close_rounded,
          onPressed: () => pressed++,
        ),
      );
      final action = find.byKey(const ValueKey('sphere-action'));
      // The action over the crown; the search under the foot.
      expect(
        tester.getCenter(find.byKey(const ValueKey('emoji-sphere-search'))).dy,
        greaterThan(
          tester.getCenter(find.byKey(const ValueKey('emoji-sphere'))).dy,
        ),
      );
      expect(
        tester.getBottomLeft(action).dy,
        lessThan(
          tester.getCenter(find.byKey(const ValueKey('emoji-sphere'))).dy,
        ),
      );
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(pressed, 1);
      expect(result.changes, isEmpty);
      expect(find.bySemanticsLabel('Clear'), findsOneWidget);
    });

    testWidgets('narrow screens and large text still fit', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pump(tester, selected: '😊');
      tester.view.physicalSize = const Size(280, 600);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final size = tester.getSize(find.byKey(const ValueKey('emoji-sphere')));
      expect(size.width, lessThanOrEqualTo(280));
      expect(math.max(size.width, size.height), greaterThan(100));
    });
  });
}
