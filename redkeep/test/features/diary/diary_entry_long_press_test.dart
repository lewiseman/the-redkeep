import 'dart:async';
import 'dart:io';
import 'dart:ui' show SemanticsAction;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:redkeep/app/navigation_destination.dart';
import 'package:redkeep/app/storage_providers.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/ai/application/ai_lifecycle.dart';
import 'package:redkeep/features/appearance/domain/appearance_preferences.dart';
import 'package:redkeep/features/diary/application/diary_media_providers.dart';
import 'package:redkeep/features/diary/application/diary_paper_providers.dart';
import 'package:redkeep/features/diary/application/diary_providers.dart';
import 'package:redkeep/features/diary/data/diary_photo_store.dart';
import 'package:redkeep/features/diary/data/drift_diary_repository.dart';
import 'package:redkeep/features/diary/domain/diary_ai_conversation.dart';
import 'package:redkeep/features/diary/domain/diary_document.dart';
import 'package:redkeep/features/diary/domain/diary_period.dart';
import 'package:redkeep/features/diary/domain/diary_photo.dart';
import 'package:redkeep/features/diary/presentation/diary_scene.dart';
import 'package:redkeep/features/diary/presentation/diary_edit_page.dart';
import 'package:redkeep/features/diary/presentation/diary_sheet.dart';
import 'package:redkeep/features/sync/application/sync_providers.dart';

import '../../support/fake_appearance_repository.dart';
import '../../support/pump_app.dart';

const _first = '11111111111111111111111111111111';
const _second = '22222222222222222222222222222222';
final _today = DiaryPeriod(2026, 11, 2);

class _MissingPhotos extends DiaryPhotoStore {
  @override
  Future<File?> resolve(String path, {String? expectedHash}) async => null;
}

Finder _entry(String id) => find.descendant(
  of: find.byKey(const ValueKey('diary-live-content')),
  matching: find.byKey(ValueKey('diary-entry-$id')),
);

Future<void> _immerse(WidgetTester tester) async {
  final scene = tester.widget<DiaryScene>(find.byType(DiaryScene));
  final nested = tester.state<NestedScrollViewState>(
    find.byType(NestedScrollView),
  );
  nested.outerController.jumpTo(scene.collapseExtent);
  await tester.pumpAndSettle();
  expect(tester.widget<DiaryScene>(find.byType(DiaryScene)).collapse, 1);
}

void main() {
  testWidgets(
    'only full immersion enables editing the pressed entry, and Back retains immersion',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final db = AppDatabase(NativeDatabase.memory());
      final repo = DriftDiaryRepository(db, clock: () => DateTime(2026, 11, 2));
      final semantics = tester.ensureSemantics();
      try {
        for (final (id, body) in [
          (_first, 'First saved entry.'),
          (_second, 'Second saved entry.'),
        ]) {
          await repo.save(
            id: id,
            date: _today,
            text: DiaryText(body: body),
            expectedRevision: 0,
          );
        }
        final router = await pumpApp(
          tester,
          database: db,
          diary: repo,
          initialLocation: diaryDayLocation(_today),
        );
        expect(
          tester
              .getSemantics(_entry(_first))
              .getSemanticsData()
              .hasAction(SemanticsAction.longPress),
          isFalse,
        );
        await tester.longPress(_entry(_first));
        await tester.pumpAndSettle();
        expect(
          router.routeInformationProvider.value.uri.path,
          diaryDayLocation(_today),
        );
        final nested = tester.state<NestedScrollViewState>(
          find.byType(NestedScrollView),
        );
        final scene = tester.widget<DiaryScene>(find.byType(DiaryScene));
        nested.outerController.jumpTo(scene.collapseExtent / 2);
        await tester.pumpAndSettle();
        await tester.longPress(_entry(_first));
        await tester.pumpAndSettle();
        expect(
          router.routeInformationProvider.value.uri.path,
          diaryDayLocation(_today),
        );
        await _immerse(tester);
        expect(
          tester
              .getSemantics(_entry(_second))
              .getSemanticsData()
              .hasAction(SemanticsAction.longPress),
          isTrue,
        );
        await tester.longPress(_entry(_second));
        await tester.pumpAndSettle();
        expect(
          GoRouterState.of(tester.element(find.byType(DiaryEditPage))).uri.path,
          diaryEntryLocation(_today, _second, edit: true),
        );
        final body = find.byKey(const ValueKey('diary-body'));
        expect(
          tester.widget<TextField>(body).controller!.text,
          'Second saved entry.',
        );
        await tester.enterText(body, 'Second entry revised.');
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Save entry'));
        await tester.tap(find.text('Save entry'));
        await tester.pumpAndSettle();
        expect(
          (await repo.openDocument(_first)).entry!.text.body,
          'First saved entry.',
        );
        expect(
          (await repo.openDocument(_second)).entry!.text.body,
          'Second entry revised.',
        );
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(
          router.routeInformationProvider.value.uri.path,
          diaryDayLocation(_today),
        );
        expect(tester.widget<DiaryScene>(find.byType(DiaryScene)).collapse, 1);
        await tester.longPress(_entry(_first));
        await tester.pumpAndSettle();
        expect(
          GoRouterState.of(tester.element(find.byType(DiaryEditPage))).uri.path,
          diaryEntryLocation(_today, _first, edit: true),
        );
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        semantics.dispose();
        await db.close();
      }
    },
  );

  for (final period in [
    DiaryPeriod.week(_today.start),
    DiaryPeriod.month(2026, 11),
    DiaryPeriod.year(2026),
  ]) {
    testWidgets(
      'immersed ${period.kind.name} entries open their own editor with simpler effects',
      (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        final repo = DriftDiaryRepository(
          db,
          clock: () => DateTime(2026, 11, 2),
        );
        final appearance = FakeAppearanceRepository(
          const AppearancePreferences(simplerEffects: true),
        );
        try {
          await repo.save(
            id: _first,
            date: period,
            text: const DiaryText(body: 'Period writing.'),
            expectedRevision: 0,
          );
          await pumpApp(
            tester,
            database: db,
            diary: repo,
            repository: appearance,
            initialLocation: diaryDayLocation(period),
          );
          await _immerse(tester);
          await tester.longPress(_entry(_first));
          await tester.pumpAndSettle();
          expect(
            GoRouterState.of(tester.element(find.byType(DiaryEditPage)))
                .uri
                .path,
            diaryEntryLocation(period, _first, edit: true),
          );
          expect(
            tester
                .widget<TextField>(find.byKey(const ValueKey('diary-body')))
                .controller!
                .text,
            'Period writing.',
          );
        } finally {
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
          await db.close();
          await appearance.close();
        }
      },
    );
  }

  for (final photo in [false, true]) {
    testWidgets(
      'long pressing a ${photo ? 'photo' : 'conversation'} entry uses the matching editor',
      (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        final entry = DiaryEntry(
          id: _first,
          date: _today,
          text: const DiaryText(body: 'Saved words.'),
          revision: 1,
          createdAt: DateTime(2026, 11, 2),
          updatedAt: DateTime(2026, 11, 2),
          photos: photo
              ? const [
                  DiaryPhoto(
                    id: 'photo_test',
                    path: 'diary_photos/missing.png',
                  ),
                ]
              : const [],
          conversation: photo
              ? null
              : DiaryAiConversation(
                  turns: const [
                    {'speaker': 'user', 'text': 'Saved words.'},
                  ],
                  createdAt: DateTime(2026, 11, 2),
                ),
        );
        final router = GoRouter(
          initialLocation: '/diary',
          routes: [
            GoRoute(
              path: '/diary',
              builder: (context, state) => Scaffold(
                body: SingleChildScrollView(
                  child: DiaryDayContent(
                    day: DiaryPaperDay(date: _today, entries: [entry]),
                    interactive: true,
                    enableEntryEditing: true,
                  ),
                ),
              ),
              routes: [
                GoRoute(
                  path: ':date/entries/:id/:mode',
                  builder: (_, state) =>
                      Scaffold(body: Text(state.pathParameters['mode']!)),
                ),
              ],
            ),
          ],
        );
        try {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                appDatabaseProvider.overrideWithValue(db),
                diaryPhotoStoreProvider.overrideWithValue(_MissingPhotos()),
                syncCanEditProvider.overrideWithValue(true),
                aiEnabledProvider.overrideWithValue(false),
                diaryClockProvider.overrideWithValue(
                  () => DateTime(2026, 11, 2),
                ),
              ],
              child: MaterialApp.router(routerConfig: router),
            ),
          );
          await tester.pumpAndSettle();
          await tester.longPress(
            photo
                ? find.byKey(const ValueKey('diary-photo-story-$_first'))
                : find.text('Conversation'),
          );
          await tester.pumpAndSettle();
          expect(
            GoRouterState.of(
              tester.element(find.text(photo ? 'photos' : 'edit')),
            ).uri.path,
            photo
                ? '${diaryEntryLocation(_today, _first)}/photos'
                : diaryEntryLocation(_today, _first, edit: true),
          );
        } finally {
          await tester.pumpWidget(const SizedBox());
          router.dispose();
          await db.close();
        }
      },
    );
  }

  testWidgets(
    'entry editing follows live state, immersion, permissions and pending actions',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final entry = DiaryEntry(
        id: _first,
        date: _today,
        text: const DiaryText(body: 'Saved words.'),
        revision: 1,
        createdAt: DateTime(2026, 11, 2),
        updatedAt: DateTime(2026, 11, 2),
      );
      final day = DiaryPaperDay(date: _today, entries: [entry]);
      Future<void> mount({
        bool interactive = true,
        bool immersed = true,
        bool canEdit = true,
      }) => tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            syncCanEditProvider.overrideWithValue(canEdit),
            aiEnabledProvider.overrideWithValue(false),
            diaryClockProvider.overrideWithValue(() => DateTime(2026, 11, 2)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: DiaryDayContent(
                  day: day,
                  interactive: interactive,
                  enableEntryEditing: immersed,
                ),
              ),
            ),
          ),
        ),
      );
      GestureDetector gesture() => tester.widget<GestureDetector>(
        find.byKey(const ValueKey('diary-entry-$_first')),
      );
      final gate = Completer<void>();
      try {
        await mount();
        expect(gesture().onLongPress, isNotNull);
        await mount(immersed: false);
        expect(gesture().onLongPress, isNull);
        await mount(interactive: false);
        expect(gesture().onLongPress, isNull);
        await mount(canEdit: false);
        expect(gesture().onLongPress, isNull);
        await mount();
        expect(gesture().onLongPress, isNotNull);
        final container = ProviderScope.containerOf(
          tester.element(find.byType(DiaryDayContent)),
        );
        final action = container
            .read(diaryActionsProvider.notifier)
            .run((_) => gate.future);
        await tester.pump();
        expect(gesture().onLongPress, isNull);
        gate.complete();
        await action;
        await tester.pump();
        expect(gesture().onLongPress, isNotNull);
      } finally {
        if (!gate.isCompleted) gate.complete();
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        await db.close();
      }
    },
  );
}
