import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../appearance/application/appearance_controller.dart';
import '../../diary/application/diary_paper_providers.dart';
import '../../diary/application/diary_providers.dart';
import '../data/home_widget_bridge.dart';
import '../domain/home_widget_snapshot.dart';

final homeWidgetBridgeProvider = Provider<HomeWidgetBridge>(
  (ref) => const PlatformHomeWidgetBridge(),
);

/// The encoded widget snapshot, or null until the diary and appearance have
/// loaded (an early empty snapshot would flash a blank month).
final homeWidgetSnapshotProvider = Provider.autoDispose<String?>((ref) {
  final written = ref.watch(diaryCalendarDatesProvider).value;
  final moods = ref.watch(diaryCalendarMoodsProvider).value;
  final appearance = ref.watch(appearanceControllerProvider);
  if (written == null || moods == null || !appearance.loaded) return null;
  return jsonEncode(
    homeWidgetSnapshot(
      written: written,
      moods: moods,
      appearance: appearance.preferences,
      today: ref.read(diaryClockProvider)(),
    ),
  );
});

/// Keeps the home screen widgets in step with the diary while the app runs.
/// Bursts of saves (typing, sync) collapse into one update.
class HomeWidgetSync extends ConsumerStatefulWidget {
  const HomeWidgetSync({
    super.key,
    required this.child,
    this.delay = const Duration(milliseconds: 600),
  });
  final Widget child;
  final Duration delay;

  @override
  ConsumerState<HomeWidgetSync> createState() => _HomeWidgetSyncState();
}

class _HomeWidgetSyncState extends ConsumerState<HomeWidgetSync> {
  Timer? _timer;
  String? _published;

  @override
  void initState() {
    super.initState();
    ref.listenManual(homeWidgetSnapshotProvider, (_, next) {
      if (next == null || next == _published) return;
      _timer?.cancel();
      _timer = Timer(widget.delay, () {
        _published = next;
        unawaited(ref.read(homeWidgetBridgeProvider).publish(next));
      });
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
