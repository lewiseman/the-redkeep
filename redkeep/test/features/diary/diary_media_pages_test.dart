import '../../support/fake_ai.dart';

import 'package:redkeep/features/companion/application/companion_controller.dart';
import 'package:redkeep/features/sync/application/sync_providers.dart';
import 'package:redkeep/app/app_router.dart';

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
import 'package:redkeep/features/diary/presentation/add_diary_photos_page.dart';
import 'package:redkeep/features/diary/presentation/photos/diary_photo_entry_book.dart';
import 'package:redkeep/features/diary/presentation/photos/diary_reflection_desk.dart';

import '../../support/pump_app.dart';

void main() {
  testWidgets(
    'new editor media actions follow trimmed title and body emptiness',
    (tester) async {
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
      expect(enabled('Talk to your diary'), isTrue);
      await tester.enterText(
        find.byKey(const ValueKey('diary-title')),
        'Title',
      );
      await tester.pump();
      expect(enabled('Add photos'), isFalse);
      await tester.enterText(find.byKey(const ValueKey('diary-title')), ' \t');
      await tester.enterText(find.byKey(const ValueKey('diary-body')), ' \n');
      await tester.pump();
      expect(enabled('Add photos'), isTrue);
      await tester.enterText(find.byKey(const ValueKey('diary-body')), 'Words');
      await tester.pump();
      expect(enabled('Talk to your diary'), isFalse);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await db.close();
    },
  );
  testWidgets(
    'photo story moves through offline reflection and review, deduplicates, and saves photos only',
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
            companionControllerProvider.overrideWith(() => TestConnection()),
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
                date: DateTime(2026, 11, 4),
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
      await tester.tap(find.byKey(const ValueKey('diary-section-reflect')));
      await tester.pumpAndSettle();
      expect(find.byType(DiaryReflectionDesk), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('diary-section-photos')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Just the photos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Just the photos'));
      await tester.pumpAndSettle();
      expect(find.byType(DiaryPhotoEntryBook), findsOneWidget);
      tester.view.physicalSize = const Size(320, 480);
      scale.value = 3;
      await tester.pumpAndSettle();
      for (final stage in ['photos', 'reflect', 'review']) {
        await tester.tap(find.byKey(ValueKey('diary-section-$stage')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
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
      expect(entry.entry!.text.body, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await db.close();
        await root.delete(recursive: true);
      });
    },
  );
}
