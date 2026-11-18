import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/app/navigation_destination.dart';
import 'package:redkeep/features/stock_photos/domain/stock_photo_source.dart';
import 'package:redkeep/features/stock_photos/presentation/stock_photo_preview_page.dart';
import 'package:redkeep/features/stock_photos/presentation/stock_photo_search_page.dart';

import '../../support/fake_stock_photos.dart';
import '../../support/pump_app.dart';

final _id = 'a' * 32;

void main() {
  FakeStockPhotoSource photos({int pages = 1, int count = 6}) =>
      FakeStockPhotoSource(
        bytes: Uint8List.fromList([0xff, 0xd8, 0xff, 0]),
        pages: pages,
        photos: [for (var i = 0; i < count; i++) fakeStockPhoto('p$i')],
      );

  testWidgets('without a key the page explains what to set up', (tester) async {
    await pumpApp(tester, initialLocation: noteBackgroundSearchLocation(_id));
    await tester.pumpAndSettle();
    expect(find.text('Photo search is not set up'), findsOneWidget);
    expect(find.textContaining('UNSPLASH_ACCESS_KEY'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('searching shows results, an empty state and the credit', (
    tester,
  ) async {
    final source = photos();
    await pumpApp(
      tester,
      initialLocation: noteBackgroundSearchLocation(_id),
      stockPhotos: source,
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp('^Photo p0')), findsOneWidget);
    expect(find.text('Photos from Unsplash'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('stock-photo-search')),
      'nothing',
    );
    // Searches wait for a pause in typing.
    await tester.pump(StockPhotoSearchPage.debounce ~/ 2);
    expect(source.searches.map((s) => s.$1), ['']);
    await tester.pump(StockPhotoSearchPage.debounce);
    await tester.pumpAndSettle();
    expect(source.searches.last, ('nothing', 1));
    expect(find.text('Nothing found'), findsOneWidget);
  });

  testWidgets('a failure can be retried', (tester) async {
    final source = photos()..failure = StockPhotoFailure.rateLimited;
    await pumpApp(
      tester,
      initialLocation: noteBackgroundSearchLocation(_id),
      stockPhotos: source,
    );
    await tester.pumpAndSettle();
    expect(find.text('Photos did not load'), findsOneWidget);
    expect(find.textContaining('busy'), findsOneWidget);

    source.failure = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp('^Photo p0')), findsOneWidget);
  });

  testWidgets('scrolling to the end loads the next page', (tester) async {
    final source = photos(pages: 2, count: 30);
    await pumpApp(
      tester,
      initialLocation: noteBackgroundSearchLocation(_id),
      stockPhotos: source,
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -6000));
    await tester.pumpAndSettle();
    expect(source.searches, [('', 1), ('', 2)]);
    expect(find.bySemanticsLabel(RegExp(r'^Photo p\d+-2')), findsWidgets);
  });

  testWidgets('a failed download stays on the preview with a message', (
    tester,
  ) async {
    final source = photos();
    await pumpApp(
      tester,
      initialLocation: noteBackgroundSearchLocation(_id),
      stockPhotos: source,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel(RegExp('^Photo p1')));
    await tester.pumpAndSettle();
    source.failure = StockPhotoFailure.offline;
    await tester.tap(find.byKey(const ValueKey('stock-photo-use')));
    await tester.pumpAndSettle();
    expect(find.byType(StockPhotoPreviewPage), findsOneWidget);
    expect(find.text('You seem to be offline.'), findsOneWidget);
  });

  testWidgets('search and preview fit 320px with 3x text', (tester) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await pumpApp(
      tester,
      initialLocation: noteBackgroundSearchLocation(_id),
      stockPhotos: photos(),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // Two columns at this width.
    final first = tester.getRect(find.bySemanticsLabel(RegExp('^Photo p0')));
    final second = tester.getRect(find.bySemanticsLabel(RegExp('^Photo p1')));
    expect(second.top, first.top);
    expect(second.right, lessThanOrEqualTo(320));

    await tester.tap(find.bySemanticsLabel(RegExp('^Photo p0')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('stock-photo-use')),
      200,
    );
    expect(find.text('Ada Lens'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
