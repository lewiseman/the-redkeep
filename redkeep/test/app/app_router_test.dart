import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/app/app_router.dart';

import '../support/pump_app.dart';

void main() {
  testWidgets('injected initial destination recovers to home', (tester) async {
    final router = await pumpApp(tester, initialLocation: '/missing?private=x');

    expect(router.routeInformationProvider.value.uri.path, '/missing');
    expect(find.text('Page not found'), findsOneWidget);
    expect(find.textContaining('private'), findsNothing);

    await tester.tap(find.text('Return home'));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.toString(), '/');
    expect(find.text('Welcome to Redkeep'), findsOneWidget);
    expect(router.canPop(), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unknown navigation uses the same fallback and recovery', (
    tester,
  ) async {
    final router = await pumpApp(tester);

    router.go('/not-registered');
    await tester.pumpAndSettle();
    expect(find.text('Page not found'), findsOneWidget);

    await tester.tap(find.text('Return home'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to Redkeep'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, '/');
    expect(tester.takeException(), isNull);
  });

  test('provider scopes own independent routers and navigation state', () {
    final first = ProviderContainer.test();
    final second = ProviderContainer.test();
    final firstRouter = first.read(appRouterProvider);
    final secondRouter = second.read(appRouterProvider);

    firstRouter.go('/missing');

    expect(firstRouter.routeInformationProvider.value.uri.path, '/missing');
    expect(secondRouter.routeInformationProvider.value.uri.path, '/');
    expect(first.read(appRouterProvider), same(firstRouter));
    expect(secondRouter, isNot(same(firstRouter)));
  });
}
