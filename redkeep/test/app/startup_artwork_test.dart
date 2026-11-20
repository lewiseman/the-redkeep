import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/app/bootstrap/startup_artwork.dart';
import 'package:redkeep/app/navigation_destination.dart';
import 'package:redkeep/features/assets/domain/app_artwork.dart';
import 'package:redkeep/features/assets/presentation/local_artwork.dart';

void main() {
  testWidgets('warmup decodes the visible diary artwork at its render size', (
    tester,
  ) async {
    final container = ProviderContainer.test(
      overrides: [initialNavigationLocationProvider.overrideWithValue('/')],
    );

    await tester.runAsync(() async {
      await container.read(startupArtworkProvider.future);
      for (final key in const [
        'navigation.diary.active',
        'navigation.notes.inactive',
        'navigation.more.inactive',
      ]) {
        final status = await localArtworkImage(key)
            .obtainCacheStatus(configuration: ImageConfiguration.empty);
        expect(status?.keepAlive, isTrue, reason: key);
      }
    });
  });

  test('every artwork key names a bundled image', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    for (final path in appArtwork.values) {
      final data = await rootBundle.load(path);
      expect(data.lengthInBytes, greaterThan(0), reason: path);
    }
  });
}
