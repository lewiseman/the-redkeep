import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/core/notifications/notification_permission.dart';
import 'package:redkeep/features/more/presentation/notifications_switch.dart';

class _FakePermission implements NotificationPermission {
  _FakePermission({required this.on, this.grants = true});
  bool on;
  bool grants;
  int requests = 0, settingsOpened = 0;

  @override
  Future<bool> enabled() async => on;

  @override
  Future<bool> request() async {
    requests++;
    if (grants) on = true;
    return on;
  }

  @override
  Future<void> openSettings() async => settingsOpened++;
}

void main() {
  Future<void> pump(WidgetTester tester, _FakePermission permission) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationPermissionProvider.overrideWithValue(permission),
        ],
        child: const MaterialApp(home: Scaffold(body: NotificationsSwitch())),
      ),
    );
    await tester.pumpAndSettle();
  }

  bool switchedOn(WidgetTester tester) =>
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value;

  testWidgets('turning on asks Android and shows the answer', (tester) async {
    final permission = _FakePermission(on: false);
    await pump(tester, permission);
    expect(switchedOn(tester), isFalse);
    expect(find.textContaining('Off.'), findsOneWidget);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(permission.requests, 1);
    expect(permission.settingsOpened, 0);
    expect(switchedOn(tester), isTrue);
    expect(find.textContaining('On.'), findsOneWidget);
  });

  testWidgets('a refused request opens Android settings instead', (
    tester,
  ) async {
    final permission = _FakePermission(on: false, grants: false);
    await pump(tester, permission);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(permission.requests, 1);
    expect(permission.settingsOpened, 1);
    expect(switchedOn(tester), isFalse);
  });

  testWidgets(
    'turning off opens Android settings, and the switch catches up on return',
    (tester) async {
      final permission = _FakePermission(on: true);
      await pump(tester, permission);
      expect(switchedOn(tester), isTrue);

      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(permission.requests, 0);
      expect(permission.settingsOpened, 1);
      expect(switchedOn(tester), isTrue);

      // The person switched them off in Android, then came back.
      permission.on = false;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(switchedOn(tester), isFalse);
    },
  );
}
