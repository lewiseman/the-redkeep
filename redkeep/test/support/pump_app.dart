import 'package:redkeep/features/notes/data/note_media_store.dart';
import 'package:redkeep/features/voice/application/voice_coordination.dart';
import 'package:redkeep/features/voice/application/voice_capture.dart';
import 'package:drift/native.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/recall/application/recall_controller.dart';

import 'fake_ai.dart';

import 'package:redkeep/features/ai/application/ai_lifecycle.dart';
import 'package:redkeep/features/appearance/application/appearance_typography.dart';

import 'fake_appearance_fonts.dart';

import 'package:redkeep/features/sync/application/sync_providers.dart';
import 'package:redkeep/features/flow/application/flow_providers.dart';
import 'package:redkeep/features/flow/domain/flow_repository.dart';
import 'package:redkeep/features/diary/application/diary_providers.dart';
import 'package:redkeep/features/diary/domain/diary_repository.dart';

import 'empty_diary_repository.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:redkeep/app/app_router.dart';
import 'package:redkeep/app/redkeep_app.dart';
import 'package:redkeep/app/storage_providers.dart';
import 'package:redkeep/app/bootstrap/bootstrap_providers.dart';
import 'package:redkeep/features/notes/application/notes_providers.dart';
import 'package:redkeep/features/notes/domain/notes_repository.dart';

import 'fake_appearance_repository.dart';
import 'fake_ai_provider.dart';
import 'fake_required_assets.dart';
import 'fake_onboarding_repository.dart';

import 'package:redkeep/features/ai/application/ai_cloud.dart';
import 'package:redkeep/features/ai/domain/ai_provider.dart';
import 'package:redkeep/features/diary/application/diary_reader_day.dart';
import 'package:redkeep/features/diary/domain/diary_period.dart';

Future<GoRouter> pumpApp(
  WidgetTester tester, {
  String? initialLocation,
  AppearanceFontLoader fontLoader = fakeAppearanceFontLoader,
  FakeAppearanceRepository? repository,
  FakeOnboardingRepository? onboarding,
  FakeRequiredAssets? assets,
  FlowRepository? flow,
  String Function()? flowId,
  NotesRepository? notes,
  NoteMediaStore? noteMedia,
  String Function()? noteId,
  DiaryRepository? diary,
  String Function()? diaryId,
  DiaryPeriod? diaryDay,
  FakeAiProviderClient? aiProvider,
  bool aiEnabled = false,
  AppDatabase? database,
  AiCloudSettings? aiSettings = testAiSettings,
  FakeEmbedder? embedder,
  VoiceCapture Function(String)? voiceCapture,
}) async {
  final db = database ?? AppDatabase(NativeDatabase.memory());
  if (database == null) addTearDown(db.close);
  final preferences = repository ?? FakeAppearanceRepository();
  if (repository == null) addTearDown(preferences.close);
  addTearDown(() => tester.pumpWidget(const SizedBox()));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (voiceCapture != null)
          voiceCaptureFactoryProvider.overrideWithValue(voiceCapture),
        appDatabaseProvider.overrideWithValue(db),
        recallVectorsProvider.overrideWith((ref) async => MemoryVectors()),
        recallEmbedderProvider.overrideWithValue(embedder ?? FakeEmbedder()),
        syncEnabledProvider.overrideWithValue(false),
        aiEnabledProvider.overrideWithValue(aiEnabled),
        appearanceFontLoaderProvider.overrideWithValue(fontLoader),
        fontPreviewLoaderProvider.overrideWithValue(FakeFontPreviewLoader()),
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
        if (diaryDay != null)
          diaryReaderDayProvider.overrideWithBuild(
            (ref, notifier) => DiaryReaderDay(diaryDay),
          ),
        if (flow != null) flowRepositoryProvider.overrideWithValue(flow),
        if (flowId != null) flowIdProvider.overrideWithValue(flowId),
        if (notes != null) notesRepositoryProvider.overrideWithValue(notes),
        if (noteMedia != null)
          noteMediaStoreProvider.overrideWithValue(noteMedia),
        if (noteId != null) noteIdProvider.overrideWithValue(noteId),
        protectedAiProvidersProvider.overrideWithValue(
          MemoryAiProviders(saved: aiSettings),
        ),
        aiCloudClientProvider.overrideWithValue(
          aiProvider ?? FakeAiProviderClient(),
        ),
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

/// Scrolls [target] to mid-viewport, clear of the page's pinned app bar.
Future<void> revealBelowAppBar(WidgetTester tester, Finder target) async {
  await Scrollable.ensureVisible(tester.element(target), alignment: .5);
  await tester.pump();
}
