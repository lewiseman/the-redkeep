import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/features/appearance/domain/appearance_preferences.dart';
import 'package:redkeep/features/appearance/presentation/appearance_page.dart';

import '../support/fake_appearance_repository.dart';
import '../support/pump_app.dart';

void main() {
  for (final reduced in [false, true]) {
    testWidgets(
      'Android system back cancels and commits; reduced motion $reduced',
      (tester) async {
        final appearance = FakeAppearanceRepository(
          AppearancePreferences(reduceMotion: reduced),
        );
        addTearDown(appearance.close);
        final router = await pumpApp(
          tester,
          initialLocation: '/settings',
          repository: appearance,
        );
        Future<void> send(
          String method, [
          Map<String, Object?>? arguments,
        ]) async {
          await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
            'flutter/backgesture',
            const StandardMethodCodec().encodeMethodCall(
              MethodCall(method, arguments),
            ),
            (_) {},
          );
          await tester.pump();
        }

        const start = <String, Object?>{
          'touchOffset': <double>[5, 240],
          'progress': 0.0,
          'swipeEdge': 0,
        };
        const update = <String, Object?>{
          'touchOffset': <double>[160, 240],
          'progress': 0.4,
          'swipeEdge': 0,
        };
        final route = ModalRoute.of(
          tester.element(find.byType(AppearancePage)),
        )!;
        await send('startBackGesture', start);
        await send('updateBackGestureProgress', update);
        expect(route.popGestureInProgress, !reduced);
        await send('cancelBackGesture');
        await tester.pumpAndSettle();
        expect(find.byType(AppearancePage), findsOneWidget);
        expect(router.canPop(), isTrue);
        await send('startBackGesture', start);
        await send('updateBackGestureProgress', update);
        await send('commitBackGesture');
        await tester.pumpAndSettle();
        expect(find.text('Welcome to Redkeep'), findsOneWidget);
        expect(router.canPop(), isFalse);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }
}
