import 'package:redkeep/features/sync/application/sync_providers.dart';
import 'package:redkeep/features/flow/application/flow_providers.dart';
import 'package:redkeep/features/flow/domain/flow_repository.dart';
import 'package:redkeep/features/diary/application/diary_providers.dart';
import 'package:redkeep/features/diary/domain/diary_repository.dart';

import 'empty_diary_repository.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:redkeep/app/app_router.dart';
import 'package:redkeep/app/redkeep_app.dart';
import 'package:redkeep/app/storage_providers.dart';
import 'package:redkeep/app/bootstrap/bootstrap_providers.dart';
import 'package:redkeep/features/notes/application/notes_providers.dart';
import 'package:redkeep/features/notes/domain/notes_repository.dart';

import 'fake_appearance_repository.dart';
import 'fake_required_assets.dart';
import 'fake_onboarding_repository.dart';

import 'package:redkeep/features/brain/domain/brain.dart';
import 'package:redkeep/features/brain/application/brain_executor.dart';
import 'package:redkeep/features/brain/application/brain_providers.dart';

Future<GoRouter> pumpApp(
  WidgetTester tester, {
  String? initialLocation,
  FakeAppearanceRepository? repository,
  FakeOnboardingRepository? onboarding,
  FakeRequiredAssets? assets,
  FlowRepository? flow,
  String Function()? flowId,
  NotesRepository? notes,
  String Function()? noteId,
  DiaryRepository? diary,
  String Function()? diaryId,
  BrainAssignments? brainAssignments,
  BrainModelFiles? brainFiles,
  BrainModelLoader? brainLoader,
}) async {
  final preferences = repository ?? FakeAppearanceRepository();
  if (repository == null) addTearDown(preferences.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        syncEnabledProvider.overrideWithValue(false),
        appearanceRepositoryProvider.overrideWithValue(preferences),
        onboardingRepositoryProvider.overrideWithValue(
          onboarding ?? FakeOnboardingRepository(),
        ),
        requiredAssetsProvider.overrideWith(
          (ref) async => assets ?? FakeRequiredAssets(),
        ),
        releaseSplashProvider.overrideWithValue(() {}),
        diaryRepositoryProvider.overrideWithValue(
          diary ?? EmptyDiaryRepository(),
        ),
        diaryClockProvider.overrideWithValue(() => DateTime(2026, 11, 2, 12)),
        if (diaryId != null) diaryIdProvider.overrideWithValue(diaryId),
        if (flow != null) flowRepositoryProvider.overrideWithValue(flow),
        if (flowId != null) flowIdProvider.overrideWithValue(flowId),
        if (notes != null) notesRepositoryProvider.overrideWithValue(notes),
        if (noteId != null) noteIdProvider.overrideWithValue(noteId),
        if (brainAssignments != null)
          brainAssignmentsProvider.overrideWithValue(brainAssignments),
        if (brainFiles != null)
          brainModelFilesProvider.overrideWith((ref) async => brainFiles),
        if (brainLoader != null)
          brainModelLoaderProvider.overrideWithValue(brainLoader),
        if (initialLocation != null)
          appRouterProvider.overrideWith((ref) {
            return createAppRouter(ref, initialLocation: initialLocation);
          }),
      ],
      child: const RedkeepApp(),
    ),
  );
  await tester.pumpAndSettle();
  return tester.container().read(appRouterProvider);
}
