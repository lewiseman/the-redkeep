import '../../voice/application/voice_receipts.dart';

import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart'
    show ScaffoldMessenger, SnackBar, SnackBarAction, Text;

import '../../diary/data/diary_picker_recovery.dart';
import '../../diary/application/diary_providers.dart';
import '../../voice/application/voice_coordination.dart';
import '../../diary/application/diary_media_providers.dart';
import '../../diary/application/diary_photo_question_controller.dart';
import '../../diary/data/diary_photo_question_store.dart';

import 'package:drift/drift.dart' show TableUpdateQuery;

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
    await ref.read(voiceActiveProvider.notifier).stopAll();
    await ref.read(aiJobsProvider.notifier).stopForReset();
    await ref.read(recallControllerProvider.notifier).stopForReset();
    await ref.read(aiJobStoreProvider).clear();
    await ref.read(voiceStoreProvider).clearAll();
    await DiaryPickerRecovery().reset();
    await ref.read(diaryPhotoStoreProvider).clearAll();
    await ref.read(diaryPhotoQuestionStoreProvider).clearAll();
    ref.invalidate(diaryPhotoQuestionProvider);
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
    ref.invalidate(diaryPhotoStoreProvider);
    ref.invalidate(diaryPhotoQuestionStoreProvider);
    ref.invalidate(voiceReceiptsProvider);
    ref.invalidate(voiceStoreProvider);
    final active = ref.read(aiForegroundProvider);
    ref.read(aiJobsProvider.notifier).foreground(active);
    ref.read(recallControllerProvider.notifier).foreground(active);
    if (active) {
      unawaited(ref.read(voiceReceiptsProvider).drain().catchError((_) {}));
    }
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
        unawaited(ref.read(voiceStoreProvider).cleanup().catchError((_) {}));
        unawaited(_recoverPicker());
        unawaited(
          ref.read(diaryPhotoStoreProvider).reconcile().catchError((_) {}),
        );
      }
    });
  }

  Future<void> _recoverPicker() async {
    try {
      final pending = await DiaryPickerRecovery().recover();
      if (!mounted || pending?['files'] is! List) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 30),
          content: const Text('Your selected diary photos were recovered.'),
          action: SnackBarAction(
            label: 'Open photos',
            onPressed: () {
              final id = pending!['id'] as String;
              ref.read(diaryNewIdsProvider.notifier).add(id);
              context.push('/diary/${pending['date']}/entries/$id/photos');
            },
          ),
        ),
      );
    } catch (_) {
      /* Retain the address and retry on next startup. */
    }
  }

  void _foreground(bool active) {
    ref.read(aiForegroundProvider.notifier).set(active);
    ref.read(aiJobsProvider.notifier).foreground(active);
    ref.read(recallControllerProvider.notifier).foreground(active);
    if (active) {
      unawaited(ref.read(voiceReceiptsProvider).drain().catchError((_) {}));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (ref.read(aiEnabledProvider)) {
      _foreground(state == AppLifecycleState.resumed);
      if (state != AppLifecycleState.resumed) {
        unawaited(ref.read(voiceActiveProvider.notifier).suspend());
      }
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
    ref.watch(diaryPhotoQuestionProvider);
    ref.watch(diaryPhotoStoreProvider);
    ref.listen(diaryMediaChangesProvider, (_, _) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(
            ref.read(diaryPhotoStoreProvider).reconcile().catchError((_) {}),
          );
        }
      });
    });
    ref.listen(companionControllerProvider, (previous, next) {
      if (next.phase == CompanionPhase.connected &&
          previous?.phase != next.phase) {
        scheduleMicrotask(() {
          if (mounted) {
            unawaited(ref.read(aiJobsProvider.notifier).restore());
            unawaited(
              ref.read(voiceReceiptsProvider).drain().catchError((_) {}),
            );
          }
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

final diaryMediaChangesProvider = StreamProvider<void>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db
      .tableUpdates(
        TableUpdateQuery.onAllTables([db.diaryEntries, db.diaryMediaOps]),
      )
      .map((_) {});
});
