import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redkeep/app/storage_providers.dart';
import 'package:redkeep/core/presentation/diary_typography.dart';
import 'package:redkeep/core/storage/app_database.dart';
import 'package:redkeep/features/ai/application/ai_lifecycle.dart';
import 'package:redkeep/features/diary/application/diary_media_providers.dart';
import 'package:redkeep/features/diary/application/diary_paper_providers.dart';
import 'package:redkeep/features/diary/application/diary_providers.dart';
import 'package:redkeep/features/diary/data/diary_photo_store.dart';
import 'package:redkeep/features/diary/domain/diary_period.dart';
import 'package:redkeep/features/diary/domain/diary_document.dart';
import 'package:redkeep/features/diary/domain/diary_photo.dart';
import 'package:redkeep/features/diary/presentation/diary_paper_curl.dart';
import 'package:redkeep/features/diary/presentation/diary_sheet.dart';
import 'package:redkeep/features/diary/presentation/diary_writing_prompt.dart';
import 'package:redkeep/features/sync/application/sync_providers.dart';

import '../../support/warm_diary_faces.dart';

final _canEdit = NotifierProvider<_EditAccess, bool>(_EditAccess.new);

class _EditAccess extends Notifier<bool> {
  @override
  bool build() => true;
  void change(bool value) => state = value;
}

class _PhotoStore extends DiaryPhotoStore {
  final photo = Completer<File?>();
  @override
  Future<File?> resolve(String path, {String? expectedHash}) => photo.future;
}

void main() {
  final date = DiaryPeriod(2026, 11, 1);
  DiaryPaperDay day(String words, {bool photo = false}) => DiaryPaperDay(
    date: date,
    entries: [
      DiaryEntry(
        id: 'a' * 32,
        date: date,
        text: DiaryText(body: words),
        revision: 1,
        createdAt: DateTime(2026, 11, 1),
        updatedAt: DateTime(2026, 11, 1),
        photos: photo
            ? const [DiaryPhoto(id: 'photo', path: 'diary_photos/test.png')]
            : const [],
      ),
    ],
  );

  testWidgets(
    'cached paper refreshes content, access, theme, text metrics and late photos',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final photos = _PhotoStore();
      var current = day('Original writing');
      var dark = false;
      var scale = 1.0;
      var height = 480.0;
      final lightTheme = ThemeData.light().copyWith(
        extensions: const [DiaryTypography(body: TextStyle(fontSize: 17))],
      );
      final darkTheme = ThemeData.dark().copyWith(
        extensions: const [DiaryTypography(body: TextStyle(fontSize: 21))],
      );
      Future<void> mount() async {
        final theme = dark ? darkTheme : lightTheme;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              diaryPhotoStoreProvider.overrideWithValue(photos),
              syncCanEditProvider.overrideWith((ref) => ref.watch(_canEdit)),
              aiEnabledProvider.overrideWithValue(false),
              diaryClockProvider.overrideWithValue(() => DateTime(2026, 11, 2)),
            ],
            child: MaterialApp(
              themeAnimationDuration: Duration.zero,
              theme: theme,
              home: Builder(
                builder: (context) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: Center(
                    child: SizedBox(
                      width: 320,
                      height: 600,
                      child: DiaryPaperCurl(
                        progress: 0,
                        direction: 1,
                        travel: 400,
                        paper: theme.colorScheme.surface,
                        flat: true,
                        warm: true,
                        child: DiarySheet(day: current, minimumHeight: height),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await warmDiaryFaces(tester);
      }

      await mount();
      final face = tester.renderObject<RenderDiaryCurl>(
        find.byType(DiaryPaperCurl),
      );
      final original = tester.widget<Text>(find.text('Original writing'));
      final frontCaptures = face.debugFrontCaptures;
      height = 520;
      await mount();
      expect(
        tester.widget<Text>(find.text('Original writing')),
        same(original),
      );
      current = day('Updated writing');
      await mount();
      expect(find.text('Original writing'), findsNothing);
      expect(find.text('Updated writing'), findsOneWidget);
      expect(face.debugFrontCaptures, greaterThan(frontCaptures));
      expect(find.byType(DiaryTitlePrompt), findsOneWidget);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(DiarySheet)),
      );
      container.read(_canEdit.notifier).change(false);
      await tester.pump();
      await warmDiaryFaces(tester);
      expect(find.byType(DiaryTitlePrompt), findsNothing);
      final lightInk = tester
          .widget<Text>(find.text('Updated writing'))
          .style!
          .color;
      dark = true;
      scale = 3;
      await mount();
      final updated = tester.widget<Text>(find.text('Updated writing'));
      expect(updated.style!.color, isNot(lightInk));
      expect(updated.style!.fontSize, 21);
      expect(
        MediaQuery.textScalerOf(tester.element(find.text('Updated writing')))
            .scale(21),
        63,
      );

      current = day('Updated writing', photo: true);
      await mount();
      final pendingCaptures = face.debugFrontCaptures;
      late Directory root;
      late File file;
      await tester.runAsync(() async {
        root = await Directory.systemTemp.createTemp('redkeep-sheet-cache-');
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawColor(Colors.amber, BlendMode.src);
        final picture = recorder.endRecording();
        final image = await picture.toImage(40, 30);
        final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        file = await File('${root.path}/photo.png')
            .writeAsBytes(data.buffer.asUint8List());
        image.dispose();
        picture.dispose();
        photos.photo.complete(file);
      });
      addTearDown(() => root.delete(recursive: true));
      await tester.pump();
      for (var attempt = 0; attempt < 20; attempt++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
        if (tester.widget<RawImage>(find.byType(RawImage)).image != null) break;
      }
      await warmDiaryFaces(tester);
      expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
      expect(face.debugFrontCaptures, greaterThan(pendingCaptures));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('cached live content follows action state and edit permission', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          syncCanEditProvider.overrideWith((ref) => ref.watch(_canEdit)),
          aiEnabledProvider.overrideWithValue(false),
          diaryClockProvider.overrideWithValue(() => DateTime(2026, 11, 2)),
        ],
        child: MaterialApp(
          home: SingleChildScrollView(
            child: DiaryDayContent(day: day('Words'), interactive: true),
          ),
        ),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DiaryDayContent)),
    );
    DiaryTitlePrompt title() => tester.widget(find.byType(DiaryTitlePrompt));
    expect(title().onTap, isNotNull);
    final gate = Completer<void>();
    final action = container
        .read(diaryActionsProvider.notifier)
        .run((_) => gate.future);
    await tester.pump();
    expect(title().onTap, isNull);
    gate.complete();
    await action;
    await tester.pump();
    expect(title().onTap, isNotNull);
    container.read(_canEdit.notifier).change(false);
    await tester.pump();
    expect(find.byType(DiaryTitlePrompt), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
