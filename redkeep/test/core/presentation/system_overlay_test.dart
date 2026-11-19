import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/core/presentation/redkeep_theme.dart';
import 'package:redkeep/core/presentation/system_overlay.dart';

void main() {
  test('icons contrast with the backdrop', () {
    expect(
      systemOverlayOn(Colors.white).statusBarIconBrightness,
      Brightness.dark,
    );
    expect(
      systemOverlayOn(const Color(0xFF8E1B1B)).statusBarIconBrightness,
      Brightness.light,
    );
  });

  testWidgets('leaving a tinted page restores the theme status bar', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    final theme = RedkeepTheme.light;
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        theme: theme,
        builder: (context, child) => SystemOverlayFallback(child: child!),
        // Like the notes list: no AppBar declares a style.
        home: const Scaffold(body: SizedBox.expand()),
      ),
    );
    await tester.pumpAndSettle();
    expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.dark);

    // A red note asks for light icons.
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(
            backgroundColor: const Color(0xFF8E1B1B),
            systemOverlayStyle: systemOverlayOn(const Color(0xFF8E1B1B)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.light);

    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.dark);
  });
}
