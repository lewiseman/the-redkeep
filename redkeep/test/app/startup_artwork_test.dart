import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/app/bootstrap/bootstrap_providers.dart';
import 'package:redkeep/app/bootstrap/startup_artwork.dart';
import 'package:redkeep/app/navigation_destination.dart';
import 'package:redkeep/features/assets/presentation/local_artwork.dart';
import 'package:redkeep/features/diary/presentation/diary_artwork.dart';

import '../support/fake_required_assets.dart';

void main() {
  testWidgets('warmup caches the visible diary artwork at its render sizes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final assets = _RecordingAssets();
    final container = ProviderContainer.test(
      overrides: [
        initialNavigationLocationProvider.overrideWithValue('/'),
        requiredAssetsProvider.overrideWith((_) async => assets),
      ],
    );

    await tester.runAsync(() async {
      await container.read(startupArtworkProvider.future);
      await container.pump();
      const expected = {
        'navigation.diary.active': 120,
        'navigation.notes.inactive': 120,
        'navigation.flow.inactive': 120,
        'navigation.more.inactive': 120,
        'diary.header': 800,
        'diary.calendar.pin': 48,
      };
      expect(assets.resolved, unorderedEquals(expected.keys));
      for (final entry in expected.entries) {
        final file = File.fromUri(await assets.fixture(entry.key));
        final status = await ResizeImage(
          FileImage(file),
          width: entry.value,
        ).obtainCacheStatus(configuration: ImageConfiguration.empty);
        expect(status?.keepAlive, isTrue, reason: entry.key);
      }

      // The first widgets get synchronous provider data and reuse the warm
      // cache without rechecking files or evicting the decoded images.
      expect(
        container
            .read(localArtworkFileProvider('navigation.diary.active'))
            .hasValue,
        isTrue,
      );
      expect(
        container.read(diaryImageProvider(('diary.header', 800))).hasValue,
        isTrue,
      );
      expect(assets.resolved, unorderedEquals(expected.keys));
    });
  });
}

class _RecordingAssets extends FakeRequiredAssets {
  final resolved = <String>[];

  Future<Uri> fixture(String key) => super.resolve(key);

  @override
  Future<Uri> resolve(String key) {
    resolved.add(key);
    return fixture(key);
  }
}
