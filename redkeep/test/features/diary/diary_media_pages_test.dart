import 'package:redkeep/features/sync/application/sync_providers.dart';
import 'package:redkeep/app/app_router.dart';

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/app/storage_providers.dart';
import 'package:redkeep/features/diary/application/diary_providers.dart';
import 'package:redkeep/features/diary/application/diary_media_providers.dart';
import 'package:redkeep/features/diary/data/diary_photo_store.dart';
import 'package:redkeep/features/diary/data/drift_diary_repository.dart';
import 'package:redkeep/features/diary/domain/diary_document.dart';
import 'package:redkeep/features/diary/domain/diary_period.dart';
import 'package:redkeep/features/diary/presentation/add_diary_photos_page.dart';

import '../../support/pump_app.dart';

void main() {
  testWidgets('new editor media actions follow trimmed body emptiness', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final scale = ValueNotifier<double>(1);
    addTearDown(scale.dispose);
    final db = AppDatabase(NativeDatabase.memory());
    final repo = DriftDiaryRepository(db, clock: () => DateTime(2026, 11, 4));
    await pumpApp(
      tester,
      initialLocation: '/diary',
      database: db,
      diary: repo,
      diaryId: () => 'a' * 32,
    );
    await tester.pumpAndSettle();
    final scope = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold).first),
    );
    final date = DateTime(2026, 11, 2);
    scope.read(diaryNewIdsProvider.notifier).add('a' * 32);
    final router = await Future.value(scope.read(appRouterProvider));
    router.go(
      '/diary/${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}/entries/${'a' * 32}/edit',
    );
    await tester.pumpAndSettle();
    bool enabled(String name) =>
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == name,
              ),
            )
            .onPressed !=
        null;
    expect(enabled('Add photos'), isTrue);
    expect(enabled('Dictate'), isTrue);
    expect(find.byKey(const ValueKey('diary-title')), findsNothing);
    await tester.enterText(find.byKey(const ValueKey('diary-body')), 'Words');
    await tester.pump();
    expect(enabled('Add photos'), isFalse);
    await tester.enterText(find.byKey(const ValueKey('diary-body')), ' \t\n');
    await tester.pump();
    expect(enabled('Add photos'), isTrue);
    await tester.enterText(find.byKey(const ValueKey('diary-body')), 'Words');
    await tester.pump();
    expect(enabled('Dictate'), isTrue, reason: 'Dictation adds to writing.');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });
  testWidgets(
    'photo story is one captioned photos page, deduplicates, and saves',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = DriftDiaryRepository(db, clock: () => DateTime(2026, 11, 4));
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final scale = ValueNotifier<double>(1);
      addTearDown(scale.dispose);
      late Directory root;
      late File file;
      await tester.runAsync(() async {
        root = await Directory.systemTemp.createTemp('redkeep-photo-ui-');
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawColor(Colors.amber, BlendMode.src);
        final picture = recorder.endRecording();
        final image = await picture.toImage(40, 30);
        final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        file = File('${root.path}/synthetic.png');
        await file.writeAsBytes(data.buffer.asUint8List());
        image.dispose();
        picture.dispose();
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            syncEnabledProvider.overrideWithValue(false),
            appDatabaseProvider.overrideWithValue(db),
            diaryRepositoryProvider.overrideWithValue(repo),
            diaryPhotoStoreProvider.overrideWithValue(
              DiaryPhotoStore(
                db: db,
                supportDirectory: () => Future.value(root),
              ),
            ),
          ],
          child: MaterialApp(
            home: ValueListenableBuilder<double>(
              valueListenable: scale,
              builder: (context, value, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  disableAnimations: true,
                  textScaler: TextScaler.linear(value),
                ),
                child: child!,
              ),
              child: AddDiaryPhotosPage(
                date: DiaryPeriod(2026, 11, 4),
                newItemUuid: 'b' * 32,
                imagePicker: () async => [XFile(file.path), XFile(file.path)],
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pumpAndSettle();
      for (
        var i = 0;
        i < 50 &&
            find
                .byKey(const ValueKey('diary-photo-caption-0'))
                .evaluate()
                .isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      expect(
        find.byKey(const ValueKey('diary-photo-caption-0')),
        findsOneWidget,
        reason: find
            .byType(Text)
            .evaluate()
            .map((e) => (e.widget as Text).data)
            .join(' | '),
      );
      expect(find.byKey(const ValueKey('diary-photo-caption-1')), findsNothing);
      expect(find.text('Generate questions'), findsNothing);
      expect(find.byKey(const ValueKey('diary-section-reflect')), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('diary-photo-caption-0')),
        'Beach day',
      );
      await tester.pump();
      bool captionFocused() => tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(const ValueKey('diary-photo-caption-0')),
              matching: find.byType(EditableText),
            ),
          )
          .focusNode
          .hasFocus;
      expect(captionFocused(), isTrue);
      // The keyboard opening must not rebuild the caption field.
      tester.view.viewInsets = const FakeViewPadding(bottom: 400);
      await tester.pumpAndSettle();
      expect(captionFocused(), isTrue);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(320, 480);
      scale.value = 3;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(
        find.byKey(const ValueKey('diary-photo-save')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('diary-photo-save')));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pumpAndSettle();
      var entry = await tester.runAsync(() => repo.openDocument('b' * 32));
      for (var i = 0; i < 50 && entry?.entry == null; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
        entry = await tester.runAsync(() => repo.openDocument('b' * 32));
      }
      expect(
        entry?.entry,
        isNotNull,
        reason: find
            .byType(Text)
            .evaluate()
            .map((e) => (e.widget as Text).data)
            .join(' | '),
      );
      expect(entry!.entry!.photos.length, 1);
      expect(entry.entry!.photos.single.caption, 'Beach day');
      expect(entry.entry!.photos.single.reflections, isEmpty);

      // Reopened, the saved story is a preview until Edit.
      Future<void> reopen(DiaryEntry story) async {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              syncEnabledProvider.overrideWithValue(false),
              appDatabaseProvider.overrideWithValue(db),
              diaryRepositoryProvider.overrideWithValue(repo),
              diaryPhotoStoreProvider.overrideWithValue(
                DiaryPhotoStore(
                  db: db,
                  supportDirectory: () => Future.value(root),
                ),
              ),
            ],
            child: MaterialApp(
              home: MediaQuery(
                data: const MediaQueryData(disableAnimations: true),
                child: Navigator(
                  onGenerateRoute: (_) => MaterialPageRoute<void>(
                    builder: (_) => const Scaffold(body: Text('Diary')),
                  ),
                ),
              ),
            ),
          ),
        );
        tester.view.physicalSize = const Size(390, 844);
        scale.value = 1;
        final navigator = tester.state<NavigatorState>(
          find.byType(Navigator).last,
        );
        unawaited(
          navigator.push(
            MaterialPageRoute<bool>(
              builder: (_) => AddDiaryPhotosPage(
                date: DiaryPeriod(2026, 11, 4),
                story: story,
              ),
            ),
          ),
        );
        for (
          var i = 0;
          i < 50 &&
              find
                  .byKey(const ValueKey('diary-photo-caption-preview-0'))
                  .evaluate()
                  .isEmpty;
          i++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump();
        }
        await tester.pumpAndSettle();
      }

      await reopen(entry.entry!);
      expect(find.text('Beach day'), findsOneWidget);
      expect(find.byKey(const ValueKey('diary-photo-caption-0')), findsNothing);
      expect(find.byKey(const ValueKey('diary-photo-save')), findsNothing);
      expect(find.byTooltip('Remove photo 1'), findsNothing);
      expect(find.byTooltip('Add more photos'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('diary-photo-edit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('diary-photo-edit')), findsNothing);
      expect(find.byTooltip('Add more photos'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('diary-photo-caption-0')),
        'Unsaved',
      );
      await tester.pump();

      // Back leaves the editor for the preview and drops the change.
      await tester.tap(find.byKey(const ValueKey('diary-photo-cancel-edit')));
      for (
        var i = 0;
        i < 50 &&
            find
                .byKey(const ValueKey('diary-photo-caption-preview-0'))
                .evaluate()
                .isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(find.text('Beach day'), findsOneWidget);
      expect(find.text('Unsaved'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('diary-photo-edit')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('diary-photo-caption-0')),
        'Sunset swim',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('diary-photo-save')));
      for (var i = 0; i < 50; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
        entry = await tester.runAsync(() => repo.openDocument('b' * 32));
        if (entry?.entry?.photos.single.caption == 'Sunset swim') break;
      }
      expect(entry!.entry!.photos.single.caption, 'Sunset swim');
      await tester.pumpAndSettle();
      expect(find.text('Diary'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await db.close();
        await root.delete(recursive: true);
      });
    },
  );
}
