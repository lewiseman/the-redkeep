import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/storage_providers.dart';
import '../../companion/application/companion_controller.dart';
import '../../recall/application/recall_controller.dart';
import '../domain/ai_operation.dart';
import 'ai_jobs.dart';
import 'ai_preferences.dart';

/// A consumed boundary for offline shell tests. Production starts only inside
/// the writing shell, after startup and onboarding have completed.
final aiEnabledProvider = Provider<bool>((ref) => true);
final aiForegroundProvider = NotifierProvider<AiForeground, bool>(
  AiForeground.new,
);

class AiForeground extends Notifier<bool> {
  @override
  bool build() =>
      WidgetsBinding.instance.lifecycleState == null ||
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  void set(bool value) {
    if (state != value) state = value;
  }
}

final aiResetProvider = Provider<Future<void> Function()>(
  (ref) => () async {
    if (!ref.read(aiEnabledProvider)) return;
    await ref.read(aiJobsProvider.notifier).stopForReset();
    await ref.read(recallControllerProvider.notifier).stopForReset();
    await ref.read(aiJobStoreProvider).clear();
    await (await ref.read(recallVectorsProvider.future)).reset();
    // The existing durable account-reset marker remains until these operations
    // and the primary-database clear have all succeeded. Repeating is safe.
    final db = ref.read(appDatabaseProvider);
    await db.delete(db.recallManifests).go();
  },
);

final aiResumeAfterResetProvider = Provider<void Function()>(
  (ref) => () {
    if (!ref.read(aiEnabledProvider)) return;
    final active = ref.read(aiForegroundProvider);
    ref.read(aiJobsProvider.notifier).foreground(active);
    ref.read(recallControllerProvider.notifier).foreground(active);
  },
);

class AiLifecycleHost extends ConsumerStatefulWidget {
  const AiLifecycleHost({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<AiLifecycleHost> createState() => _AiLifecycleHostState();
}

class _AiLifecycleHostState extends ConsumerState<AiLifecycleHost>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(aiEnabledProvider)) {
        _foreground(ref.read(aiForegroundProvider));
      }
    });
  }

  void _foreground(bool active) {
    ref.read(aiForegroundProvider.notifier).set(active);
    ref.read(aiJobsProvider.notifier).foreground(active);
    ref.read(recallControllerProvider.notifier).foreground(active);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (ref.read(aiEnabledProvider)) {
      _foreground(state == AppLifecycleState.resumed);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(aiEnabledProvider)) return widget.child;
    ref.watch(aiPreferencesProvider);
    ref.watch(recallControllerProvider);
    ref.listen(companionControllerProvider, (previous, next) {
      if (next.phase == CompanionPhase.connected &&
          previous?.phase != next.phase) {
        scheduleMicrotask(() {
          if (mounted) unawaited(ref.read(aiJobsProvider.notifier).restore());
        });
      }
    });
    ref.listen(aiPreferencesProvider, (_, next) {
      if (next.value?.dailyQuestions == false &&
          ref.read(aiJobsProvider).job?.operation ==
              AiOperation.dailyQuestion) {
        scheduleMicrotask(() async {
          if (!mounted) return;
          await ref.read(aiJobsProvider.notifier).cancel();
          if (mounted) await ref.read(aiJobsProvider.notifier).clear();
        });
      }
    });
    return widget.child;
  }
}
